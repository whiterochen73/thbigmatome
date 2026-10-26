# 連続中4日以下先発カウント（consecutive_short_rest_count）を、サーバ側で求める（cmd_1775 第2段 E3・第4段で AMB-23 に合わせて改訂）。
#
# 「直前の登板」（役割を問わない）で決める:
#   直前の登板が先発（role=starter。第二先発の 2 番手も role=starter で保存される）で、
#   そこからの中日数（負傷控除後）が中4日以下 → 直前の登板の値 + 1
#   それ以外（直前がリリーフ・オープナー / 中5日以上 / 直前の登板なし）→ 0
#
# - AMB-23（Operator 2026-10-26）: 連続は「起点の登板以降がすべて先発登板」の時だけ。間にリリーフ・オープナー登板が
#   入れば切れる（先発同士を飛び越えて数えない）。「連続する3回の先発登板で、間隔が両方とも中4日以下」が負傷チェック（§8.5.1 条件2）の形。
#   中3日も数える（中2日以内は先発不可なので現れない）。
# - 「直前の登板」は休養表（fatigue_summary の last_app）と同じ基準: 同じチーム・同じ投手・対象日より前で最も新しいもの
#   （同日に複数あれば id の新しい方）。
# - 中日数は離脱を差し引いた値（rulebook §8.7.2）。差し引くのは負傷のみ（AMB-04 出場停止と負傷は別枠）。
# - 中10日リセット（実日数差。離脱期間は関与しない）が成立する時は 0（AMB-04 追補 3・Operator 裁定 2026-10-26）。
#   疲労に関わる情報がすべてリセットされるので、控除後の中日数が 4 以下でも +1 しない。リセットは他の判定より先に見る。
class PitcherConsecutiveShortRest
  SHORT_REST_DAYS = 4 # この日数以下の中日数が「連続」に数えられる（AMB-23）

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
    last = PitcherGameState
      .where(pitcher_id: @pitcher_id, team_id: @team_id)
      .where("schedule_date < ?", @target_date.to_s)
      .order(schedule_date: :desc, id: :desc)
      .first
    return 0 if last.nil? || last.role != "starter"

    last_date = last.schedule_date.to_date
    return 0 if PitcherRestStatus.rest_reset?(last_date, @target_date)

    rest_days = PitcherRestStatus.raw_rest_days(last_date, @target_date) -
                PitcherRestStatus.absence_days_in_range(injury_absences, last_date + 1, @target_date - 1)
    return 0 unless rest_days <= SHORT_REST_DAYS

    previous = @overrides.fetch(last.id) { last.consecutive_short_rest_count }
    previous.to_i + 1
  end

  private

  def injury_absences
    membership = TeamMembership.find_by(team_id: @team_id, player_id: @pitcher_id)
    return [] if membership.nil?

    PitcherRestStatus.injury_absences([ membership.id ])[membership.id]
  end
end
