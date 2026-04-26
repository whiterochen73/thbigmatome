require "rails_helper"

RSpec.describe "Api::V1::Commissioner::TeamManagersController", type: :request do
  include_context "authenticated commissioner"

  let(:team) { create(:team, is_active: true) }
  let(:sibling_team) { create(:team, is_active: true) }
  let(:manager) { create(:manager) }
  let(:player) { create(:player) }

  # ─── 正常系 ────────────────────────────────────────────────────────────────

  describe "POST /api/v1/commissioner/teams/:team_id/team_managers (正常系)" do
    it "重複なし director を作成できる" do
      post "/api/v1/commissioner/teams/#{team.id}/team_managers",
           params: { team_manager: { manager_id: manager.id, role: "director" } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(TeamManager.where(team: team, manager: manager, role: :director)).to exist
    end
  end

  # ─── 既存重複（create 時に拒否） ─────────────────────────────────────────

  describe "POST /api/v1/commissioner/teams/:team_id/team_managers (既存重複)" do
    before do
      # manager は sibling_team の director
      create(:team_manager, team: sibling_team, manager: manager, role: :director)
      # sibling_team に player が所属
      create(:team_membership, team: sibling_team, player: player, skip_commissioner_validation: true)
      # team にも同じ player が所属
      create(:team_membership, team: team, player: player, skip_commissioner_validation: true)
    end

    it "sibling チームと選手が重複する場合 422 を返す" do
      post "/api/v1/commissioner/teams/#{team.id}/team_managers",
           params: { team_manager: { manager_id: manager.id, role: "director" } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("選手が重複")
    end
  end

  # ─── director 付け替え重複拒否（update 時に拒否） ────────────────────────

  describe "PATCH /api/v1/commissioner/teams/:team_id/team_managers/:id (director 付け替え重複拒否)" do
    let(:old_manager) { create(:manager) }
    let(:new_manager) { create(:manager) }
    let!(:team_manager) { create(:team_manager, team: team, manager: old_manager, role: :director) }

    before do
      # new_manager は sibling_team の director
      create(:team_manager, team: sibling_team, manager: new_manager, role: :director)
      # sibling_team に player が所属
      create(:team_membership, team: sibling_team, player: player, skip_commissioner_validation: true)
      # team にも同じ player が所属
      create(:team_membership, team: team, player: player, skip_commissioner_validation: true)
    end

    it "新しい director の sibling チームと選手が重複する場合 422 を返す" do
      patch "/api/v1/commissioner/teams/#{team.id}/team_managers/#{team_manager.id}",
            params: { team_manager: { manager_id: new_manager.id } },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("選手が重複")
    end
  end

  # ─── director_team_limit 両立 ─────────────────────────────────────────────

  describe "POST /api/v1/commissioner/teams/:team_id/team_managers (director_team_limit 両立)" do
    let(:team_a) { create(:team, is_active: true) }
    let(:team_b) { create(:team, is_active: true) }

    before do
      # manager はすでに 2 チームの director（上限）
      create(:team_manager, team: team_a, manager: manager, role: :director)
      create(:team_manager, team: team_b, manager: manager, role: :director)
    end

    it "director_team_limit（2チーム上限）違反時に 422 を返す" do
      post "/api/v1/commissioner/teams/#{team.id}/team_managers",
           params: { team_manager: { manager_id: manager.id, role: "director" } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
