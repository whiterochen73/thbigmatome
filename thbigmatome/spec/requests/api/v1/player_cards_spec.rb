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

    it "includes cost from the player's latest cost_player record" do
      cost = create(:cost)
      card = create(:player_card)
      create(:cost_player, cost: cost, player: card.player, normal_cost: 7)

      get "/api/v1/player_cards"

      json = response.parsed_body["player_cards"].first
      expect(json["cost"]).to eq(7)
    end

    it "returns null cost when player has no cost_player record" do
      create(:player_card)

      get "/api/v1/player_cards"

      json = response.parsed_body["player_cards"].first
      expect(json["cost"]).to be_nil
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

    it "includes defenses list with id" do
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
      expect(json["defenses"].first).to include("id", "position", "range_value", "error_rank")
    end

    it "includes new fields: handedness, is_switch_hitter, is_dual_wielder, is_closer, biorhythm_period" do
      card = create(:player_card,
        handedness: "右",
        is_switch_hitter: true,
        is_dual_wielder: false,
        is_closer: true,
        biorhythm_period: "小暑"
      )

      get "/api/v1/player_cards/#{card.id}", as: :json

      json = response.parsed_body
      expect(json["handedness"]).to eq("右")
      expect(json["is_switch_hitter"]).to be true
      expect(json["is_dual_wielder"]).to be false
      expect(json["is_closer"]).to be true
      expect(json["biorhythm_period"]).to eq("小暑")
    end

    it "includes trait_list with condition info" do
      card = create(:player_card)
      td = TraitDefinition.create!(name: "変化球投手", description: "変化球が得意")
      tc = TraitCondition.create!(name: "対左", description: "左打者に対して")
      PlayerCardTrait.create!(player_card: card, trait_definition: td, condition: tc)

      get "/api/v1/player_cards/#{card.id}", as: :json

      json = response.parsed_body
      trait = json["trait_list"].first
      expect(trait["name"]).to eq("変化球投手")
      expect(trait["condition_name"]).to eq("対左")
      expect(trait["condition_description"]).to eq("左打者に対して")
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

    it "updates new fields: handedness, is_switch_hitter, is_dual_wielder, is_closer, biorhythm_period" do
      patch "/api/v1/player_cards/#{card.id}",
            params: {
              player_card: {
                handedness: "左",
                is_switch_hitter: true,
                is_dual_wielder: true,
                is_closer: true,
                biorhythm_period: "大寒"
              }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      card.reload
      expect(card.handedness).to eq("左")
      expect(card.is_switch_hitter).to be true
      expect(card.is_dual_wielder).to be true
      expect(card.is_closer).to be true
      expect(card.biorhythm_period).to eq("大寒")
    end

    it "updates player_card_defenses via nested attributes" do
      defense = PlayerCardDefense.create!(
        player_card: card, position: "1b", range_value: 3, error_rank: "B"
      )

      patch "/api/v1/player_cards/#{card.id}",
            params: {
              player_card: {
                player_card_defenses_attributes: [
                  { id: defense.id, range_value: 5, position: "1b", error_rank: "A" }
                ]
              }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(defense.reload.range_value).to eq(5)
    end

    it "adds a new defense via nested attributes" do
      expect {
        patch "/api/v1/player_cards/#{card.id}",
              params: {
                player_card: {
                  player_card_defenses_attributes: [
                    { position: "cf", range_value: 4, error_rank: "C" }
                  ]
                }
              },
              as: :json
      }.to change { card.player_card_defenses.count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it "destroys a defense via nested attributes with _destroy" do
      defense = PlayerCardDefense.create!(
        player_card: card, position: "1b", range_value: 3, error_rank: "B"
      )

      expect {
        patch "/api/v1/player_cards/#{card.id}",
              params: {
                player_card: {
                  player_card_defenses_attributes: [
                    { id: defense.id, _destroy: true }
                  ]
                }
              },
              as: :json
      }.to change { card.player_card_defenses.count }.by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "adds a trait via nested attributes" do
      td = TraitDefinition.create!(name: "長打力", description: "長打が得意")

      expect {
        patch "/api/v1/player_cards/#{card.id}",
              params: {
                player_card: {
                  player_card_traits_attributes: [
                    { trait_definition_id: td.id, role: "main" }
                  ]
                }
              },
              as: :json
      }.to change { card.player_card_traits.count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it "removes a trait via nested attributes with _destroy" do
      td = TraitDefinition.create!(name: "長打力", description: "長打が得意")
      trait = PlayerCardTrait.create!(player_card: card, trait_definition: td)

      expect {
        patch "/api/v1/player_cards/#{card.id}",
              params: {
                player_card: {
                  player_card_traits_attributes: [
                    { id: trait.id, _destroy: true }
                  ]
                }
              },
              as: :json
      }.to change { card.player_card_traits.count }.by(-1)

      expect(response).to have_http_status(:ok)
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
