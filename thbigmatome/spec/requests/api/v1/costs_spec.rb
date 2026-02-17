require "rails_helper"

RSpec.describe "Api::V1::CostsController", type: :request do
  describe "GET /api/v1/costs" do
    include_context "authenticated user"

    it "returns 200 with empty list when no costs" do
      get "/api/v1/costs", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns all costs" do
      costs = create_list(:cost, 3)

      get "/api/v1/costs", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
    end

    it "includes cost attributes" do
      cost = create(:cost, name: "2026年コスト表", start_date: Date.new(2026, 1, 1), end_date: nil)

      get "/api/v1/costs", as: :json

      json = response.parsed_body.first
      expect(json).to include(
        "id" => cost.id,
        "name" => "2026年コスト表",
        "start_date" => "2026-01-01",
        "end_date" => nil
      )
    end
  end

  describe "POST /api/v1/costs" do
    include_context "authenticated user"

    it "creates a cost and returns 201" do
      expect {
        post "/api/v1/costs", params: { cost: { name: "新コスト表", start_date: "2026-04-01" } }, as: :json
      }.to change(Cost, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns 422 with invalid params" do
      post "/api/v1/costs", params: { cost: { name: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/costs/:id" do
    include_context "authenticated user"

    let!(:cost) { create(:cost, name: "旧コスト表") }

    it "updates the cost" do
      patch "/api/v1/costs/#{cost.id}", params: { cost: { name: "新コスト表" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(cost.reload.name).to eq("新コスト表")
    end
  end

  describe "DELETE /api/v1/costs/:id" do
    include_context "authenticated user"

    let!(:cost) { create(:cost) }

    it "deletes the cost and returns 204" do
      expect {
        delete "/api/v1/costs/#{cost.id}", as: :json
      }.to change(Cost, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/v1/costs/:id/duplicate" do
    include_context "authenticated user"

    let!(:cost) { create(:cost, name: "元コスト表", start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31)) }

    it "duplicates the cost and returns 201" do
      player = create(:player)
      create(:cost_player, cost: cost, player: player, normal_cost: 5)

      expect {
        post "/api/v1/costs/#{cost.id}/duplicate", as: :json
      }.to change(Cost, :count).by(1).and change(CostPlayer, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["name"]).to eq("元コスト表 (コピー)")
      expect(Date.parse(json["start_date"])).to eq(Date.new(2026, 1, 1))
      expect(Date.parse(json["end_date"])).to eq(Date.new(2026, 12, 31))
    end
  end

  describe "unauthenticated access" do
    let!(:cost) { create(:cost) }

    it "GET /api/v1/costs returns 401" do
      get "/api/v1/costs", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/costs returns 401" do
      post "/api/v1/costs", params: { cost: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "PATCH /api/v1/costs/:id returns 401" do
      patch "/api/v1/costs/#{cost.id}", params: { cost: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "DELETE /api/v1/costs/:id returns 401" do
      delete "/api/v1/costs/#{cost.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/costs/:id/duplicate returns 401" do
      post "/api/v1/costs/#{cost.id}/duplicate", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
