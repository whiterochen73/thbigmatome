require "rails_helper"

RSpec.describe "Api::V1::Competitions", type: :request do
  describe "GET /api/v1/competitions" do
    include_context "authenticated user"

    it "returns 200" do
      get "/api/v1/competitions", as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/competitions" do
    include_context "authenticated user"

    it "creates competition" do
      post "/api/v1/competitions",
           params: { competition: { name: "テスト大会", year: 2026, competition_type: "league_pennant" } },
           as: :json
      expect(response).to have_http_status(:created)
    end
  end

  describe "authentication" do
    it "returns 401 without auth" do
      get "/api/v1/competitions", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
