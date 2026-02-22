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
    include_context "authenticated commissioner"

    it "creates competition" do
      post "/api/v1/competitions",
           params: { competition: { name: "テスト大会", year: 2026, competition_type: "league_pennant" } },
           as: :json
      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /api/v1/competitions/:id/teams" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }

    it "returns 200 and empty array when no entries" do
      get "/api/v1/competitions/#{competition.id}/teams", as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns teams for the competition" do
      team = create(:team)
      create(:competition_entry, competition: competition, team: team)

      get "/api/v1/competitions/#{competition.id}/teams", as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first["name"]).to eq(team.name)
    end
  end

  describe "authentication" do
    it "returns 401 without auth" do
      get "/api/v1/competitions", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
