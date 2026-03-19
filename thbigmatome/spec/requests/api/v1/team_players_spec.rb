require "rails_helper"

RSpec.describe "Api::V1::TeamPlayers", type: :request do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }

  def post_team_players(team_id, players:, cost_list_id: cost.id)
    post "/api/v1/teams/#{team_id}/team_players",
      params: {
        players: players,
        cost_list_id: cost_list_id
      },
      as: :json
  end

  def player_param(player, cost_type: "normal_cost", excluded: false, display_name: nil)
    {
      player_id: player.id,
      selected_cost_type: cost_type,
      excluded_from_team_total: excluded,
      display_name: display_name
    }
  end

  # ============================================================
  # GET /api/v1/teams/:team_id/team_players
  # ============================================================

  describe "GET /api/v1/teams/:team_id/team_players" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    it "returns 200 with team players" do
      player = create(:player)
      create(:team_membership, team: team, player: player, selected_cost_type: "normal_cost")
      create(:cost_player, cost: cost, player: player, normal_cost: 5)

      get "/api/v1/teams/#{team.id}/team_players", as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  # ============================================================
  # POST /api/v1/teams/:team_id/team_players (commissioner)
  # ============================================================

  describe "POST /api/v1/teams/:team_id/team_players (commissioner mode)" do
    include_context "authenticated commissioner"
    before { team.update!(user: user) }

    context "commissioner がチーム総コスト超過でも200 + warning が返る" do
      it "returns 200 with warning when team total cost exceeds limit" do
        # TEAM_TOTAL_MAX_COST = 200
        # Add players whose total cost exceeds 200 (excluded=false)
        players = []
        21.times do
          p = create(:player)
          create(:cost_player, cost: cost, player: p, normal_cost: 10)
          players << p
        end
        # 21 * 10 = 210 > 200

        post_team_players(team.id, players: players.map { |p| player_param(p) })

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["warnings"]).to be_an(Array)
        expect(json["warnings"]).not_to be_empty
      end
    end

    context "commissioner がsibling team選手を追加しても200 + warning が返る" do
      it "returns 200 with no validation error when adding sibling team player" do
        # Set up sibling team with same director
        manager = create(:manager)
        sibling_team = create(:team)
        create(:team_manager, team: team, manager: manager, role: :director)
        create(:team_manager, team: sibling_team, manager: manager, role: :director)

        # Player already in sibling team
        player = create(:player)
        create(:team_membership, team: sibling_team, player: player, selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        post_team_players(team.id, players: [ player_param(player) ])

        expect(response).to have_http_status(:ok)
      end
    end

    context "commissioner が非除外選手を正常に登録できる" do
      it "returns 200 with empty warnings for valid roster" do
        player = create(:player)
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        post_team_players(team.id, players: [ player_param(player) ])

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["warnings"]).to be_an(Array)
        expect(json["warnings"]).to be_empty
      end
    end
  end

  # ============================================================
  # POST /api/v1/teams/:team_id/team_players (non-commissioner)
  # ============================================================

  describe "POST /api/v1/teams/:team_id/team_players (non-commissioner)" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    context "非commissioner はチーム総コスト超過で422が返る" do
      it "returns 422 when team total cost exceeds limit" do
        players = []
        21.times do
          p = create(:player)
          create(:cost_player, cost: cost, player: p, normal_cost: 10)
          players << p
        end

        post_team_players(team.id, players: players.map { |p| player_param(p) })

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to be_present
      end
    end

    context "非commissioner はsibling team選手追加で422が返る" do
      it "returns 422 when adding player already in sibling team" do
        manager = create(:manager)
        sibling_team = create(:team)
        create(:team_manager, team: team, manager: manager, role: :director)
        create(:team_manager, team: sibling_team, manager: manager, role: :director)

        player = create(:player)
        create(:team_membership, team: sibling_team, player: player, selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        post_team_players(team.id, players: [ player_param(player) ])

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "valid roster" do
      it "returns 200 for valid team members" do
        player = create(:player)
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        post_team_players(team.id, players: [ player_param(player) ])

        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ============================================================
  # POST /api/v1/teams/:team_id/team_players (unauthenticated)
  # ============================================================

  describe "POST /api/v1/teams/:team_id/team_players (unauthenticated)" do
    it "returns 401" do
      post_team_players(team.id, players: [])

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
