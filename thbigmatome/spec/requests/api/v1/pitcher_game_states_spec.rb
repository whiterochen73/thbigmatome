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

      it "0アウト降板（innings=0, no_out_exit=true）: max(0+1,1)=1" do
        # max(0+1, 1) = 1
        create_pgs(schedule_date: "2026-03-01", innings_pitched: 0, no_out_exit: true)
        get_states(date: "2026-03-02", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(1)
      end

      it "1イニング投げて0アウト降板（innings=1, no_out_exit=true）: max(1+1,1)=2" do
        # max(1+1, 1) = 2
        create_pgs(schedule_date: "2026-03-01", innings_pitched: 1, no_out_exit: true)
        get_states(date: "2026-03-02", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(2)
      end

      it "同ゲームに先行投手あり・1イニング投げて0アウト降板: 関与イニング2" do
        # 先行投手が1イニング投げた後、対象投手が1イニング投げてno_out_exit=true
        # prior_outs=3, my_outs=3 → start=2, end=2, involvement=(2-2+1)+1=2
        game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
        prior_pitcher = create(:player, :pitcher)
        create(:pitcher_game_state,
          pitcher: prior_pitcher, team: team, competition: competition, game: game,
          role: "reliever", schedule_date: "2026-03-01",
          innings_pitched: 1.0, appearance_order: 0
        )
        create(:pitcher_game_state,
          pitcher: pitcher, team: team, competition: competition, game: game,
          role: "reliever", schedule_date: "2026-03-01",
          innings_pitched: 1.0, no_out_exit: true, appearance_order: 1
        )
        get_states(date: "2026-03-02", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(2)
      end

      it "0アウト降板後に連日登板: 累積が正しく加算される" do
        # 03-01: no_out_exit(max(0+1,1)=1), 03-02: 通常1イニング(max(1+0,1)=1) → 累積2
        create_pgs(schedule_date: "2026-03-01", innings_pitched: 0, no_out_exit: true)
        create_pgs(schedule_date: "2026-03-02")
        get_states(date: "2026-03-03", player_ids: [ pitcher.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher.id }
        expect(entry["cumulative_innings"]).to eq(2)
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

        # Test Basis: rulebook §8.3.1（KO・ノーゲーム中4日 / 長イニング敗戦中4日は「2回連続で発動」）/ cmd_1775 第2段 E8
        it "E8: KO/中4日(2回連続) → injury_check、1回目は full" do
          create_starter_pgs(schedule_date: "2026-03-05", result_category: "ko", consecutive: 1)
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        it "E8: ノーゲーム/中4日(2回連続) → injury_check" do
          create_starter_pgs(schedule_date: "2026-03-05", result_category: "no_game", consecutive: 1)
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        it "E8: 長イニング敗戦/中4日(1回目・連続でない) → reduced_4、2回連続 → injury_check" do
          create_starter_pgs(schedule_date: "2026-03-05", result_category: "long_loss", consecutive: 0)
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_4")

          PitcherGameState.where(pitcher_id: pitcher_first.id).update_all(consecutive_short_rest_count: 1)
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        context "離脱を挟む先発（E4・E5）" do
          let(:season_first) { create(:season, team: team) }

          def add_absence(type, start:, days:)
            create(:player_absence, team_membership: tm_first, season: season_first, absence_type: type,
                                    start_date: Date.parse(start), duration: days, duration_unit: "days")
          end

          def first_entry
            response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          end

          it "E4: 出場停止を挟んでも中日数から引かない（実日数中4日 → reduced_3。引けば中1日で unavailable になる）" do
            create_starter_pgs(schedule_date: "2026-03-05")
            add_absence(:suspension, start: "2026-03-06", days: 3)
            get_fatigue_summary(date: "2026-03-10")
            expect(first_entry["rest_days"]).to eq(4)
            expect(first_entry["projected_status"]).to eq("reduced_3")
            expect(first_entry["is_unavailable"]).to be false
          end

          it "E4: 負傷を挟めば中日数から引く（実日数中4日 - 負傷3日 = 中1日 → unavailable）" do
            create_starter_pgs(schedule_date: "2026-03-05")
            add_absence(:injury, start: "2026-03-06", days: 3)
            get_fatigue_summary(date: "2026-03-10")
            expect(first_entry["rest_days"]).to eq(1)
            expect(first_entry["projected_status"]).to eq("unavailable")
          end

          it "E5: 実日数中9日 + 負傷 7 日（控除後 2 日）はリセットせず unavailable" do
            create_starter_pgs(schedule_date: "2026-03-01")
            add_absence(:injury, start: "2026-03-02", days: 7)
            get_fatigue_summary(date: "2026-03-11") # 実日数 9
            expect(first_entry["rest_days"]).to eq(2)
            expect(first_entry["projected_status"]).to eq("unavailable")
          end

          it "E5: 実日数中10日 + 負傷 7 日（控除後 3 日）はリセット成立で full（控除後の中3日 injury_check にならない）" do
            create_starter_pgs(schedule_date: "2026-03-01")
            add_absence(:injury, start: "2026-03-02", days: 7)
            get_fatigue_summary(date: "2026-03-12") # 実日数 10
            expect(first_entry["projected_status"]).to eq("full")
            expect(first_entry["is_unavailable"]).to be false
          end

          it "E5（AMB-04 追補2）: リセット成立かつ控除後 0 日（負傷 10 日・実日数中10日）でも unavailable にしない = 登板可・full" do
            create_starter_pgs(schedule_date: "2026-03-01")
            add_absence(:injury, start: "2026-03-02", days: 10)
            get_fatigue_summary(date: "2026-03-12")
            expect(first_entry["is_unavailable"]).to be false
            expect(first_entry["projected_status"]).to eq("full")
          end
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

      # 境界値回帰防止: effective_end_date は排他的（この日には復帰可能）
      # start=3/15, duration=5days → effective_end_date=3/20（3/20から復帰可能）
      it "target_date == effective_end_date（回復日当日）→ is_injured: false" do
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 15),
          duration: 5,
          duration_unit: "days"
        )
        get_states(date: "2026-03-20", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be false
      end

      it "target_date == effective_end_date - 1（回復前日）→ is_injured: true" do
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 15),
          duration: 5,
          duration_unit: "days"
        )
        get_states(date: "2026-03-19", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be true
      end

      it "target_date > effective_end_date（回復後）→ is_injured: false" do
        create(:player_absence,
          team_membership: team_membership2,
          season: season,
          start_date: Date.new(2026, 3, 15),
          duration: 5,
          duration_unit: "days"
        )
        get_states(date: "2026-03-22", player_ids: [ pitcher2.id ])

        entry = response.parsed_body.find { |e| e["player_id"] == pitcher2.id }
        expect(entry["is_injured"]).to be false
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

      def create_absence3(start_date:, duration:, duration_unit: "days", absence_type: :injury)
        create(:player_absence,
          team_membership: tm3, season: season3, absence_type: absence_type,
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

      # Test Basis: AMB-04 追補（2026-09-13）リセットは差し引かない実日数差 (next - last) - 1 >= 10。離脱の有無・長短は関与しない / cmd_1775 第2段 E5
      describe "中10日リセット（実日数差。離脱は関与しない）" do
        it "リリーフ: 実日数中10日で累積イニングが 0 にリセットされる（離脱 7 日では減衰凍結だけなら 1 残る）" do
          # 3/1〜3/5 連日登板（累積5）、3/6 から 7 日離脱（〜3/12）。
          # 3/16 は 3/5 から実日数中10日 → リセットで 0。リセットが無ければ 離脱控除後の中3日 で 5→4→3→1 = 1
          5.times { |i| create_pgs3(schedule_date: "2026-03-0#{i + 1}") }
          create_absence3(start_date: "2026-03-06", duration: 7)

          get_states3(date: "2026-03-16")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(0)
        end

        it "リリーフ: 実日数中9日ではリセットしない（離脱控除後の中2日だけ減衰 5→4→3）" do
          5.times { |i| create_pgs3(schedule_date: "2026-03-0#{i + 1}") }
          create_absence3(start_date: "2026-03-06", duration: 7)

          get_states3(date: "2026-03-15")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(3)
        end

        it "リリーフ: 離脱が無くても実日数中10日以上なら累積は 0（減衰の結果と一致する）" do
          create_pgs3(schedule_date: "2026-03-01")
          get_states3(date: "2026-03-20")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(0)
        end

        it "先発: 実日数中10日以上のとき、離脱を差し引かない実日数を rest_days として返す（離脱 14 日・実日数中15日）" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 14)

          get_states3(date: "2026-03-17")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(15)
        end

        it "先発: 離脱がちょうど 10 日で実日数中10日 → リセット成立で実日数 10 を返す（控除後 0 日にしない）" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 10)

          get_states3(date: "2026-03-12")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(10)
        end

        it "先発: 実日数中9日では離脱 10 日を差し引く（控除後 -1 → 0 以下。リセットしない）" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 10)

          get_states3(date: "2026-03-11")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to be <= 0
        end

        it "先発: 10日未満の離脱でも実日数中10日ならリセット（離脱 3 日）" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-03", duration: 3)

          get_states3(date: "2026-03-12")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(10)
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

      # Test Basis: AMB-04「出場停止と負傷は別枠」（2026-09-12 Operator 確定）。中日数控除・減衰凍結は負傷のみ / cmd_1775 第2段 E4
      describe "出場停止・再調整は中日数の控除にも減衰凍結にも使わない" do
        it "先発の rest_days: 出場停止 3 日は引かない（実日数中5日のまま。負傷なら 2）" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 3, absence_type: :suspension)

          get_states3(date: "2026-03-07")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(5)
        end

        it "先発の rest_days: 再調整も引かない" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 3, absence_type: :reconditioning)

          get_states3(date: "2026-03-07")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(5)
        end

        it "負傷と出場停止が重なっても引くのは負傷分だけ（実日数中6日 - 負傷2日 = 4）" do
          create_pgs3(schedule_date: "2026-03-01", role: "starter")
          create_absence3(start_date: "2026-03-02", duration: 2)
          create_absence3(start_date: "2026-03-03", duration: 3, absence_type: :suspension)

          get_states3(date: "2026-03-08")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["rest_days"]).to eq(4)
        end

        it "リリーフの累積イニング: 出場停止中も通常どおり減衰する（凍結しない）" do
          # 3/1〜3/3 連日登板（累積3）、3/4〜3/7 出場停止、target 3/9。凍結しなければ 5 日分減衰して 0（負傷なら凍結して 1）
          create_pgs3(schedule_date: "2026-03-01")
          create_pgs3(schedule_date: "2026-03-02")
          create_pgs3(schedule_date: "2026-03-03")
          create_absence3(start_date: "2026-03-04", duration: 4, absence_type: :suspension)

          get_states3(date: "2026-03-09")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher3.id }
          expect(entry["cumulative_innings"]).to eq(0)
        end

        it "出場可否の表示は今のまま: 出場停止中も is_injured: true（表示の範囲外）" do
          create_pgs3(schedule_date: "2026-03-01")
          create_absence3(start_date: "2026-03-02", duration: 14, absence_type: :suspension)

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
