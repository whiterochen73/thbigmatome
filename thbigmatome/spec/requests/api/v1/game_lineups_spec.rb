require "rails_helper"

RSpec.describe "Api::V1::GameLineups", type: :request do
  let(:team) { create(:team) }

  def game_lineup_url
    "/api/v1/teams/#{team.id}/game_lineup"
  end

  let(:valid_lineup_data) do
    {
      "dh_enabled" => true,
      "opponent_pitcher_hand" => "right",
      "starting_lineup" => [
        { "batting_order" => 1, "player_id" => 1, "position" => "RF" }
      ],
      "bench_players" => [],
      "off_players" => [],
      "relief_pitcher_ids" => [],
      "starter_bench_pitcher_ids" => []
    }
  end

  describe "認証なしアクセス" do
    it "GET /game_lineup → 401" do
      get game_lineup_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "PUT /game_lineup → 401" do
      put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/teams/:team_id/game_lineup" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    context "前回データが存在する場合" do
      let!(:game_lineup) { create(:game_lineup, team: team, lineup_data: valid_lineup_data) }

      it "200を返す" do
        get game_lineup_url
        expect(response).to have_http_status(:ok)
      end

      it "lineup_dataを返す" do
        get game_lineup_url
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(game_lineup.id)
        expect(json["lineup_data"]["dh_enabled"]).to eq(true)
        expect(json["lineup_data"]["opponent_pitcher_hand"]).to eq("right")
        expect(json).to have_key("updated_at")
      end
    end

    context "前回データが存在しない場合" do
      it "404を返す" do
        get game_lineup_url
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/v1/teams/:team_id/game_lineup" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    context "前回データが存在しない場合（create）" do
      it "200を返す" do
        put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
        expect(response).to have_http_status(:ok)
      end

      it "新規レコードを作成する" do
        expect {
          put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
        }.to change(GameLineup, :count).by(1)
      end

      it "lineup_dataを返す" do
        put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
        json = JSON.parse(response.body)
        expect(json["lineup_data"]["dh_enabled"]).to eq(true)
        expect(json["lineup_data"]["opponent_pitcher_hand"]).to eq("right")
      end
    end

    context "前回データが既に存在する場合（update）" do
      let!(:existing_lineup) do
        create(:game_lineup, team: team, lineup_data: { "dh_enabled" => false, "opponent_pitcher_hand" => "left" })
      end

      it "200を返す" do
        put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
        expect(response).to have_http_status(:ok)
      end

      it "レコード数が増えない（upsert）" do
        expect {
          put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
        }.not_to change(GameLineup, :count)
      end

      it "lineup_dataが更新される" do
        put game_lineup_url, params: { game_lineup: { lineup_data: valid_lineup_data } }, as: :json
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(existing_lineup.id)
        expect(json["lineup_data"]["dh_enabled"]).to eq(true)
        expect(json["lineup_data"]["opponent_pitcher_hand"]).to eq("right")
      end
    end
  end
end
