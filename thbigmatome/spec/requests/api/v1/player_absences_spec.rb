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

  describe "POST/PATCH /api/v1/player_absences の phase（試合前 / 試合中。AMB-25）" do
    include_context "authenticated user"

    let(:team) { create(:team) }
    let(:season) { create(:season, team: team) }
    let(:membership) { create(:team_membership, team: team, player: create(:player)) }
    let(:base_params) do
      { team_membership_id: membership.id, season_id: season.id, absence_type: "injury",
        start_date: "2026-04-10", duration: 3, duration_unit: "days" }
    end

    it "phase を渡さなければ pre_game で保存され、レスポンスに phase と effective_start_date が入る" do
      post "/api/v1/player_absences", params: { player_absence: base_params }, as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["phase"]).to eq("pre_game")
      expect(json["effective_start_date"]).to eq("2026-04-10")
      expect(json["effective_end_date"]).to eq("2026-04-13")
      expect(PlayerAbsence.last.phase).to eq("pre_game")
    end

    it "phase: in_game で保存でき、effective_start_date は翌日・復帰日は D+N+1" do
      post "/api/v1/player_absences", params: { player_absence: base_params.merge(phase: "in_game") }, as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["phase"]).to eq("in_game")
      expect(json["start_date"]).to eq("2026-04-10")
      expect(json["effective_start_date"]).to eq("2026-04-11")
      expect(json["effective_end_date"]).to eq("2026-04-14")
    end

    it "phase の不正値は 422 で、離脱は作られない" do
      expect {
        post "/api/v1/player_absences", params: { player_absence: base_params.merge(phase: "after_game") }, as: :json
      }.not_to change(PlayerAbsence, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["phase"]).to be_present
    end

    it "phase が空文字でも 422（既定値に黙って倒さない）" do
      post "/api/v1/player_absences", params: { player_absence: base_params.merge(phase: "") }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "0 日の離脱は記録しない（従来どおり 422）" do
      post "/api/v1/player_absences", params: { player_absence: base_params.merge(duration: 0, phase: "in_game") }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "出場停止・調整にも同じ区分と数え方を当てる" do
      %w[suspension reconditioning].each do |type|
        post "/api/v1/player_absences",
          params: { player_absence: base_params.merge(absence_type: type, phase: "in_game", duration: 1) }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include("absence_type" => type, "effective_start_date" => "2026-04-11", "effective_end_date" => "2026-04-12")
      end
    end

    it "PATCH で区分を変えられ、不正値は 422 で元の値のまま" do
      absence = create(:player_absence, team_membership: membership, season: season, start_date: Date.new(2026, 4, 10), duration: 2)

      patch "/api/v1/player_absences/#{absence.id}", params: { player_absence: { phase: "in_game" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("phase" => "in_game", "effective_end_date" => "2026-04-13")

      patch "/api/v1/player_absences/#{absence.id}", params: { player_absence: { phase: "bogus" } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(absence.reload.phase).to eq("in_game")
    end

    it "一覧にも phase と effective_start_date が入る" do
      create(:player_absence, team_membership: membership, season: season, start_date: Date.new(2026, 4, 10), phase: "in_game")

      get "/api/v1/player_absences", params: { season_id: season.id }

      expect(response.parsed_body.first).to include("phase" => "in_game", "effective_start_date" => "2026-04-11")
    end
  end
end
