require "rails_helper"

RSpec.describe "Api::V1::GamesController", type: :request do
  describe "GET /api/v1/games" do
    include_context "authenticated user"

    it "returns 200 with empty list when no games" do
      get "/api/v1/games", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns all games ordered by id desc" do
      games = create_list(:game, 3)

      get "/api/v1/games", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
      expect(json.map { |g| g["id"] }).to eq(games.map(&:id).sort.reverse)
    end

    it "returns game_record_id when game_record exists" do
      game = create(:game)
      game_record = create(:game_record, game: game)

      get "/api/v1/games", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      game_json = json.find { |g| g["id"] == game.id }
      expect(game_json["game_record_id"]).to eq(game_record.id)
    end

    it "returns null game_record_id when no game_record" do
      create(:game)

      get "/api/v1/games", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.first["game_record_id"]).to be_nil
    end

    it "filters by competition_id" do
      competition1 = create(:competition)
      competition2 = create(:competition)
      game1 = create(:game, competition: competition1)
      create(:game, competition: competition2)

      get "/api/v1/games?competition_id=#{competition1.id}", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(1)
      expect(json.first["id"]).to eq(game1.id)
    end
  end

  describe "GET /api/v1/games (unauthenticated)" do
    it "returns 401" do
      get "/api/v1/games", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/games/:id" do
    include_context "authenticated user"

    it "returns 200 with game details" do
      game = create(:game)

      get "/api/v1/games/#{game.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(game.id)
      expect(json["status"]).to eq("draft")
    end

    it "returns 404 for non-existent game" do
      get "/api/v1/games/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # Test Basis: Operator 決定 2026-11-01（cmd_1795）。作成・確定・オーダーの API は廃止し、Clubhouse の games:pull が読む GET だけを残す
  describe "廃止した操作" do
    include_context "authenticated user"

    let(:game) { create(:game, status: "draft") }

    it "POST /api/v1/games は無い" do
      post "/api/v1/games", params: { game: { status: "draft" } }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "POST /api/v1/games/:id/confirm は無い" do
      post "/api/v1/games/#{game.id}/confirm", as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "GET /api/v1/games/:id/lineup は無い" do
      get "/api/v1/games/#{game.id}/lineup"
      expect(response).to have_http_status(:not_found)
    end
  end
end
