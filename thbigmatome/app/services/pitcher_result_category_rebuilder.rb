# 先発の result_category（と使った疲労P）を、試合概要の得点とカードから作り直す（E2・過去分の是正）。
#
# 使い方: 書き込む側の入口は PitcherHistoryRebuild の 1 本（cmd_1784 段3。設計書 §4.5）。この class はその中身（走査と判定）で、
# 直接呼ぶのは試運転（apply: false。点検の S8c・rake の試運転）と PitcherHistoryRebuild だけ。
#   - SeasonSchedule の得点・ノーゲームが保存・変更された時 / 登板の保存・削除 / 離脱の作成・変更・削除 / カードの変更: PitcherHistoryRebuild.from
#   - 過去分の一括: rake pitcher_game_states:recalculate_result_category（既定は試運転）
#
# 前登板の区分が次の補正を決めるので、投手ごとに日付順に処理し、作り直した値を次の判定に使う
# （試運転でも DB に書かずに同じ連鎖を再現する。result_category_overrides を使う）。
# 判定できないもの（カード未特定・得点未入力・試合概要なし）は変えず、理由別に件数を出す。
# ノーゲーム: 試合概要に no_game が立っていれば、その日の登板は no_game に揃える（得点に依らない）。
# 試合概要に no_game が立っていないのに result_category が no_game の古い記録は、変えず skipped_no_game に数える
# （画面から選べなかった頃に API で直接入れたもの）。ただし no_game を立てた・外した直後の再計算では、その日の記録を作り直す。
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

  # 全先発（または team_id 指定）を投手ごとに日付順で作り直す
  def rebuild_all(team_id: nil)
    rebuild_from(team_id: team_id)
  end

  # team_id のチーム（nil なら全チーム）の先発を、投手ごとに日付順で作り直す。
  # date を渡せばその日以降の登板だけ（それより前は DB の値を前登板として読む）。pitcher_ids を渡せばその投手だけ（空配列なら誰も作り直さない）。
  # recompute_no_game_on: その日の記録だけ、ノーゲームの印が無い no_game の記録も作り直す
  def rebuild_from(team_id: nil, date: nil, pitcher_ids: nil, recompute_no_game_on: nil)
    scope = PitcherGameState.where(role: "starter")
    scope = scope.where(team_id: team_id) if team_id.present?
    scope = scope.where("schedule_date >= ?", date.to_s) if date
    scope = scope.where(pitcher_id: pitcher_ids) unless pitcher_ids.nil?
    no_game_date = recompute_no_game_on&.to_s
    scope.distinct.pluck(:team_id, :pitcher_id).sort.each do |tid, pid|
      states = scope.where(team_id: tid, pitcher_id: pid).order(:schedule_date, :id).to_a
      states.each { |state| rebuild_state(state, recompute_no_game: !no_game_date.nil? && state.schedule_date == no_game_date) }
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

  def rebuild_state(state, recompute_no_game: false)
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
    return add(base, :skipped_no_game) if state.result_category == "no_game" && outcome.result != "no_game" && !recompute_no_game
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
