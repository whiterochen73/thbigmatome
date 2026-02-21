require "rails_helper"

RSpec.describe "Api::V1::StadiumsController", type: :request do
  describe "GET /api/v1/stadiums" do
    include_context "authenticated user"

    it "returns 200 with stadiums list" do
      create(:stadium, name: "Stadium A", code: "SA")
      create(:stadium, name: "Stadium B", code: "SB")

      get "/api/v1/stadiums"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to be_an(Array)
      expect(json.length).to eq(2)
    end
  end

  describe "GET /api/v1/stadiums/:id" do
    include_context "authenticated user"

    let!(:stadium) { create(:stadium, name: "Stadium A", code: "SA") }

    it "returns 200 with stadium data" do
      get "/api/v1/stadiums/#{stadium.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(stadium.id)
      expect(json["name"]).to eq("Stadium A")
      expect(json["code"]).to eq("SA")
    end
  end

  describe "POST /api/v1/stadiums" do
    include_context "authenticated user"

    it "creates a stadium and returns 201" do
      post "/api/v1/stadiums",
        params: {
          stadium: {
            name: "New Stadium",
            code: "NS",
            indoor: false,
            up_table_ids: []
          }
        },
        as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["name"]).to eq("New Stadium")
      expect(json["code"]).to eq("NS")

      stadium = Stadium.find_by(code: "NS")
      expect(stadium).to be_present
    end
  end

  describe "PATCH /api/v1/stadiums/:id" do
    include_context "authenticated user"

    let!(:stadium) { create(:stadium, name: "Stadium A", code: "SA") }

    it "updates a stadium and returns 200" do
      patch "/api/v1/stadiums/#{stadium.id}",
        params: {
          stadium: {
            name: "Updated Stadium",
            indoor: true
          }
        },
        as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["name"]).to eq("Updated Stadium")
      expect(json["indoor"]).to be true
    end
  end

  describe "unauthenticated access" do
    it "GET /api/v1/stadiums returns 401" do
      get "/api/v1/stadiums", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/stadiums returns 401" do
      post "/api/v1/stadiums",
        params: { stadium: { name: "Test", code: "T" } },
        as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
