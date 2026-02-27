require "rails_helper"

RSpec.describe "Api::V1::PlayerCards", type: :request do
  describe "GET /api/v1/player_cards" do
    include_context "authenticated user"

    it "returns 200 with player_cards and meta" do
      create(:player_card)

      get "/api/v1/player_cards"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key("player_cards")
      expect(json).to have_key("meta")
      expect(json["player_cards"]).to be_an(Array)
      expect(json["meta"]).to include("total", "page", "per_page")
    end

    it "includes player_name, player_number, card_set_name, card_type" do
      card = create(:player_card)

      get "/api/v1/player_cards"

      json = response.parsed_body["player_cards"].first
      expect(json["player_name"]).to eq(card.player.name)
      expect(json["player_number"]).to eq(card.player.number)
      expect(json["card_set_name"]).to eq(card.card_set.name)
      expect(json["card_type"]).to eq(card.card_type)
    end

    it "filters by card_set_id" do
      card_set1 = create(:card_set)
      card_set2 = create(:card_set)
      create(:player_card, card_set: card_set1)
      create(:player_card, card_set: card_set2)

      get "/api/v1/player_cards", params: { card_set_id: card_set1.id }

      json = response.parsed_body
      expect(json["meta"]["total"]).to eq(1)
      expect(json["player_cards"].first["card_set_id"]).to eq(card_set1.id)
    end

    it "filters by card_type" do
      create(:player_card, card_type: "pitcher")
      create(:player_card, card_type: "batter")

      get "/api/v1/player_cards", params: { card_type: "pitcher" }

      json = response.parsed_body
      expect(json["meta"]["total"]).to eq(1)
      expect(json["player_cards"].first["card_type"]).to eq("pitcher")
    end

    it "filters by player name (case insensitive partial match)" do
      player_a = create(:player, name: "博麗霊夢")
      player_b = create(:player, name: "霧雨魔理沙")
      create(:player_card, player: player_a)
      create(:player_card, player: player_b)

      get "/api/v1/player_cards", params: { name: "博麗" }

      json = response.parsed_body
      expect(json["meta"]["total"]).to eq(1)
      expect(json["player_cards"].first["player_name"]).to eq("博麗霊夢")
    end

    it "paginates results" do
      create_list(:player_card, 5)

      get "/api/v1/player_cards", params: { page: 1, per_page: 2 }

      json = response.parsed_body
      expect(json["player_cards"].size).to eq(2)
      expect(json["meta"]["total"]).to eq(5)
      expect(json["meta"]["per_page"]).to eq(2)
    end
  end

  describe "GET /api/v1/player_cards/:id" do
    include_context "authenticated user"

    it "returns 200 with detail info" do
      card = create(:player_card)

      get "/api/v1/player_cards/#{card.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(card.id)
      expect(json["card_type"]).to eq(card.card_type)
    end

    it "includes player and card_set nested objects" do
      card = create(:player_card)

      get "/api/v1/player_cards/#{card.id}", as: :json

      json = response.parsed_body
      expect(json["player"]).to include("id", "name", "number")
      expect(json["card_set"]).to include("id", "name")
    end

    it "includes defenses list" do
      card = create(:player_card)
      PlayerCardDefense.create!(
        player_card: card,
        position: "1b",
        range_value: 3,
        error_rank: "B"
      )

      get "/api/v1/player_cards/#{card.id}", as: :json

      json = response.parsed_body
      expect(json["defenses"]).to be_an(Array)
      expect(json["defenses"].first).to include("position", "range_value", "error_rank")
    end

    it "returns 404 for non-existent card" do
      get "/api/v1/player_cards/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/player_cards/:id" do
    include_context "authenticated user"

    let!(:card) { create(:player_card, speed: 3) }

    it "updates the card and returns 200" do
      patch "/api/v1/player_cards/#{card.id}",
            params: { player_card: { speed: 5 } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(card.reload.speed).to eq(5)
    end

    it "returns 422 with invalid params" do
      patch "/api/v1/player_cards/#{card.id}",
            params: { player_card: { speed: 99 } },
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns 404 for non-existent card" do
      patch "/api/v1/player_cards/999999",
            params: { player_card: { speed: 3 } },
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "authentication" do
    it "GET /api/v1/player_cards returns 401 without auth" do
      get "/api/v1/player_cards"
      expect(response).to have_http_status(:unauthorized)
    end

    it "GET /api/v1/player_cards/:id returns 401 without auth" do
      card = create(:player_card)
      get "/api/v1/player_cards/#{card.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "PATCH /api/v1/player_cards/:id returns 401 without auth" do
      card = create(:player_card)
      patch "/api/v1/player_cards/#{card.id}", params: { player_card: { speed: 3 } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
