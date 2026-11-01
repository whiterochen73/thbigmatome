# 登板（pitcher_game_states）の season_schedule_id を、（チーム, 試合日）から日程の行を引いて埋める（cmd_1784 段3。設計書 §5.2 段3）。
#
# 埋めるのは、紐づけが空で、そのチームのその日の日程の行がちょうど 1 件ある登板だけ。
# 対応する日程の行が無い登板（no_schedule）・同じ日に複数ある登板（ambiguous）・日付が読めない登板（bad_date）は、行を作らず・紐づけず、
# 一覧に出す。すでに紐づいている登板（already）は触らない。ただし紐づけ先が（チーム, 試合日）から引いた行と違う登板（mismatch）は
# 変えずに一覧に出す。何度流しても同じ結果になる。
#
# 使い方: rake season_records:link_pitcher_schedules（既定は試運転。APPLY=1 の時だけ書く）
class PitcherScheduleLinker
  # status: :linked / :already / :no_schedule / :ambiguous / :bad_date / :mismatch
  Row = Struct.new(:state_id, :team_id, :pitcher_id, :schedule_date, :status, :schedule_ids, :current_schedule_id, keyword_init: true)

  UNLINKABLE = %i[no_schedule ambiguous bad_date mismatch].freeze

  attr_reader :rows

  def initialize(apply: false, team_id: nil)
    @apply = apply
    @team_id = team_id.presence&.to_i
    @rows = []
  end

  def call
    schedules = schedule_index
    to_link = Hash.new { |h, k| h[k] = [] }

    states.each do |id, team_id, pitcher_id, date_str, current|
      date = PitcherGameState.parse_schedule_date(date_str)
      ids = date ? schedules.fetch([ team_id, date ], []) : []
      status = if date.nil? then :bad_date
      elsif ids.empty? then :no_schedule
      elsif ids.size > 1 then :ambiguous
      elsif current.nil? then :linked
      elsif current == ids.first then :already
      else :mismatch
      end
      @rows << Row.new(state_id: id, team_id: team_id, pitcher_id: pitcher_id, schedule_date: date_str, status: status,
                       schedule_ids: ids, current_schedule_id: current)
      to_link[ids.first] << id if status == :linked
    end

    # updated_at は触らない（紐づけは登板の内容の変更ではない）
    to_link.each { |schedule_id, ids| PitcherGameState.where(id: ids).update_all(season_schedule_id: schedule_id) } if @apply
    self
  end

  def summary
    @rows.group_by(&:status).transform_values(&:size)
  end

  def unlinkable
    @rows.select { |r| UNLINKABLE.include?(r.status) }
  end

  private

  def states
    scope = PitcherGameState.order(:id)
    scope = scope.where(team_id: @team_id) if @team_id
    scope.pluck(:id, :team_id, :pitcher_id, :schedule_date, :season_schedule_id)
  end

  # { [team_id, Date] => [season_schedule_id, ...] }
  def schedule_index
    SeasonSchedule.joins(:season).order("season_schedules.id").pluck("seasons.team_id", "season_schedules.date", "season_schedules.id")
                  .group_by { |team_id, date, _| [ team_id, date ] }.transform_values { |list| list.map(&:last) }
  end
end
