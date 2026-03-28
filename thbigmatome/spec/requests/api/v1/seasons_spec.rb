require "rails_helper"

RSpec.describe "Api::V1::SeasonsController", type: :request do
  describe "POST /api/v1/seasons" do
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }
    let(:team) { create(:team, user_id: owner.id, team_type: "normal") }
    let(:schedule) do
      s = Schedule.create!(name: "日程表1", start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 9, 30), effective_date: Date.new(2026, 1, 1))
      s.schedule_details.create!(date: Date.new(2026, 4, 1), date_type: "game_day")
      s
    end

    context "as commissioner" do
      include_context "authenticated commissioner"

      it "creates a season for any team and returns 201 with team_type set" do
        post "/api/v1/seasons", params: {
          team_id: team.id,
          schedule_id: schedule.id,
          name: "2026シーズン"
        }, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["season"]["team_type"]).to eq("normal")
        expect(json["schedule_count"]).to eq(1)
      end
    end

    context "as owner of the team" do
      before do
        post "/api/v1/auth/login", params: { name: owner.name, password: "password123" }, as: :json
      end

      it "creates a season for own team and returns 201" do
        post "/api/v1/seasons", params: {
          team_id: team.id,
          schedule_id: schedule.id,
          name: "2026シーズン"
        }, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["season"]["team_type"]).to eq("normal")
      end

      it "returns 403 when creating season for another team" do
        other_team = create(:team, user_id: other_user.id)

        post "/api/v1/seasons", params: {
          team_id: other_team.id,
          schedule_id: schedule.id,
          name: "2026シーズン"
        }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as unauthenticated user" do
      it "returns 401" do
        post "/api/v1/seasons", params: {
          team_id: team.id,
          schedule_id: schedule.id,
          name: "2026シーズン"
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/seasons/:id" do
    let(:team) { create(:team) }
    let(:season) { create(:season, team: team) }
    let(:player) { create(:player) }
    let(:team_membership) { create(:team_membership, team: team, player: player) }

    context "as commissioner" do
      include_context "authenticated commissioner"

      it "updates key_player_id and returns 200" do
        patch "/api/v1/seasons/#{season.id}", params: {
          season: { key_player_id: team_membership.id }
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["season"]["key_player_id"]).to eq(team_membership.id)
        expect(json["key_player_name"]).to eq(player.name)
      end

      it "clears key_player_id when set to nil" do
        season.update!(key_player_id: team_membership.id)

        patch "/api/v1/seasons/#{season.id}", params: {
          season: { key_player_id: nil }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(season.reload.key_player_id).to be_nil
      end

      it "returns 404 for non-existent season" do
        patch "/api/v1/seasons/99999", params: {
          season: { key_player_id: nil }
        }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as non-commissioner" do
      include_context "authenticated user"

      it "returns 403" do
        patch "/api/v1/seasons/#{season.id}", params: {
          season: { key_player_id: nil }
        }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as unauthenticated user" do
      it "returns 401" do
        patch "/api/v1/seasons/#{season.id}", params: {
          season: { key_player_id: nil }
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/seasons/:id" do
    let(:team) { create(:team) }
    let(:season) { create(:season, team: team) }

    context "as commissioner" do
      include_context "authenticated commissioner"

      it "destroys the season and returns 204" do
        delete "/api/v1/seasons/#{season.id}"

        expect(response).to have_http_status(:no_content)
        expect(Season.find_by(id: season.id)).to be_nil
      end

      it "returns 404 for non-existent season" do
        delete "/api/v1/seasons/99999"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as non-commissioner" do
      include_context "authenticated user"

      it "returns 403" do
        delete "/api/v1/seasons/#{season.id}"

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as unauthenticated user" do
      it "returns 401" do
        delete "/api/v1/seasons/#{season.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
