require "rails_helper"

RSpec.describe "Api::V1::CostAssignmentsController", type: :request do
  describe "GET /api/v1/cost_assignments" do
    include_context "authenticated user"

    let!(:cost) { create(:cost) }
    let!(:player) { create(:player) }

    it "returns 200 with players and cost info" do
      create(:cost_player, cost: cost, player: player, normal_cost: 5, relief_only_cost: 3)

      get "/api/v1/cost_assignments", params: { cost_id: cost.id }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to be_an(Array)

      player_data = json.find { |p| p["id"] == player.id }
      expect(player_data).to be_present
      expect(player_data["normal_cost"]).to eq(5)
      expect(player_data["relief_only_cost"]).to eq(3)
    end

    it "returns nil costs for players without cost assignment" do
      get "/api/v1/cost_assignments", params: { cost_id: cost.id }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      player_data = json.find { |p| p["id"] == player.id }
      expect(player_data["normal_cost"]).to be_nil
    end
  end

  describe "POST /api/v1/cost_assignments" do
    include_context "authenticated user"

    let!(:cost) { create(:cost) }
    let!(:player) { create(:player) }

    it "creates cost assignments" do
      post "/api/v1/cost_assignments",
        params: {
          assignments: {
            cost_id: cost.id,
            players: [
              { player_id: player.id, normal_cost: 7, relief_only_cost: nil, pitcher_only_cost: nil, fielder_only_cost: nil, two_way_cost: nil }
            ]
          }
        },
        as: :json

      expect(response).to have_http_status(:no_content)

      cost_player = CostPlayer.find_by(cost: cost, player: player)
      expect(cost_player).to be_present
      expect(cost_player.normal_cost).to eq(7)
    end

    it "updates existing cost assignments" do
      create(:cost_player, cost: cost, player: player, normal_cost: 5)

      post "/api/v1/cost_assignments",
        params: {
          assignments: {
            cost_id: cost.id,
            players: [
              { player_id: player.id, normal_cost: 10, relief_only_cost: nil, pitcher_only_cost: nil, fielder_only_cost: nil, two_way_cost: nil }
            ]
          }
        },
        as: :json

      expect(response).to have_http_status(:no_content)
      cost_player = CostPlayer.find_by(cost: cost, player: player)
      expect(cost_player.normal_cost).to eq(10)
    end
  end

  describe "unauthenticated access" do
    it "GET /api/v1/cost_assignments returns 401" do
      get "/api/v1/cost_assignments", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/cost_assignments returns 401" do
      post "/api/v1/cost_assignments", params: { assignments: {} }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
