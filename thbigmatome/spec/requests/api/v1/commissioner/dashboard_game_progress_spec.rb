require "rails_helper"

# Test Basis: cmd_1794 段3（サーバ側）。Operator 決定 2026-11-02「進み具合に試合数（消化数／総数）を出す」。数え方の境界は spec/services/season_game_progress_spec.rb。
# ここは API の形・権限・全チーム分が揃うこと。
RSpec.describe "GET /api/v1/commissioner/dashboard/game_progress", type: :request do
  let(:path) { "/api/v1/commissioner/dashboard/game_progress" }

  def season_with(team, results:, unplayed: 0, playoff_played: 0)
    season = create(:season, team: team)
    day = Date.new(2026, 5, 1)
    results.times { create(:season_schedule, season: season, date: (day += 1), score: 2, opponent_score: 1) }
    unplayed.times { create(:season_schedule, season: season, date: (day += 1)) }
    playoff_played.times { create(:season_schedule, season: season, date: (day += 1), date_type: "playoff_day", score: 1, opponent_score: 0) }
    season
  end

  context "コミッショナー" do
    include_context "authenticated commissioner"

    it "チームごとに team_id・regular_played・regular_total・playoff_played を数値で返す" do
      team = create(:team, is_active: true)
      season_with(team, results: 3, unplayed: 2, playoff_played: 1)

      get path

      expect(response).to have_http_status(:ok)
      row = response.parsed_body.find { |r| r["team_id"] == team.id }
      expect(row).to eq("team_id" => team.id, "regular_played" => 3, "regular_total" => 5, "playoff_played" => 1)
    end

    it "稼働中も休止中も 1 チーム 1 行で返し、シーズンの無いチームは返さない" do
      active = create(:team, is_active: true)
      inactive = create(:team, is_active: false)
      no_season = create(:team)
      season_with(active, results: 1)
      season_with(inactive, results: 2)

      get path

      ids = response.parsed_body.map { |r| r["team_id"] }
      expect(ids).to contain_exactly(active.id, inactive.id)
      expect(ids).not_to include(no_season.id)
    end

    it "日程の無いシーズンは 0 / 0 で返す" do
      team = create(:team)
      create(:season, team: team)

      get path

      expect(response.parsed_body).to eq([ { "team_id" => team.id, "regular_played" => 0, "regular_total" => 0, "playoff_played" => 0 } ])
    end

    it "ノーゲームの日は数えず、振り替えた日は数える" do
      team = create(:team)
      season = season_with(team, results: 1)
      create(:season_schedule, season: season, date: Date.new(2026, 6, 1), no_game: true)
      create(:season_schedule, season: season, date: Date.new(2026, 6, 2), date_type: "reserve_day", score: 4, opponent_score: 3).update!(date_type: "game_day")

      get path

      expect(response.parsed_body.first).to include("regular_played" => 2, "regular_total" => 2)
    end
  end

  context "一般ユーザー" do
    include_context "authenticated user"

    it "403 を返す" do
      get path
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "未認証" do
    it "401 を返す" do
      get path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
