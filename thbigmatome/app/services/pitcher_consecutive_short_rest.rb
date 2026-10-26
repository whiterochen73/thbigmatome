# 連続中4日先発カウント（consecutive_short_rest_count）を、サーバ側で求める（cmd_1775 第2段 E3）。
#
#   直前の先発登板との中日数が中4日 → 直前の先発の値 + 1
#   それ以外（中3日・中5日以上・直前の先発なし）→ 0
#
# - 「直前の先発」は同じチーム・同じ投手の role=starter の登板のうち、対象日より前で最も新しいもの。
#   間にリリーフ登板があっても先発同士で数える。
# - 中日数は離脱を差し引いた値（rulebook §8.7.2）。差し引くのは負傷のみ（AMB-04 出場停止と負傷は別枠）。
# - このカウントは次回の中4日先発の負傷チェック（§8.5.1 条件2・§8.3.1 の「2回連続で発動」）に使う。
# - 中10日リセット（実日数差）は疲労P・累積イニングの扱いで、このカウントでは見ていない
#   （実日数が中10日以上でも、控除後の中日数がちょうど4なら +1 になる。指示どおり控除後の rest_days で判定）。
class PitcherConsecutiveShortRest
  SHORT_REST_DAYS = 4

  # count_overrides: { pitcher_game_state.id => 作り直した値 }
  #   rake の試運転や日付順の連鎖で、DB に書く前の「作り直した値」を前回値として使うための差し込み。
  def self.call(team_id:, pitcher_id:, schedule_date:, count_overrides: {})
    new(team_id, pitcher_id, schedule_date, count_overrides).call
  end

  def initialize(team_id, pitcher_id, schedule_date, overrides)
    @team_id = team_id
    @pitcher_id = pitcher_id
    @target_date = Date.parse(schedule_date.to_s)
    @overrides = overrides || {}
  end

  def call
    last_start = PitcherGameState
      .where(pitcher_id: @pitcher_id, team_id: @team_id, role: "starter")
      .where("schedule_date < ?", @target_date.to_s)
      .order(schedule_date: :desc, id: :desc)
      .first
    return 0 if last_start.nil?

    last_date = last_start.schedule_date.to_date
    rest_days = PitcherRestStatus.raw_rest_days(last_date, @target_date) -
                PitcherRestStatus.absence_days_in_range(injury_absences, last_date + 1, @target_date - 1)
    return 0 unless rest_days == SHORT_REST_DAYS

    previous = @overrides.fetch(last_start.id) { last_start.consecutive_short_rest_count }
    previous.to_i + 1
  end

  private

  def injury_absences
    membership = TeamMembership.find_by(team_id: @team_id, player_id: @pitcher_id)
    return [] if membership.nil?

    PitcherRestStatus.injury_absences([ membership.id ])[membership.id]
  end
end
