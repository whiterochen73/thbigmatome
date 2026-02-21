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

  describe "POST /api/v1/games" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:home_team) { create(:team) }
    let(:visitor_team) { create(:team) }
    let(:stadium) { create(:stadium) }

    let(:valid_params) do
      {
        game: {
          competition_id: competition.id,
          home_team_id: home_team.id,
          visitor_team_id: visitor_team.id,
          stadium_id: stadium.id,
          real_date: Date.today.to_s,
          status: "draft",
          source: "live"
        }
      }
    end

    it "creates a game and returns 201" do
      expect {
        post "/api/v1/games", params: valid_params, as: :json
      }.to change(Game, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["competition_id"]).to eq(competition.id)
    end

    it "returns 422 with invalid params" do
      post "/api/v1/games", params: { game: { status: "invalid_status" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json["errors"]).to be_present
    end
  end
end
