require "rails_helper"

RSpec.describe "Api::V1::CardSetsController", type: :request do
  describe "GET /api/v1/card_sets" do
    include_context "authenticated user"

    it "returns 200 with empty list when no card sets" do
      get "/api/v1/card_sets", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns all card sets ordered by id" do
      card_sets = create_list(:card_set, 3)

      get "/api/v1/card_sets", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
      expect(json.map { |cs| cs["id"] }).to eq(card_sets.map(&:id).sort)
    end

    it "includes card set attributes" do
      card_set = create(:card_set, year: 2024, set_type: "annual", name: "Test Set")

      get "/api/v1/card_sets", as: :json

      json = response.parsed_body.first
      expect(json).to include(
        "id" => card_set.id,
        "year" => 2024,
        "set_type" => "annual",
        "name" => "Test Set"
      )
    end
  end

  describe "GET /api/v1/card_sets/:id" do
    include_context "authenticated user"

    it "returns 200 with card set details" do
      card_set = create(:card_set, name: "Individual Set")

      get "/api/v1/card_sets/#{card_set.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["name"]).to eq("Individual Set")
    end

    it "returns 404 for non-existent card set" do
      get "/api/v1/card_sets/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "authentication" do
    it "returns 401 when not authenticated for index" do
      get "/api/v1/card_sets", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when not authenticated for show" do
      get "/api/v1/card_sets/1", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
