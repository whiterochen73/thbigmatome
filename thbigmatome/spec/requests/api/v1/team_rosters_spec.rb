require "rails_helper"

RSpec.describe "Api::V1::TeamRosters", type: :request do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }

  # Helper: add a player to the team with cost setup
  def add_player_to_team(team:, cost:, squad: "second", cost_value: 5, cost_type: "normal_cost", excluded: false, player_trait: nil)
    player = player_trait ? create(:player, player_trait) : create(:player)
    membership = create(:team_membership,
      team: team,
      player: player,
      squad: squad,
      selected_cost_type: cost_type,
      excluded_from_team_total: excluded
    )
    create(:cost_player, cost: cost, player: player, normal_cost: cost_value)
    { player: player, membership: membership }
  end

  # ============================================================
  # GET /api/v1/teams/:team_id/roster
  # ============================================================

  describe "GET /api/v1/teams/:team_id/roster" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    let!(:season_schedule) do
      create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
    end

    context "when the team has a season and roster" do
      let!(:first_squad_result) do
        add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 5)
      end
      let!(:second_squad_result) do
        add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)
      end

      it "returns 200 with roster data" do
        get "/api/v1/teams/#{team.id}/roster", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["season_id"]).to eq(season.id)
        expect(json["current_date"]).to eq("2026-05-15")
        expect(json["roster"]).to be_an(Array)
        expect(json["roster"].size).to eq(2)
      end

      it "includes first and second squad players" do
        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        squads = json["roster"].map { |r| r["squad"] }
        expect(squads).to include("first", "second")
      end

      it "includes player details in roster entries" do
        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].find { |r| r["team_membership_id"] == first_squad_result[:membership].id }
        expect(entry).to include(
          "player_id" => first_squad_result[:player].id,
          "player_name" => first_squad_result[:player].short_name,
          "squad" => "first",
          "cost" => 5
        )
      end

      it "includes absence info (is_absent=false when no absence)" do
        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].first
        expect(entry["is_absent"]).to be false
        expect(entry["absence_info"]).to be_nil
      end
    end

    context "when a player has an active absence" do
      let!(:player_result) do
        add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 5)
      end
      let!(:absence) do
        create(:player_absence, :injury,
          team_membership: player_result[:membership],
          season: season,
          start_date: Date.new(2026, 5, 10),
          duration: 10,
          duration_unit: "days",
          reason: "Test injury"
        )
      end

      it "includes absence information" do
        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].find { |r| r["team_membership_id"] == player_result[:membership].id }
        expect(entry["is_absent"]).to be true
        expect(entry["absence_info"]["absence_type"]).to eq("injury")
        expect(entry["absence_info"]["reason"]).to eq("Test injury")
        expect(entry["absence_info"]["effective_end_date"]).to eq("2026-05-20")
      end
    end

    context "pitcher fields (is_starter_pitcher / is_relief_only)" do
      it "returns is_starter_pitcher=true when pitcher has player_card with starter_stamina >= 4" do
        player = create(:player, :pitcher)
        create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: player, normal_cost: 5)
        create(:player_card, player: player, is_pitcher: true, starter_stamina: 5, is_relief_only: false)

        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].find { |r| r["player_id"] == player.id }
        expect(entry["is_starter_pitcher"]).to be true
        expect(entry["is_relief_only"]).to be false
      end

      it "returns is_starter_pitcher=false when pitcher has no player_card" do
        player = create(:player, :pitcher)
        create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: player, normal_cost: 5)
        # no player_card created → player_cards.first == nil

        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].find { |r| r["player_id"] == player.id }
        expect(entry["is_starter_pitcher"]).to be false
      end

      it "returns is_relief_only=true when player_card.is_relief_only is true" do
        player = create(:player, :pitcher)
        create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: player, normal_cost: 5)
        create(:player_card, player: player, is_pitcher: true, is_relief_only: true, starter_stamina: nil)

        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].find { |r| r["player_id"] == player.id }
        expect(entry["is_relief_only"]).to be true
        expect(entry["is_starter_pitcher"]).to be false
      end

      it "returns is_starter_pitcher=false and is_relief_only=false for non-pitcher" do
        player = create(:player, :fielder)
        create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        get "/api/v1/teams/#{team.id}/roster", as: :json

        json = response.parsed_body
        entry = json["roster"].find { |r| r["player_id"] == player.id }
        expect(entry["is_starter_pitcher"]).to be false
        expect(entry["is_relief_only"]).to be false
      end
    end

    context "previous_game_date field" do
      it "returns the most recent schedule date before current_date" do
        # season_schedule at 2026-04-01 already exists from outer let!
        create(:season_schedule, season: season, date: Date.new(2026, 5, 12), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 5, 20), date_type: "game_day")

        get "/api/v1/teams/#{team.id}/roster", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["previous_game_date"]).to eq("2026-05-12")
      end

      it "returns previous_game_date when only older schedules exist" do
        # season_schedule at 2026-04-01 from outer let! is the only one before current_date

        get "/api/v1/teams/#{team.id}/roster", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["previous_game_date"]).to eq("2026-04-01")
      end

      it "returns nil when no schedules exist before current_date" do
        # Override season with a current_date before any schedule
        season.update!(current_date: Date.new(2026, 3, 1))

        get "/api/v1/teams/#{team.id}/roster", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["previous_game_date"]).to be_nil
      end
    end

    context "when team does not exist" do
      it "returns 404" do
        get "/api/v1/teams/999999/roster", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when team has no season" do
      let(:team_no_season) { create(:team, user: user) }

      it "returns 404" do
        get "/api/v1/teams/#{team_no_season.id}/roster", as: :json

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to include("Season")
      end
    end
  end

  describe "GET /api/v1/teams/:team_id/roster (unauthenticated)" do
    let!(:season_schedule) do
      create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/teams/#{team.id}/roster", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ============================================================
  # POST /api/v1/teams/:team_id/roster
  # ============================================================

  describe "POST /api/v1/teams/:team_id/roster" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    let(:target_date) { Date.new(2026, 5, 15) }

    # Season schedule setup: start on Apr 1, game day on target_date
    let!(:season_start_schedule) do
      create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
    end

    def post_roster_update(team_id, roster_updates, date: target_date)
      post "/api/v1/teams/#{team_id}/roster",
        params: {
          roster_updates: roster_updates,
          target_date: date.to_s
        },
        as: :json
    end

    # ============================================================
    # Promotion (second -> first)
    # ============================================================

    context "promotion (second -> first)" do
      it "successfully promotes a player" do
        # Setup: 25 players already in first squad (minimum), 1 player in second
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["message"]).to include("successfully")
        expect(result[:membership].reload.squad).to eq("first")
      end

      it "creates a SeasonRoster entry on promotion" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        expect {
          post_roster_update(team.id, [
            { team_membership_id: result[:membership].id, squad: "first" }
          ])
        }.to change(SeasonRoster, :count).by(1)

        roster_entry = SeasonRoster.last
        expect(roster_entry.squad).to eq("first")
        expect(roster_entry.team_membership).to eq(result[:membership])
        expect(roster_entry.registered_on).to eq(target_date)
      end

      it "rejects promotion when player is on cooldown" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        # Create a promotion record (past) then a demotion record (5 days ago)
        # Cooldown = 10 days from demotion, so still on cooldown
        create(:season_roster,
          season: season,
          team_membership: result[:membership],
          squad: "first",
          registered_on: Date.new(2026, 5, 1)
        )
        create(:season_roster,
          season: season,
          team_membership: result[:membership],
          squad: "second",
          registered_on: Date.new(2026, 5, 10)
        )

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to include("cooldown")
        expect(result[:membership].reload.squad).to eq("second")
      end

      it "allows promotion with same_day_exempt (promoted and demoted on same day)" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        # Same-day promotion and demotion: both on May 10
        promotion = create(:season_roster,
          season: season,
          team_membership: result[:membership],
          squad: "first",
          registered_on: Date.new(2026, 5, 10)
        )
        create(:season_roster,
          season: season,
          team_membership: result[:membership],
          squad: "second",
          registered_on: Date.new(2026, 5, 10),
          created_at: promotion.created_at + 1.hour
        )

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:ok)
        expect(result[:membership].reload.squad).to eq("first")
      end

      it "rejects promotion for reconditioning player" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        create(:player_absence, :reconditioning,
          team_membership: result[:membership],
          season: season,
          start_date: Date.new(2026, 5, 10),
          duration: 30,
          duration_unit: "days"
        )

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to include("再調整中")
        expect(result[:membership].reload.squad).to eq("second")
      end

      it "returns warnings when promoting an injured player" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        create(:player_absence, :injury,
          team_membership: result[:membership],
          season: season,
          start_date: Date.new(2026, 5, 10),
          duration: 30,
          duration_unit: "days"
        )

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["warnings"]).to be_an(Array)
        expect(json["warnings"].size).to eq(1)
        expect(json["warnings"].first["type"]).to eq("player_absent")
        expect(result[:membership].reload.squad).to eq("first")
      end

      it "rejects promotion when 1st squad cost limit is exceeded" do
        # 25 players in first squad, each with cost 4 = total 100
        # cost limit for 26 players = 117
        # promoting a player with cost 18 would make total 118 > 117
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 18)

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to include("コスト")
      end

      it "allows promotion at exact cost limit boundary" do
        # 25 players in first squad, each cost 4 = 100
        # cost limit for 26 players = 117
        # promoting a player with cost 17 = total 117 = exactly at limit
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 17)

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:ok)
      end

      # outside world limit test removed: player_player_types table dropped (cmd_511 Phase 2b)
    end

    # ============================================================
    # Demotion (first -> second)
    # ============================================================

    context "demotion (first -> second)" do
      it "successfully demotes a player" do
        # 26 players in first squad (above minimum), demote 1
        26.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        target_membership = team.team_memberships.where(squad: "first").first

        post_roster_update(team.id, [
          { team_membership_id: target_membership.id, squad: "second" }
        ])

        expect(response).to have_http_status(:ok)
        expect(target_membership.reload.squad).to eq("second")
      end

      it "creates a SeasonRoster entry on demotion" do
        26.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        target_membership = team.team_memberships.where(squad: "first").first

        expect {
          post_roster_update(team.id, [
            { team_membership_id: target_membership.id, squad: "second" }
          ])
        }.to change(SeasonRoster, :count).by(1)

        roster_entry = SeasonRoster.last
        expect(roster_entry.squad).to eq("second")
        expect(roster_entry.team_membership).to eq(target_membership)
      end
    end
  end

  describe "POST /api/v1/teams/:team_id/roster (unauthenticated)" do
    let(:target_date) { Date.new(2026, 5, 15) }

    it "returns 401 when not authenticated" do
      post "/api/v1/teams/#{team.id}/roster",
        params: {
          roster_updates: [],
          target_date: target_date.to_s
        },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/teams/:team_id/roster (non-existent team)" do
    include_context "authenticated user"

    it "returns 404 for non-existent team" do
      post "/api/v1/teams/999999/roster",
        params: {
          roster_updates: [],
          target_date: "2026-05-15"
        },
        as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/teams/:team_id/roster (no season)" do
    include_context "authenticated user"

    let(:team_no_season) { create(:team, user: user) }

    it "returns 400 when team has no season" do
      post "/api/v1/teams/#{team_no_season.id}/roster",
        params: {
          roster_updates: [],
          target_date: "2026-05-15"
        },
        as: :json

      expect(response).to have_http_status(:bad_request)
      json = response.parsed_body
      expect(json["error"]).to include("Season")
    end
  end

  # ============================================================
  # POST /api/v1/teams/:team_id/roster (commissioner mode)
  # ============================================================

  describe "POST /api/v1/teams/:team_id/roster (commissioner override)" do
    include_context "authenticated commissioner"

    let(:target_date) { Date.new(2026, 5, 15) }

    let!(:season_start_schedule) do
      create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
    end
    let!(:game_day_schedule) do
      create(:season_schedule, season: season, date: target_date, date_type: "game_day")
    end

    before { team.update!(user: user) }

    def post_roster_update(team_id, roster_updates, date: target_date)
      post "/api/v1/teams/#{team_id}/roster",
        params: {
          roster_updates: roster_updates,
          target_date: date.to_s
        },
        as: :json
    end

    context "commissioner が1軍コスト超過でもrosterを更新できる" do
      it "returns 200 with commissioner_override warning" do
        # 25 players in first squad, each cost 4 = 100; limit for 26 = 117
        # promoting player with cost 18 → total 118 > 117
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 18)

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["warnings"]).to be_an(Array)
        expect(json["warnings"].any? { |w| w["type"] == "commissioner_override" }).to be true
        expect(result[:membership].reload.squad).to eq("first")
      end
    end

    context "commissioner が外の世界枠超過でもrosterを更新できる" do
      it "returns 200 with commissioner_override warning when outside world limit exceeded" do
        # normal team: native series = ["touhou"], 外の世界枠上限 = 4
        # 4 outside-world players already in first squad (exactly at limit)
        # Promoting a 5th outside-world player would exceed the limit
        21.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 3) }
        4.times do
          p = create(:player, series: "original")
          tm = create(:team_membership, team: team, player: p, squad: "first", selected_cost_type: "normal_cost")
          create(:cost_player, cost: cost, player: p, normal_cost: 3)
        end
        # 5th outside-world player in second squad → promote
        outside_player = create(:player, series: "original")
        outside_membership = create(:team_membership, team: team, player: outside_player, squad: "second", selected_cost_type: "normal_cost")
        create(:cost_player, cost: cost, player: outside_player, normal_cost: 3)

        post_roster_update(team.id, [
          { team_membership_id: outside_membership.id, squad: "first" }
        ])

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["warnings"].any? { |w| w["type"] == "commissioner_override" }).to be true
      end
    end

    context "非commissionerは1軍コスト超過で422が返る" do
      include_context "authenticated user"
      before { team.update!(user: user) }

      it "returns 422 when cost limit exceeded" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 18)

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to include("コスト")
      end
    end

    context "commissioner でも cooldown は維持される" do
      it "returns 422 when player is on cooldown" do
        25.times { add_player_to_team(team: team, cost: cost, squad: "first", cost_value: 4) }
        result = add_player_to_team(team: team, cost: cost, squad: "second", cost_value: 3)

        create(:season_roster,
          season: season,
          team_membership: result[:membership],
          squad: "first",
          registered_on: Date.new(2026, 5, 1)
        )
        create(:season_roster,
          season: season,
          team_membership: result[:membership],
          squad: "second",
          registered_on: Date.new(2026, 5, 10)
        )

        post_roster_update(team.id, [
          { team_membership_id: result[:membership].id, squad: "first" }
        ])

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json["error"]).to include("cooldown")
      end
    end
  end
end
