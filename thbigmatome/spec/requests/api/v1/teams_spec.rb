require "rails_helper"

RSpec.describe "Api::V1::TeamsController", type: :request do
  describe "GET /api/v1/teams" do
    include_context "authenticated user"

    it "returns 200 with empty list when no teams" do
      get "/api/v1/teams", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns all teams" do
      teams = create_list(:team, 3)

      get "/api/v1/teams", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
      expect(json.map { |t| t["id"] }).to match_array(teams.map(&:id))
    end

    it "includes team attributes" do
      team = create(:team, name: "テストチーム", short_name: "TC", is_active: true)

      get "/api/v1/teams", as: :json

      json = response.parsed_body.first
      expect(json).to include(
        "id" => team.id,
        "name" => "テストチーム",
        "short_name" => "TC",
        "is_active" => true,
        "has_season" => false
      )
    end

    it "includes director and coaches" do
      team = create(:team)
      director = create(:manager, name: "監督A", role: :director)
      coach = create(:manager, name: "コーチA", role: :coach)
      TeamManager.create!(team: team, manager: director, role: :director)
      TeamManager.create!(team: team, manager: coach, role: :coach)

      get "/api/v1/teams", as: :json

      json = response.parsed_body.first
      expect(json["director"]["name"]).to eq("監督A")
      expect(json["coaches"].size).to eq(1)
      expect(json["coaches"].first["name"]).to eq("コーチA")
    end
  end

  describe "GET /api/v1/teams/:id" do
    include_context "authenticated user"

    it "returns 200 with team details" do
      team = create(:team, name: "詳細チーム")

      get "/api/v1/teams/#{team.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["name"]).to eq("詳細チーム")
    end

    it "returns 404 for non-existent team" do
      get "/api/v1/teams/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/teams" do
    include_context "authenticated user"

    it "creates a team and returns 201" do
      expect {
        post "/api/v1/teams", params: { team: { name: "新チーム", short_name: "NT", is_active: true } }, as: :json
      }.to change(Team, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["name"]).to eq("新チーム")
    end

    it "returns 422 with invalid params" do
      post "/api/v1/teams", params: { team: { name: "", short_name: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json["errors"]).to be_present
    end

    it "assigns director and coaches" do
      director = create(:manager, role: :director)
      coach = create(:manager, role: :coach)

      post "/api/v1/teams",
        params: { team: { name: "フルチーム", short_name: "FT", is_active: true, director_id: director.id, coach_ids: [ coach.id ] } },
        as: :json

      expect(response).to have_http_status(:created)
      team = Team.last
      expect(team.director).to eq(director)
      expect(team.coaches).to include(coach)
    end
  end

  describe "PATCH /api/v1/teams/:id" do
    include_context "authenticated user"

    let!(:team) { create(:team, name: "旧名前") }

    it "updates the team" do
      patch "/api/v1/teams/#{team.id}", params: { team: { name: "新名前" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(team.reload.name).to eq("新名前")
    end

    it "returns 404 for non-existent team" do
      patch "/api/v1/teams/999999", params: { team: { name: "X" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/teams/:id" do
    include_context "authenticated user"

    let!(:team) { create(:team) }

    it "deletes the team and returns 204" do
      expect {
        delete "/api/v1/teams/#{team.id}", as: :json
      }.to change(Team, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 for non-existent team" do
      delete "/api/v1/teams/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "unauthenticated access" do
    let!(:team) { create(:team) }

    it "GET /api/v1/teams returns 401" do
      get "/api/v1/teams", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "GET /api/v1/teams/:id returns 401" do
      get "/api/v1/teams/#{team.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /api/v1/teams returns 401" do
      post "/api/v1/teams", params: { team: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "PATCH /api/v1/teams/:id returns 401" do
      patch "/api/v1/teams/#{team.id}", params: { team: { name: "X" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "DELETE /api/v1/teams/:id returns 401" do
      delete "/api/v1/teams/#{team.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
