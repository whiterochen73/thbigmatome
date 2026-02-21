require "rails_helper"

RSpec.describe "Api::V1::PlayerCards", type: :request do
  describe "GET /api/v1/player_cards" do
    include_context "authenticated user"

    it "returns 200" do
      get "/api/v1/player_cards", as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "authentication" do
    it "returns 401 without auth" do
      get "/api/v1/player_cards", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
