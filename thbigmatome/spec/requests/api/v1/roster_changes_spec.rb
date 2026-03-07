require "rails_helper"

RSpec.describe "Api::V1::RosterChanges", type: :request do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }

  def roster_changes_url
    "/api/v1/teams/#{team.id}/roster_changes"
  end

  describe "認証なしアクセス" do
    it "GET /roster_changes → 401" do
      get roster_changes_url, params: { since: "2025-06-01", season_id: season.id }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/teams/:team_id/roster_changes" do
    include_context "authenticated user"

    context "パラメータ不足" do
      it "sinceがない場合は422を返す" do
        get roster_changes_url, params: { season_id: season.id }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "season_idがない場合は422を返す" do
        get roster_changes_url, params: { since: "2025-06-01" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "正常レスポンス" do
      it "changes配列とtextを含むJSONを返す" do
        get roster_changes_url, params: { since: "2025-06-01", season_id: season.id }
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key("changes")
        expect(json).to have_key("text")
        expect(json["changes"]).to be_an(Array)
      end

      it "since以降の変更が含まれる" do
        player = create(:player, name: "ユキ", number: "78")
        tm = create(:team_membership, team: team, player: player, squad: "first")
        create(:season_roster, team_membership: tm, season: season, squad: "first",
               registered_on: Date.new(2025, 6, 4))

        get roster_changes_url, params: { since: "2025-06-01", season_id: season.id }
        json = response.parsed_body
        expect(json["changes"].length).to eq(1)
        expect(json["changes"].first["type"]).to eq("promote")
        expect(json["changes"].first["player_name"]).to eq("ユキ")
        expect(json["text"]).to include("登録：78 ユキ")
      end

      it "変更なしの場合は空配列と空textを返す" do
        get roster_changes_url, params: { since: "2025-06-01", season_id: season.id }
        json = response.parsed_body
        expect(json["changes"]).to be_empty
        expect(json["text"]).to eq("")
      end
    end
  end
end
