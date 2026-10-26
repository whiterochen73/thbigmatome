# 先発の result_category（と使った疲労P）を、試合概要の得点とカードから作り直す（E2・過去分の是正）。
#
# 使い方:
#   - SeasonSchedule の得点が保存・変更された時: rebuild_for_schedule（モデルの after_save から）
#   - 過去分の一括: rake pitcher_game_states:recalculate_result_category（既定は試運転）
#
# 前登板の区分が次の補正を決めるので、投手ごとに日付順に処理し、作り直した値を次の判定に使う
# （試運転でも DB に書かずに同じ連鎖を再現する。result_category_overrides を使う）。
# 判定できないもの（カード未特定・得点未入力・試合概要なし・ノーゲーム）は変えず、理由別に件数を出す。
#
# 連続中4日カウント（consecutive_short_rest_count。cmd_1775 第2段 E3）も同じ走査で埋め直す。
# カウントは得点・カードに依らず日付と離脱だけで決まるので、区分を作り直せない行（スキップ・保留）でも書く。
# 前回値の連鎖は count_overrides で再現する（試運転でも同じ値になる）。
class PitcherResultCategoryRebuilder
  # status: :changed / :fatigue_only / :unchanged / :skipped_unscored / :skipped_no_schedule /
  #         :skipped_ambiguous_schedule / :skipped_no_game / :pending
  Row = Struct.new(:state_id, :team_id, :pitcher_id, :schedule_date, :old_category, :new_category,
                   :old_fatigue_p, :new_fatigue_p, :game_result, :status, :reason,
                   :old_consecutive_short_rest_count, :new_consecutive_short_rest_count, keyword_init: true) do
    def consecutive_changed? = old_consecutive_short_rest_count != new_consecutive_short_rest_count
  end

  attr_reader :rows

  # apply: false なら DB を書かない（試運転）
  # unscored: :skip（得点未入力は変えない）/ :not_loss（負けではないとして扱う。得点が消された時用）
  def initialize(apply: false, unscored: :skip)
    @apply = apply
    @unscored = unscored
    @overrides = {}
    @count_overrides = {}
    @rows = []
  end

  # 得点が保存・変更された試合の自チーム先発を作り直し、区分が変わった投手は後続の先発へ波及させる。
  # 波及は「区分が変わらなくなった所」で止める（無関係な過去分を巻き込まない）。
  def rebuild_for_schedule(schedule)
    team_id = schedule.season.team_id
    date = schedule.date.to_s
    starters = PitcherGameState.where(team_id: team_id, schedule_date: date, role: "starter").order(:id).to_a
    starters.each do |state|
      row = rebuild_state(state)
      cascade_after(state) if row.status == :changed
    end
    @rows
  end

  # 全先発（または team_id 指定）を投手ごとに日付順で作り直す
  def rebuild_all(team_id: nil)
    scope = PitcherGameState.where(role: "starter")
    scope = scope.where(team_id: team_id) if team_id.present?
    scope.distinct.pluck(:team_id, :pitcher_id).sort.each do |tid, pid|
      states = scope.where(team_id: tid, pitcher_id: pid).order(:schedule_date, :id).to_a
      states.each { |state| rebuild_state(state) }
    end
    @rows
  end

  def summary
    @rows.group_by(&:status).transform_values(&:size)
  end

  # 連続中4日カウントが変わる行数（区分の status とは独立）
  def consecutive_changed_count
    @rows.count(&:consecutive_changed?)
  end

  private

  def cascade_after(state)
    later = PitcherGameState
      .where(team_id: state.team_id, pitcher_id: state.pitcher_id, role: "starter")
      .where("schedule_date > ?", state.schedule_date)
      .order(:schedule_date, :id)
    later.each do |next_state|
      row = rebuild_state(next_state)
      break unless row.status == :changed
    end
  end

  def rebuild_state(state)
    outcome = PitcherGameResult.for(team_id: state.team_id, schedule_date: state.schedule_date)
    new_count = PitcherConsecutiveShortRest.call(
      team_id: state.team_id, pitcher_id: state.pitcher_id, schedule_date: state.schedule_date,
      count_overrides: @count_overrides
    )
    old_count = state.consecutive_short_rest_count
    @count_overrides[state.id] = new_count
    state.update!(consecutive_short_rest_count: new_count) if @apply && new_count != old_count
    base = {
      state_id: state.id, team_id: state.team_id, pitcher_id: state.pitcher_id,
      schedule_date: state.schedule_date, old_category: state.result_category,
      old_fatigue_p: state.fatigue_p_used, game_result: outcome.result,
      old_consecutive_short_rest_count: old_count,
      new_consecutive_short_rest_count: new_count
    }
    return add(base, :skipped_no_game) if state.result_category == "no_game"
    return add(base, outcome.note == :ambiguous ? :skipped_ambiguous_schedule : :skipped_no_schedule) unless outcome.found
    return add(base, :skipped_unscored) if !outcome.scored && @unscored == :skip

    games = PitcherGameState.where(game_id: state.game_id, team_id: state.team_id)
    prior_outs = games.where("appearance_order < ?", state.appearance_order)
                      .pluck(:innings_pitched).sum { |ip| PitcherInnings.outs_from_innings(ip) }

    res = PitcherResultCategory.call(
      team_id: state.team_id, pitcher_id: state.pitcher_id, schedule_date: state.schedule_date,
      role: state.role, innings_pitched: state.innings_pitched, no_out_exit: state.no_out_exit,
      decision: state.decision, pitchers_in_game: games.count, prior_outs: prior_outs,
      game_result: outcome.result, result_category_overrides: @overrides
    )
    return add(base, :pending, reason: res.pending_reason) if res.pending?

    @overrides[state.id] = res.category
    attrs = base.merge(new_category: res.category, new_fatigue_p: res.fatigue_p)
    status = if res.category != state.result_category then :changed
    elsif res.fatigue_p != state.fatigue_p_used then :fatigue_only
    else :unchanged
    end
    state.update!(result_category: res.category, fatigue_p_used: res.fatigue_p) if @apply && status != :unchanged
    add(attrs, status)
  end

  def add(attrs, status, reason: nil)
    row = Row.new(**attrs, status: status, reason: reason)
    @rows << row
    row
  end
end
