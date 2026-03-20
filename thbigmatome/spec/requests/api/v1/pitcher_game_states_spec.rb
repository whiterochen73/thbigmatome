require "rails_helper"

RSpec.describe "Api::V1::PitcherGameStatesController", type: :request do
  describe "GET /api/v1/teams/:team_id/pitcher_game_states" do
    include_context "authenticated user"

    let(:team) { create(:team) }
    let(:competition) { create(:competition) }
    let(:pitcher) { create(:player, :pitcher) }

    before { team.update!(user: user) }

    def create_pgs(schedule_date:, role: "reliever", **attrs)
      game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
      create(:pitcher_game_state,
        pitcher: pitcher,
        team: team,
        competition: competition,
        game: game,
        role: role,
        schedule_date: schedule_date,
        **attrs
      )
    end

    def get_states(date:, player_ids:)
      get "/api/v1/teams/#{team.id}/pitcher_game_states",
        params: { date: date, player_ids: player_ids }
    end

    describe "rest_days 計算" do
      it "前日登板 → rest_days == 0" do
        create_pgs(schedule_date: "2026-03-01", role: "starter")
        get_states(date: "2026-03-02", player_ids: [ pitcher.id ])

        expect(response).to have_http_status(:ok)
        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["rest_days"]).to eq(0)
      end

      it "2日前登板 → rest_days == 1" do
        create_pgs(schedule_date: "2026-03-01", role: "starter")
        get_states(date: "2026-03-03", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["rest_days"]).to eq(1)
      end

      it "登板歴なし → rest_days == nil" do
        get_states(date: "2026-03-02", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["rest_days"]).to be_nil
      end
    end

    describe "compute_cumulative_innings（累積イニング + decay計算）" do
      it "連日登板: 累積が 1→2→3 と加算される" do
        create_pgs(schedule_date: "2026-03-01")
        create_pgs(schedule_date: "2026-03-02")
        create_pgs(schedule_date: "2026-03-03")
        get_states(date: "2026-03-04", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(3)
      end

      it "1日休んで登板: decay（累積3以下は-2/日）後に加算" do
        # 03-01 登板(累積1)、03-02 休み、03-03 登板
        # 03-03処理時: rest_days=1 → max(1-2,0)=0 → +1=1
        create_pgs(schedule_date: "2026-03-01")
        create_pgs(schedule_date: "2026-03-03")
        get_states(date: "2026-03-04", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(1)
      end

      it "3日以上休んで登板: 累積が0になってから加算" do
        # 03-01〜03-03 連日登板(累積3)、03-08 登板(4日休み → 0になる → +1)
        create_pgs(schedule_date: "2026-03-01")
        create_pgs(schedule_date: "2026-03-02")
        create_pgs(schedule_date: "2026-03-03")
        create_pgs(schedule_date: "2026-03-08")
        get_states(date: "2026-03-09", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(1)
      end

      it "累積4（4連日）から1日休み: decay率が-1/日（→3）" do
        # 03-01〜03-04 連日登板(累積4)、target=03-06（03-05スキップ）
        # idle_days=1: 4 > 3 → 4-1=3
        create_pgs(schedule_date: "2026-03-01")
        create_pgs(schedule_date: "2026-03-02")
        create_pgs(schedule_date: "2026-03-03")
        create_pgs(schedule_date: "2026-03-04")
        get_states(date: "2026-03-06", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(3)
      end

      it "累積3（3連日）から1日休み: decay率が-2/日（→1）" do
        # 03-01〜03-03 連日登板(累積3)、target=03-05（03-04スキップ）
        # idle_days=1: 3 <= 3 → max(3-2,0)=1
        create_pgs(schedule_date: "2026-03-01")
        create_pgs(schedule_date: "2026-03-02")
        create_pgs(schedule_date: "2026-03-03")
        get_states(date: "2026-03-05", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(1)
      end

      it "長期休養（7日以上）: 累積が0に収束する" do
        # 03-01〜03-03 連日登板(累積3)、target=03-11（7日休み）
        # 7日: 3→1→0→0→0→0→0 = 0
        create_pgs(schedule_date: "2026-03-01")
        create_pgs(schedule_date: "2026-03-02")
        create_pgs(schedule_date: "2026-03-03")
        get_states(date: "2026-03-11", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(0)
      end
    end

    describe "build_injured_set: 離脱判定" do
      let(:pitcher2) { create(:player, :pitcher) }
      let!(:team_membership2) { create(:team_membership, team: team, player: pitcher2) }
      let(:season) { create(:season, team: team) }

      it "target_dateが離脱期間内 → is_injured: true" do
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 15),
          duration: 5,
          duration_unit: "days"
        )
        get_states(date: "2026-03-17", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be true
      end

      it "target_dateが離脱期間外 → is_injured: false" do
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 15),
          duration: 5,
          duration_unit: "days"
        )
        get_states(date: "2026-03-10", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be false
      end

      it "end_date==nil（無期限離脱: duration_unit=games + 試合日程なし）→ is_injured: true" do
        # season_schedulesが存在しない → effective_end_date = nil → 無期限離脱扱い
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 15),
          duration: 5,
          duration_unit: "games"
        )
        get_states(date: "2026-03-21", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be true
      end

      it "target_date == start_date（当日）→ is_injured: true" do
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 17),
          duration: 5,
          duration_unit: "days"
        )
        get_states(date: "2026-03-17", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be true
      end
    end
  end
end
