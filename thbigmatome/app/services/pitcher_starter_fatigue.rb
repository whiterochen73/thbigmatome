# 先発投手の「その試合前の疲労P」を、サーバ側で求める（Operator 裁定 2026-10-25）。
#
#   疲労P = 選手カードの先発疲労P（starter_stamina）に、試合前のスタミナ補正（§8.3.1 の表）をかけた値
#
# - カードに先発疲労P の記載が無い（starter_stamina が nil）投手だけが既定 3（§8.3）。補正の結果 0 とは別物。
# - 中10日（実日数差。離脱期間は関与しない・裁定 2026-09-13）以上空けば補正なし。登板可否より優先する（裁定 2026-10-25）。
# - 中日数から引く離脱は負傷のみ（裁定 2026-09-12 出場停止と負傷は別枠）。
# - そのチームでその選手に使っているカードは team_memberships（team_id, player_id は一意）の
#   player_card_id から引く。メンバー・カードが特定できない場合は推測せず pending を返す。
class PitcherStarterFatigue
  # fatigue_p:      補正後の疲労P。pending の時は nil
  # card_fatigue_p: 補正前のカード値（未記載なら既定 3）
  # card_unset:     カードに先発疲労P の記載が無く既定 3 を使ったか
  # pending:        判定保留の理由（シンボル）。nil なら判定できた
  Result = Struct.new(:fatigue_p, :card_fatigue_p, :card_unset, :pending, keyword_init: true) do
    def pending? = !pending.nil?
  end

  PENDING_MESSAGES = {
    membership_not_found: "チームの登録に投手が見つからないためカードを特定できない",
    card_not_identified: "チームの登録にカード(player_card)が紐づいていないため疲労Pを特定できない",
    rest_too_short: "前回登板から中2日以内で、先発の補正表(§8.3.1)に該当しない"
  }.freeze

  # result_category_overrides: { pitcher_game_state.id => result_category }
  #   rake の試運転や日付順の連鎖で、DB に書く前の「作り直した値」を前登板の区分として使うための差し込み。
  def self.call(team_id:, pitcher_id:, schedule_date:, result_category_overrides: {})
    new(team_id, pitcher_id, schedule_date, result_category_overrides).call
  end

  def initialize(team_id, pitcher_id, schedule_date, overrides)
    @team_id = team_id
    @pitcher_id = pitcher_id
    @target_date = Date.parse(schedule_date.to_s)
    @overrides = overrides || {}
  end

  def call
    membership = TeamMembership.includes(:player_card).find_by(team_id: @team_id, player_id: @pitcher_id)
    return pending(:membership_not_found) if membership.nil?

    card = membership.player_card
    return pending(:card_not_identified) if card.nil?

    card_unset = card.starter_stamina.nil?
    card_fp = card.starter_stamina || PitcherGameState::DEFAULT_STARTER_FATIGUE_P

    last_app = PitcherGameState
      .where(pitcher_id: @pitcher_id, team_id: @team_id)
      .where("schedule_date < ?", @target_date.to_s)
      .order(schedule_date: :desc, id: :desc)
      .first
    return done(card_fp, card_fp, card_unset) if last_app.nil?

    last_date = last_app.schedule_date.to_date
    raw_rest = PitcherRestStatus.raw_rest_days(last_date, @target_date)
    # 中10日リセット: 実日数差。離脱期間は関与しない。登板可否（中2日以内は不可）より優先する（AMB-04 追補2）
    return done(card_fp, card_fp, card_unset) if PitcherRestStatus.rest_reset?(last_date, @target_date)

    # 中日数から引く離脱は負傷のみ（出場停止・再調整は引かない）
    absences = PitcherRestStatus.injury_absences([ membership.id ])[membership.id]

    rest_days = raw_rest - PitcherRestStatus.absence_days_in_range(absences, last_date + 1, @target_date - 1)

    fp = if last_app.role == "starter"
      category = @overrides.fetch(last_app.id) { last_app.result_category } || "normal"
      PitcherRestStatus.starter_fatigue_p(card_fp, category, rest_days)
    elsif card.slash_pitcher?
      # リリーフ/オープナー→先発（§8.3.4 スラッシュ選手）: 直近リリーフ登板直後の累積イニングで表を選ぶ
      cumulative = PitcherRestStatus.cumulative_innings(@team_id, @pitcher_id, last_date + 1, absences)
      PitcherRestStatus.slash_starter_fatigue_p_after_relief(card_fp, cumulative, rest_days)
    else
      # リリーフ/オープナー→先発（§8.3.4 通常選手）: 先発→先発の通常と同じ表
      PitcherRestStatus.starter_fatigue_p(card_fp, "normal", rest_days)
    end
    return pending(:rest_too_short) if fp.nil?

    done(fp, card_fp, card_unset)
  end

  private

  def done(fp, card_fp, card_unset)
    Result.new(fatigue_p: fp, card_fatigue_p: card_fp, card_unset: card_unset, pending: nil)
  end

  def pending(reason)
    Result.new(fatigue_p: nil, card_fatigue_p: nil, card_unset: nil, pending: reason)
  end
end
