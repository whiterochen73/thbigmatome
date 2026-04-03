require "rails_helper"

RSpec.describe "Api::V1::PlayerAbsencesController", type: :request do
  describe "GET /api/v1/player_absences" do
    include_context "authenticated user"

    let(:team) { create(:team) }
    let(:season) { create(:season, team: team) }
    let(:player) { create(:player) }
    let(:team_membership) { create(:team_membership, team: team, player: player) }

    context "season_idのみ指定" do
      before do
        create(:player_absence, team_membership: team_membership, season: season)
      end

      it "200を返し離脱情報を返す" do
        get "/api/v1/player_absences", params: { season_id: season.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.length).to eq(1)
      end
    end

    context "team_idのみ指定" do
      let(:other_team) { create(:team) }
      let(:other_season) { create(:season, team: other_team) }
      let(:other_player) { create(:player) }
      let(:other_membership) { create(:team_membership, team: other_team, player: other_player) }

      before do
        create(:player_absence, team_membership: team_membership, season: season)
        create(:player_absence, team_membership: other_membership, season: other_season)
      end

      it "200を返し指定チームのメンバーの離脱のみ返す" do
        get "/api/v1/player_absences", params: { team_id: team.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.length).to eq(1)
      end
    end

    context "season_idもteam_idもなし" do
      it "400を返す" do
        get "/api/v1/player_absences"

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]).to eq("season_id or team_id is required")
      end
    end

    context "team_idでチームにシーズンがない" do
      let(:team_without_season) { create(:team) }

      it "422を返す" do
        get "/api/v1/player_absences", params: { team_id: team_without_season.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("team has no season")
      end
    end
  end
end
