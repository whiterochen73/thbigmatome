# 先発の疲労P・result_category 作り直しのテスト用ヘルパー（cmd_1775）
module PitcherFatigueScenario
  # チーム + シーズン
  def create_team_with_season
    team = create(:team)
    season = create(:season, team: team)
    [ team, season ]
  end

  # チームに登録された投手（カード付き）。starter_stamina: nil で「カード未記載」
  def create_card_pitcher(team:, starter_stamina:, relief_stamina: nil, with_card: true)
    pitcher = create(:player, :pitcher)
    card = with_card ? create(:player_card, player: pitcher, card_type: "pitcher",
                                            starter_stamina: starter_stamina, relief_stamina: relief_stamina) : nil
    membership = create(:team_membership, team: team, player: pitcher, player_card: card)
    [ pitcher, membership ]
  end

  # 試合概要。score / opponent_score は自チーム視点
  def create_schedule(season, date, score: nil, opponent_score: nil)
    create(:season_schedule, season: season, date: date, score: score, opponent_score: opponent_score)
  end

  # 登板記録（先発）。前の投手を置きたい時は prior_pitchers を指定
  def create_start(team:, pitcher:, date:, innings:, category: "normal", role: "starter", fatigue_p_used: 0,
                   decision: nil, no_out_exit: false, game: nil, appearance_order: 0, consecutive_short_rest_count: 0)
    create(:pitcher_game_state,
           team: team, pitcher: pitcher, game: game || create(:game), schedule_date: date.to_s,
           role: role, innings_pitched: innings, result_category: category, fatigue_p_used: fatigue_p_used,
           decision: decision, no_out_exit: no_out_exit, appearance_order: appearance_order,
           consecutive_short_rest_count: consecutive_short_rest_count)
  end
end

RSpec.configure do |config|
  config.include PitcherFatigueScenario, :pitcher_fatigue
end
