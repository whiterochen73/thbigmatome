require "rails_helper"

RSpec.describe "Api::V1::PlayersController", type: :request do
  describe "GET /api/v1/players" do
    include_context "authenticated user"

    it "returns 200 with empty list when no players" do
      get "/api/v1/players", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns all players ordered by id" do
      players = create_list(:player, 3)

      get "/api/v1/players", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
      expect(json.map { |p| p["id"] }).to eq(players.map(&:id).sort)
    end

    it "includes detailed player attributes" do
      player = create(:player, name: "テスト選手", short_name: "TS", number: "42",
                       position: :catcher, throwing_hand: :right_throw, batting_hand: :left_bat,
                       speed: 3, bunt: 5, steal_start: 10, steal_end: 10, injury_rate: 3)

      get "/api/v1/players", as: :json

      json = response.parsed_body.first
      expect(json).to include(
        "id" => player.id,
        "name" => "テスト選手",
        "short_name" => "TS",
        "number" => "42",
        "position" => "catcher",
        "throwing_hand" => "right_throw",
        "batting_hand" => "left_bat",
        "speed" => 3,
        "bunt" => 5,
        "injury_rate" => 3
      )
    end
  end

  describe "GET /api/v1/players/:id" do
    include_context "authenticated user"

    it "returns 200 with player details" do
      player = create(:player, name: "個別選手")

      get "/api/v1/players/#{player.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["name"]).to eq("個別選手")
    end

    it "returns 404 for non-existent player" do
      get "/api/v1/players/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/players" do
    include_context "authenticated user"

    let(:valid_params) do
      {
        player: {
          name: "新選手", short_name: "NP", number: "99",
          position: "catcher", throwing_hand: "right_throw", batting_hand: "right_bat",
          speed: 3, bunt: 5, steal_start: 10, steal_end: 10, injury_rate: 3
        }
      }
    end

    it "creates a player and returns 201" do
      expect {
        post "/api/v1/players", params: valid_params, as: :json
      }.to change(Player, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns 422 with invalid params" do
      post "/api/v1/players", params: { player: { name: "不完全" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json["errors"]).to be_present
    end
  end

  describe "PATCH /api/v1/players/:id" do
    include_context "authenticated user"

    let!(:player) { create(:player, name: "旧選手名") }

    it "updates the player" do
      patch "/api/v1/players/#{player.id}", params: { player: { name: "新選手名" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(player.reload.name).to eq("新選手名")
    end
  end

  describe "DELETE /api/v1/players/:id" do
    include_context "authenticated user"

    let!(:player) { create(:player) }

    it "deletes the player successfully" do
      expect {
        delete "/api/v1/players/#{player.id}", as: :json
      }.to change(Player, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "unauthenticated access" do
    let!(:player) { create(:player) }

    it "GET /api/v1/players returns 401" do
      get "/api/v1/players", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "GET /api/v1/players/:id returns 401" do
      get "/api/v1/players/#{player.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/players returns 401" do
      post "/api/v1/players", params: { player: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "PATCH /api/v1/players/:id returns 401" do
      patch "/api/v1/players/#{player.id}", params: { player: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "DELETE /api/v1/players/:id returns 401" do
      delete "/api/v1/players/#{player.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
