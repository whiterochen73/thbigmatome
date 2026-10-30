# 昇降格の保存で守る規定を、時点ごとに検査する（cmd_1784 段1）。
#
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.4 の 2。
# 検査するのは次の 5 種類と、クールダウン。
#   first_squad_max      1軍は 29 人まで（どの時点でも）
#   first_squad_min      試合日（日程の種別 game_day）の試合前は 1軍に最低人数（config/cost_limits.yml）。
#                        シーズン初日の試合日は免除（初期登録のため。いまの保存と同じ）
#   first_squad_cost     1軍の合計コストが、人数別の上限（config/cost_limits.yml）以下
#   outside_world_limit  1軍の外の世界枠は 4 人まで
#   outside_world_balance  外の世界枠が 4 人なら投手・野手の両方を含む
#   cooldown             降格から 10 日は再登録できない（同日の昇降格は免除）
#
# 契約・コスト表は過去の値を復元できないので、どの時点も「今の契約・今のコスト表」で数える（設計書 §5.2・§8）。
class RosterConstraintChecker
  FIRST_SQUAD_MAX = 29
  PHASE_LABELS = { "pre_game" => "試合前", "in_game" => "試合中", "post_game" => "試合後" }.freeze

  # severity: 規定をどれだけ外れているか（人数の超過、コストの超過、不足日数など）。0 より大きければ違反
  Violation = Struct.new(:date, :phase, :kind, :message, :severity, :player_id, keyword_init: true) do
    def key
      [ kind, date, phase, player_id ]
    end

    def to_h
      { date: date.to_s, phase: phase, kind: kind, message: message }
    end
  end

  attr_reader :team, :season

  # cost_list: 検査に使うコスト表（Cost.current_cost）
  def initialize(team:, season:, cost_list:)
    @team = team
    @season = season
    @cost_list = cost_list
    @schedule_dates = season.season_schedules.pluck(:date, :date_type)
    @season_start = @schedule_dates.map(&:first).min
    @game_days = @schedule_dates.select { |_, type| type == "game_day" }.map(&:first).to_set
    @info = {}
  end

  # state の (date, phase) 時点の人数・コスト・外の世界枠の違反
  def point_violations(state, date, phase)
    first = state.first_memberships(date, phase)
    count = first.size
    violations = []

    if @game_days.include?(date) && phase == "pre_game" && count < minimum_players && date != @season_start
      violations << violation(date, phase, "first_squad_min", "試合日には1軍に最低#{minimum_players}人を登録する必要があります。", minimum_players - count)
    end

    if count > FIRST_SQUAD_MAX
      violations << violation(date, phase, "first_squad_max", "1軍に登録できる選手の最大数（#{FIRST_SQUAD_MAX}人）を超えています。", count - FIRST_SQUAD_MAX)
    end

    total_cost = first.sum { |tm| info_for(tm)[:cost] }
    max_cost = Team.first_squad_cost_limit_for_count(count)
    if max_cost && total_cost > max_cost
      violations << violation(date, phase, "first_squad_cost", "1軍に登録されている選手の合計コストが上限（#{max_cost}）を超えています。", total_cost - max_cost)
    end

    outside = first.select { |tm| info_for(tm)[:outside_world] }
    if outside.size > Team::OUTSIDE_WORLD_LIMIT
      violations << violation(date, phase, "outside_world_limit",
        I18n.t("activerecord.errors.models.team.outside_world.limit_exceeded", count: outside.size, limit: Team::OUTSIDE_WORLD_LIMIT),
        outside.size - Team::OUTSIDE_WORLD_LIMIT)
    end
    # 4 人以上の時は投手・野手の両方が要る（Team#validate_outside_world_balance と同じ。5 人以上なら limit と両方が出る）
    if outside.size >= Team::OUTSIDE_WORLD_LIMIT && !(outside.any? { |tm| info_for(tm)[:pitcher] } && outside.any? { |tm| info_for(tm)[:fielder] })
      violations << violation(date, phase, "outside_world_balance", I18n.t("activerecord.errors.models.team.outside_world.balance_required"), 1)
    end

    violations
  end

  # from_point 以降（含む）の全時点の違反。時点は state の記録のある時点と、日程の試合日（試合前）
  def violations_from(state, from_point, extra_points: [])
    points = candidate_points(from_point, [ state.record_points, extra_points ].flatten(1))
    violations = points.flat_map { |date, phase| point_violations(state, date, phase) }
    violations + cooldown_violations(state).select { |v| (v.date <=> from_point[0]) >= 0 }
  end

  # before に無い、または before より悪化した違反（この保存で新たに生じたもの）
  def new_violations(before_state, after_state, from_point)
    extra = after_state.record_points + before_state.record_points
    before = violations_from(before_state, from_point, extra_points: extra).index_by(&:key)
    after = violations_from(after_state, from_point, extra_points: extra)
    after.select { |v| (old = before[v.key]).nil? || v.severity > old.severity }
  end

  # 時点つきの文面（保存を止める・警告する時に日付を添える）
  def self.dated_message(violation)
    "#{violation.date}（#{PHASE_LABELS.fetch(violation.phase, violation.phase)}）: #{violation.message}"
  end

  private

  def minimum_players
    Team.first_squad_minimum_players
  end

  def violation(date, phase, kind, message, severity, player_id: nil)
    Violation.new(date: date, phase: phase, kind: kind, message: message, severity: severity, player_id: player_id)
  end

  def candidate_points(from_point, record_points)
    from_date, from_phase = from_point
    from_key = [ from_date, SeasonRoster.phase_rank(from_phase) ]
    points = record_points.map { |date, phase| [ date, phase ] }
    points += @game_days.select { |d| d >= from_date }.map { |d| [ d, "pre_game" ] }
    points << from_point
    points.uniq.select { |date, phase| ([ date, SeasonRoster.phase_rank(phase) ] <=> from_key) >= 0 }
          .sort_by { |date, phase| [ date, SeasonRoster.phase_rank(phase) ] }
  end

  def cooldown_violations(state)
    names = state.memberships.index_by(&:id)
    state.cooldown_violations.map do |(tm_id, promoted_on, phase), detail|
      tm = names.fetch(tm_id)
      violation(promoted_on, phase, "cooldown",
        "#{tm.player.name}は#{detail[:demotion_date]}に降格してから#{RosterState::COOLDOWN_DAYS}日以内（あと#{detail[:days_short]}日）のため、この昇格はできません。",
        detail[:days_short], player_id: tm.player_id)
    end
  end

  def info_for(tm)
    @info[tm.id] ||= begin
      native = Team::NATIVE_SERIES[team.team_type] || Team::NATIVE_SERIES["normal"]
      series = tm.player_card&.card_set&.series.presence || tm.player.series
      {
        cost: tm.selected_cost_value(@cost_list),
        outside_world: series.present? && !native.include?(series),
        pitcher: tm.pitcher_role?,
        fielder: tm.fielder_role?
      }
    end
  end
end
