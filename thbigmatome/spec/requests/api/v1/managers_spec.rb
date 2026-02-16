require "rails_helper"

RSpec.describe "Api::V1::ManagersController", type: :request do
  describe "GET /api/v1/managers" do
    include_context "authenticated user"

    it "returns 200 with paginated format" do
      get "/api/v1/managers", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key("data")
      expect(json).to have_key("meta")
      expect(json["data"]).to be_an(Array)
    end

    it "returns meta with pagination info" do
      create_list(:manager, 3)

      get "/api/v1/managers", as: :json

      json = response.parsed_body
      meta = json["meta"]
      expect(meta["total_count"]).to eq(3)
      expect(meta["per_page"]).to eq(25)
      expect(meta["current_page"]).to eq(1)
      expect(meta["total_pages"]).to eq(1)
    end

    it "returns managers ordered by id" do
      managers = create_list(:manager, 3)

      get "/api/v1/managers", as: :json

      json = response.parsed_body
      expect(json["data"].map { |m| m["id"] }).to eq(managers.map(&:id).sort)
    end

    it "paginates results with page and per_page params" do
      create_list(:manager, 5)

      get "/api/v1/managers", params: { page: 2, per_page: 2 }

      json = response.parsed_body
      expect(json["data"].size).to eq(2)
      expect(json["meta"]["current_page"]).to eq(2)
      expect(json["meta"]["total_pages"]).to eq(3)
    end

    it "includes team association with has_season" do
      manager = create(:manager)
      team = create(:team)
      TeamManager.create!(team: team, manager: manager, role: :director)

      get "/api/v1/managers", as: :json

      json = response.parsed_body
      manager_data = json["data"].first
      expect(manager_data["teams"]).to be_an(Array)
      expect(manager_data["teams"].first["has_season"]).to eq(false)
    end

    it "clamps invalid page/per_page to defaults" do
      create(:manager)

      get "/api/v1/managers", params: { page: -1, per_page: 0 }

      json = response.parsed_body
      expect(json["meta"]["current_page"]).to eq(1)
      expect(json["meta"]["per_page"]).to eq(25)
    end
  end

  describe "GET /api/v1/managers/:id" do
    include_context "authenticated user"

    it "returns 200 with manager details and teams" do
      manager = create(:manager, name: "テスト監督")
      team = create(:team, name: "所属チーム")
      TeamManager.create!(team: team, manager: manager, role: :director)

      get "/api/v1/managers/#{manager.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["name"]).to eq("テスト監督")
      expect(json["teams"]).to be_an(Array)
      expect(json["teams"].first["name"]).to eq("所属チーム")
    end

    it "returns 404 for non-existent manager" do
      get "/api/v1/managers/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/managers" do
    include_context "authenticated user"

    it "creates a manager and returns 201" do
      expect {
        post "/api/v1/managers", params: { manager: { name: "新監督", short_name: "NM" } }, as: :json
      }.to change(Manager, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["name"]).to eq("新監督")
    end

    it "returns 422 with invalid params" do
      post "/api/v1/managers", params: { manager: { name: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/managers/:id" do
    include_context "authenticated user"

    let!(:manager) { create(:manager, name: "旧監督名") }

    it "updates the manager" do
      patch "/api/v1/managers/#{manager.id}", params: { manager: { name: "新監督名" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(manager.reload.name).to eq("新監督名")
    end

    it "returns 404 for non-existent manager" do
      patch "/api/v1/managers/999999", params: { manager: { name: "X" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/managers/:id" do
    include_context "authenticated user"

    let!(:manager) { create(:manager) }

    it "deletes the manager and returns 204" do
      expect {
        delete "/api/v1/managers/#{manager.id}", as: :json
      }.to change(Manager, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 for non-existent manager" do
      delete "/api/v1/managers/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "unauthenticated access" do
    let!(:manager) { create(:manager) }

    it "GET /api/v1/managers returns 401" do
      get "/api/v1/managers", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "GET /api/v1/managers/:id returns 401" do
      get "/api/v1/managers/#{manager.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/managers returns 401" do
      post "/api/v1/managers", params: { manager: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "PATCH /api/v1/managers/:id returns 401" do
      patch "/api/v1/managers/#{manager.id}", params: { manager: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "DELETE /api/v1/managers/:id returns 401" do
      delete "/api/v1/managers/#{manager.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
