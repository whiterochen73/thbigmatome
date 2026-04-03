require 'rails_helper'

RSpec.describe "Api::V1::Home", type: :request do
  describe "GET /api/v1/home/summary" do
    include_context "authenticated user"

    let!(:competition) { create(:competition) }
    let!(:home_team) { create(:team) }
    let!(:visitor_team) { create(:team) }
    let!(:stadium) { create(:stadium) }

    context "with valid competition_id" do
      it "returns 200 OK" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        expect(response).to have_http_status(:ok)
      end

      it "includes season_progress key" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        json = JSON.parse(response.body)
        expect(json).to have_key("season_progress")
      end

      it "includes recent_games key" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        json = JSON.parse(response.body)
        expect(json).to have_key("recent_games")
      end

      it "includes batting_top3 key" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        json = JSON.parse(response.body)
        expect(json).to have_key("batting_top3")
      end

      it "includes pitching_top3 key" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        json = JSON.parse(response.body)
        expect(json).to have_key("pitching_top3")
      end

      it "includes team_summary key" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        json = JSON.parse(response.body)
        expect(json).to have_key("team_summary")
      end

      it "season_progress has completed and total fields" do
        get "/api/v1/home/summary", params: { competition_id: competition.id }
        json = JSON.parse(response.body)
        expect(json["season_progress"]).to have_key("completed")
        expect(json["season_progress"]).to have_key("total")
      end
    end

    context "with invalid competition_id" do
      it "returns 404 Not Found" do
        get "/api/v1/home/summary", params: { competition_id: 99999 }
        expect(response).to have_http_status(:not_found)
      end

      it "returns error message" do
        get "/api/v1/home/summary", params: { competition_id: 99999 }
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end
  end
end
