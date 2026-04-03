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

    describe "GET /api/v1/teams/:team_id/pitcher_game_states/fatigue_summary" do
      let(:card_set) { create(:card_set) }
      let(:pitcher_first) { create(:player, :pitcher) }
      let!(:pitcher_first_card) { create(:player_card, player: pitcher_first, card_set: card_set, card_type: "pitcher") }
      let!(:tm_first) { create(:team_membership, :first_squad, team: team, player: pitcher_first) }
      # season_rostersベース判定のため、target_date以前に1軍登録されていることが必要
      let!(:season_roster_first) { create(:season_roster, team_membership: tm_first, squad: "first", registered_on: "2026-01-01") }

      def get_fatigue_summary(date:)
        get "/api/v1/teams/#{team.id}/pitcher_game_states/fatigue_summary",
          params: { date: date }
      end

      it "1軍投手のみ返す（squad=firstのみ）" do
        other_pitcher = create(:player, :pitcher)
        create(:player_card, player: other_pitcher, card_set: card_set, card_type: "pitcher")
        create(:team_membership, team: team, player: other_pitcher, squad: "second")

        get_fatigue_summary(date: "2026-03-10")
        ids = response.parsed_body.map { |e| e["player_id"] }
        expect(ids).to include(pitcher_first.id)
        expect(ids).not_to include(other_pitcher.id)
      end

      it "登板歴なし → projected_status: full, last_role: nil" do
        get_fatigue_summary(date: "2026-03-10")

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
        expect(entry["projected_status"]).to eq("full")
        expect(entry["last_role"]).to be_nil
      end

      context "先発投手 (projected_status 計算)" do
        def create_starter_pgs(schedule_date:, result_category: "normal", consecutive: 0)
          game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
          create(:pitcher_game_state,
            pitcher: pitcher_first, team: team, competition: competition, game: game,
            role: "starter", schedule_date: schedule_date,
            result_category: result_category,
            consecutive_short_rest_count: consecutive
          )
        end

        it "中2日以内 → unavailable" do
          create_starter_pgs(schedule_date: "2026-03-08")
          get_fatigue_summary(date: "2026-03-10") # 中1日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("unavailable")
          expect(entry["is_unavailable"]).to be true
        end

        it "通常/中3日 → injury_check" do
          create_starter_pgs(schedule_date: "2026-03-06")
          get_fatigue_summary(date: "2026-03-10") # 中3日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        it "通常/中4日(連続でない) → reduced_3" do
          create_starter_pgs(schedule_date: "2026-03-05", consecutive: 0)
          get_fatigue_summary(date: "2026-03-10") # 中4日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_3")
        end

        it "通常/中4日(2回連続) → injury_check" do
          create_starter_pgs(schedule_date: "2026-03-05", consecutive: 1)
          get_fatigue_summary(date: "2026-03-10") # 中4日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        it "通常/中5日 → reduced_1" do
          create_starter_pgs(schedule_date: "2026-03-04")
          get_fatigue_summary(date: "2026-03-10") # 中5日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_1")
        end

        it "通常/中6日以上 → full" do
          create_starter_pgs(schedule_date: "2026-03-03")
          get_fatigue_summary(date: "2026-03-10") # 中6日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("full")
        end

        it "KO/中3日 → reduced_3" do
          create_starter_pgs(schedule_date: "2026-03-06", result_category: "ko")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_3")
        end

        it "KO/中4日以上 → full" do
          create_starter_pgs(schedule_date: "2026-03-05", result_category: "ko")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("full")
        end

        it "長イニング敗戦/中4日 → reduced_4" do
          create_starter_pgs(schedule_date: "2026-03-05", result_category: "long_loss")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_4")
        end

        it "長イニング敗戦/中7日以上 → full" do
          create_starter_pgs(schedule_date: "2026-03-02", result_category: "long_loss")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("full")
        end
      end

      context "リリーフ投手 (projected_status 計算)" do
        def create_reliever_pgs(schedule_date:)
          game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
          create(:pitcher_game_state,
            pitcher: pitcher_first, team: team, competition: competition, game: game,
            role: "reliever", schedule_date: schedule_date
          )
        end

        it "累積0 → full" do
          # 長期休養後は累積0になる
          create_reliever_pgs(schedule_date: "2026-03-01")
          get_fatigue_summary(date: "2026-03-10") # 8日休み → 累積0
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("full")
        end

        it "累積1 → reduced_0" do
          create_reliever_pgs(schedule_date: "2026-03-09")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_0")
        end

        it "累積3以上 → injury_check" do
          create_reliever_pgs(schedule_date: "2026-03-07")
          create_reliever_pgs(schedule_date: "2026-03-08")
          create_reliever_pgs(schedule_date: "2026-03-09")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end
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
