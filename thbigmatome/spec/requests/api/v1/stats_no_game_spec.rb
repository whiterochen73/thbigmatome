require "rails_helper"

# Test Basis: 台帳 D-11（2026-09-12）と再確認（2026-10-26 Operator）「ノーゲームは勝敗・成績に入れない」。
#   Dugout の集計（チーム勝敗・打撃・投手成績・ホーム画面）から、ノーゲームの試合を外す。登板記録・原資料は消さない
RSpec.describe "ノーゲームの試合は成績に入れない", type: :request do
  include_context "authenticated user"

  let(:competition) { create(:competition) }
  let(:home_team) { create(:team) }
  let(:visitor_team) { create(:team) }
  let(:stadium) { create(:stadium) }
  let(:batter) { create(:player) }
  let(:pitcher) { create(:player, :pitcher) }
  let(:season) { create(:season, team: home_team) }

  def confirmed_game(date, home_score:, visitor_score:)
    create(:game, competition: competition, home_team: home_team, visitor_team: visitor_team, stadium: stadium,
                  status: "confirmed", home_score: home_score, visitor_score: visitor_score, home_schedule_date: date,
                  real_date: Date.parse(date))
  end

  def hit(game, seq: 1, code: "H")
    create(:at_bat, game: game, batter: batter, pitcher: pitcher, result_code: code, status: :confirmed, seq: seq)
  end

  def pitch(game, decision:, innings: 6.0, earned_runs: 2, date: "2026-03-20")
    create(:pitcher_game_state, game: game, pitcher: pitcher, team: home_team, competition: competition, schedule_date: date,
                                decision: decision, innings_pitched: innings, earned_runs: earned_runs)
  end

  let!(:counted) do
    confirmed_game("2026-03-19", home_score: 3, visitor_score: 1).tap do |g|
      hit(g)
      pitch(g, decision: "W", innings: 7.0, earned_runs: 1, date: "2026-03-19")
    end
  end
  let!(:rained) do
    confirmed_game("2026-03-20", home_score: 10, visitor_score: 0).tap do |g|
      hit(g, code: "HR")
      hit(g, seq: 2, code: "HR")
      hit(g, seq: 3, code: "GO")
      pitch(g, decision: "W", innings: 5.0, earned_runs: 0)
      create(:season_schedule, season: season, date: Date.new(2026, 3, 20), no_game: true, score: 10, opponent_score: 0)
    end
  end

  it "チーム成績: ノーゲームの勝敗・得失点・打撃・防御率を算入しない" do
    get "/api/v1/stats/team?competition_id=#{competition.id}", as: :json
    home = response.parsed_body["team_stats"].find { |s| s["team_id"] == home_team.id }
    visitor = response.parsed_body["team_stats"].find { |s| s["team_id"] == visitor_team.id }
    expect(home).to include("wins" => 1, "losses" => 0, "draws" => 0, "runs_scored" => 3, "runs_allowed" => 1)
    expect(visitor).to include("wins" => 0, "losses" => 1)
    # visitor の打撃（top）: 算入分は 1 打数 1 安打。ノーゲームを入れると 4 打数 3 安打 = .750
    expect(visitor["batting_average"]).to eq(1.0)
    # home の防御率: 算入分は 7 回 1 自責点。ノーゲームを入れると 12 回 1 自責点 = 0.75
    expect(home["era"]).to eq(1.29)
  end

  it "投手成績: ノーゲームの勝・投球回・自責点・被本塁打を算入しない" do
    get "/api/v1/stats/pitching?competition_id=#{competition.id}", as: :json
    stat = response.parsed_body["pitching_stats"].find { |s| s["player_id"] == pitcher.id }
    expect(stat).to include("wins" => 1, "innings_pitched" => 7.0, "hr_allowed" => 0, "hits_allowed" => 1)
  end

  it "打撃成績: ノーゲームの打席・安打・本塁打・出場試合を算入しない" do
    get "/api/v1/stats/batting?competition_id=#{competition.id}", as: :json
    stat = response.parsed_body["batting_stats"].find { |s| s["player_id"] == batter.id }
    expect(stat).to include("at_bat_count" => 1, "hits" => 1, "home_runs" => 0, "games_played" => 1)
  end

  it "ホーム画面: 消化試合数・直近試合・チーム勝敗にノーゲームを入れない" do
    get "/api/v1/home/summary", params: { competition_id: competition.id }
    json = response.parsed_body
    expect(json["season_progress"]["completed"]).to eq(1)
    expect(json["recent_games"].map { |g| g["id"] }).to eq([ counted.id ])
    expect(json["team_summary"]).to include("wins" => 1, "losses" => 0)
  end

  it "ノーゲームの印を外せば、その試合は集計に戻る（削除していない）" do
    # 画面と同じ経路（update!）で外す。登板記録の区分も得点から作り直されて no_game ではなくなる
    SeasonSchedule.find_by!(season: season, date: Date.new(2026, 3, 20)).update!(no_game: false)
    get "/api/v1/stats/team?competition_id=#{competition.id}", as: :json
    home = response.parsed_body["team_stats"].find { |s| s["team_id"] == home_team.id }
    expect(home).to include("wins" => 2, "runs_scored" => 13)
  end

  it "登板記録と打席は消えない（成績算入 false は削除ではない）" do
    expect(PitcherGameState.where(game_id: rained.id).count).to eq(1)
    expect(AtBat.where(game_id: rained.id).count).to eq(3)
    get "/api/v1/stats/pitching?competition_id=#{competition.id}", as: :json
    expect(PitcherGameState.where(game_id: rained.id).count).to eq(1)
  end
end
