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
      let!(:pitcher_first_card) { create(:player_card, player: pitcher_first, card_set: card_set, card_type: "pitcher", is_pitcher: true) }
      let!(:tm_first) { create(:team_membership, :first_squad, team: team, player: pitcher_first, player_card: pitcher_first_card) }
      # season_rostersベース判定のため、target_date以前に1軍登録されていることが必要
      let!(:season_roster_first) { create(:season_roster, team_membership: tm_first, squad: "first", registered_on: "2026-01-01") }

      def get_fatigue_summary(date:)
        get "/api/v1/teams/#{team.id}/pitcher_game_states/fatigue_summary",
          params: { date: date }
      end

      it "1軍投手のみ返す（squad=firstのみ）" do
        other_pitcher = create(:player, :pitcher)
        other_card = create(:player_card, player: other_pitcher, card_set: card_set, card_type: "pitcher", is_pitcher: true)
        create(:team_membership, team: team, player: other_pitcher, player_card: other_card, squad: "second")

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

    describe "負傷離脱中の休養日数凍結・累積イニング減衰凍結・中10日全快" do
      let(:pitcher3) { create(:player, :pitcher) }
      let!(:tm3) { create(:team_membership, team: team, player: pitcher3) }
      let(:season3) { create(:season, team: team) }

      def create_pgs3(schedule_date:, role: "reliever", **attrs)
        game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
        create(:pitcher_game_state,
          pitcher: pitcher3, team: team, competition: competition, game: game,
          role: role, schedule_date: schedule_date, **attrs
        )
      end

      def create_absence3(start_date:, duration:, duration_unit: "days")
        create(:player_absence,
          team_membership: tm3, season: season3,
          start_date: start_date, duration: duration, duration_unit: duration_unit
        )
      end

      def get_states3(date:)
        get "/api/v1/teams/#{team.id}/pitcher_game_states",
          params: { date: date, player_ids: [ pitcher3.id ] }
      end

      describe "rest_days 凍結（負傷中の日数は休養日数に含めない）" do
        it "離脱期間を除いた日数を rest_days として返す" do
          # 3/1 登板 → 3/2-3/4 離脱(3日) → target 3/7
          # 休み日: 3/2,3/3,3/4,3/5,3/6 = 5日、うち離脱3日除外 → rest_days = 2
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 3)

          get_states3(date: "2026-03-07")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(2)
        end

        it "離脱期間が存在しない場合は通常通り計算される" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")

          get_states3(date: "2026-03-07")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(5)
        end
      end

      describe "累積イニング減衰凍結（負傷中は decay しない）" do
        it "離脱中は累積イニングが減衰しない" do
          # 3/1〜3/3 連日登板(累積3)、3/4〜3/7 離脱(4日, end=3/8)、target 3/9
          # 離脱なし計算: idle=5 → 3→1→0→0→0 = 0
          # 離脱あり: idle=5, 離脱日=4(3/4,3/5,3/6,3/7) → effective_idle=1 → 3→1
          create_pgs3(schedule_date: "2026-03-01")
          create_pgs3(schedule_date: "2026-03-02")
          create_pgs3(schedule_date: "2026-03-03")
          create_absence3(start_date: "2026-03-04", duration: 4)

          get_states3(date: "2026-03-09")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(1)
        end

        it "離脱期間のない通常計算には影響しない" do
          create_pgs3(schedule_date: "2026-03-01")
          create_pgs3(schedule_date: "2026-03-02")
          create_pgs3(schedule_date: "2026-03-03")

          get_states3(date: "2026-03-09")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(0)
        end
      end

      describe "中10日全快（PlayerAbsence > 10日で累積リセット・先発は rest_days nil）" do
        it "リリーフ: 10日超の離脱後は累積イニングが 0 にリセットされる" do
          # 3/1 登板(累積1)、3/2 から 14日離脱(end=3/16)、target 3/17
          create_pgs3(schedule_date: "2026-03-01")
          create_absence3(start_date: "2026-03-02", duration: 14)

          get_states3(date: "2026-03-17")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(0)
        end

        it "先発: 10日超の離脱後は rest_days が nil（全快）になる" do
          # 3/1 登板(先発)、3/2 から 14日離脱(end=3/16)、target 3/17
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 14)

          get_states3(date: "2026-03-17")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to be_nil
        end

        it "ちょうど 10日の離脱は全快扱いにならない（> 10日のみ全快）" do
          # 3/1 登板、3/2 から 10日離脱(end=3/12)、target 3/13
          # (3/12 - 3/2 = 10日、> 10 ではないので全快にならない)
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 10)

          get_states3(date: "2026-03-13")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          # rest_days は nil にならず離脱除外計算: raw=11, 離脱=10 → rest_days=1
          expect(entry["rest_days"]).to eq(1)
        end

        it "離脱中（未終了）は全快判定しない（is_injured: true のまま）" do
          create_pgs3(schedule_date: "2026-03-01")
          # 14日離脱、まだ終わっていない (target が離脱中)
          create_absence3(start_date: "2026-03-02", duration: 14)

          get_states3(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["is_injured"]).to be true
        end
      end
    end
  end

  describe "GET /api/v1/teams/:team_id/pitcher_game_states（player_ids未指定：登録カード判定）" do
    include_context "authenticated user"

    let(:team) { create(:team) }

    before { team.update!(user: user) }

    def get_states_no_ids(date:)
      get "/api/v1/teams/#{team.id}/pitcher_game_states",
        params: { date: date }
    end

    # #5: 登録カードがバッターカードの選手は投手リストに含まれない
    it "登録カードがbatterの選手は投手リストに含まれない（#5 正邪修正）" do
      batter_player = create(:player)
      card_set = create(:card_set)
      batter_card = create(:player_card, player: batter_player, card_type: "batter", is_pitcher: false, card_set: card_set)
      create(:team_membership, team: team, player: batter_player, player_card: batter_card, squad: "first")

      get_states_no_ids(date: "2026-04-05")

      player_ids = response.parsed_body.map { |e| e["player_id"] }
      expect(player_ids).not_to include(batter_player.id)
    end

    # #5: 同一選手が投手カードと野手カードを持つ場合、登録カードで判定
    it "同一選手の野手カードを登録した場合は投手リストに含まれない（#5 正邪修正）" do
      two_way_player = create(:player)
      card_set = create(:card_set)
      # 投手カードも持つが、登録は野手カード
      create(:player_card, player: two_way_player, card_type: "pitcher", is_pitcher: true, card_set: card_set)
      batter_card = create(:player_card, player: two_way_player, card_type: "batter", is_pitcher: false, card_set: card_set)
      create(:team_membership, team: team, player: two_way_player, player_card: batter_card, squad: "first")

      get_states_no_ids(date: "2026-04-05")

      player_ids = response.parsed_body.map { |e| e["player_id"] }
      expect(player_ids).not_to include(two_way_player.id)
    end

    # #6: 野手専念契約の選手は投手リストに含まれない
    it "fielder_only_cost契約の投手カード選手は投手リストに含まれない（#6 野崎夕姫修正）" do
      two_way_player = create(:player)
      card_set = create(:card_set)
      pitcher_card = create(:player_card, player: two_way_player, card_type: "pitcher", is_pitcher: true, card_set: card_set)
      create(:team_membership, team: team, player: two_way_player, player_card: pitcher_card,
             squad: "first", selected_cost_type: "fielder_only_cost")

      get_states_no_ids(date: "2026-04-05")

      player_ids = response.parsed_body.map { |e| e["player_id"] }
      expect(player_ids).not_to include(two_way_player.id)
    end

    # 正常系: 投手カード登録かつfielder_only以外は含まれる
    it "登録カードがpitcherかつnormal_cost → 投手リストに含まれる" do
      pitcher_player = create(:player)
      card_set = create(:card_set)
      pitcher_card = create(:player_card, player: pitcher_player, card_type: "pitcher", is_pitcher: true, card_set: card_set)
      create(:team_membership, team: team, player: pitcher_player, player_card: pitcher_card,
             squad: "first", selected_cost_type: "normal_cost")

      get_states_no_ids(date: "2026-04-05")

      player_ids = response.parsed_body.map { |e| e["player_id"] }
      expect(player_ids).to include(pitcher_player.id)
    end
  end
end
