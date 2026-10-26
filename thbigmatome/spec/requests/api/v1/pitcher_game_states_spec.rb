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

        # Test Basis: AMB-23 追記。連続 3 回の先発・間隔がどちらも中4日以下 → 3 回目で負傷チェック（条件 2）
        it "AMB-23: 先発 → (中3日) 先発 → (中4日) 先発 で 3 回目は injury_check（保存時に決まるカウントで判定）" do
          [ "2026-03-01", "2026-03-05" ].each do |d|
            create_starter_pgs(schedule_date: d, consecutive: PitcherConsecutiveShortRest.call(team_id: team.id, pitcher_id: pitcher_first.id, schedule_date: d))
          end
          expect(PitcherGameState.order(:schedule_date).pluck(:consecutive_short_rest_count)).to eq([ 0, 1 ])
          get_fatigue_summary(date: "2026-03-10") # 3/5 から中4日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        it "AMB-23: 先発 → (中4日) 先発 → (中3日) 先発 も 3 回目は injury_check（KO の前回でも）" do
          [ "2026-03-01", "2026-03-06" ].each do |d|
            create_starter_pgs(schedule_date: d, result_category: "ko",
                               consecutive: PitcherConsecutiveShortRest.call(team_id: team.id, pitcher_id: pitcher_first.id, schedule_date: d))
          end
          get_fatigue_summary(date: "2026-03-10") # 3/6 から中3日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("injury_check")
        end

        it "AMB-23: 先発 → (中5日) 先発 → (中4日) 先発 では発動しない（reduced_3）" do
          [ "2026-03-01", "2026-03-06" ].each_with_index do |d, i|
            # 3/1 → 3/7 を中5日にするため 2 件目は 3/7 に置く
            d = "2026-03-07" if i == 1
            create_starter_pgs(schedule_date: d, consecutive: PitcherConsecutiveShortRest.call(team_id: team.id, pitcher_id: pitcher_first.id, schedule_date: d))
          end
          expect(PitcherGameState.order(:schedule_date).pluck(:consecutive_short_rest_count)).to eq([ 0, 0 ])
          get_fatigue_summary(date: "2026-03-12") # 3/7 から中4日
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("reduced_3")
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

        it "累積2 → fatigued_start（最初から疲労状態。累積1 の reduced_0 = 疲労P0 とは別の値。AMB-19 追補）" do
          create_reliever_pgs(schedule_date: "2026-03-08")
          create_reliever_pgs(schedule_date: "2026-03-09")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("fatigued_start")
        end

        it "累積3以上 → fatigued_start_check（最初から疲労状態 + 登板後の負傷チェック。疲労状態が見えなくならない）" do
          create_reliever_pgs(schedule_date: "2026-03-07")
          create_reliever_pgs(schedule_date: "2026-03-08")
          create_reliever_pgs(schedule_date: "2026-03-09")
          get_fatigue_summary(date: "2026-03-10")
          entry = response.parsed_body.find { |e| e["player_id"] == pitcher_first.id }
          expect(entry["projected_status"]).to eq("fatigued_start_check")
        end
      end

      # Test Basis: cmd_1775 第3段 E9・E10 / rulebook §8.3.2〜§8.3.4・§8.4.3・§8.7.2 / 台帳 AMB-18 追補・AMB-19 追補・AMB-21 /
      #   「Dugout 監査 E9〜E12 の残り — 実装の範囲」（2026-10-26 Operator 決定）
      context "役割別の状態（as_starter / as_reliever）" do
        let(:season_first) { create(:season, team: team) }
        # スラッシュ選手: starter_stamina と relief_stamina の両方があり relief_only でない
        let!(:slash_player) { make_pitcher(starter_stamina: 7, relief_stamina: 3)[0] }
        # スラッシュでない通常の選手（先発疲労P 無し・リリーフ疲労P あり）。先発も出る（既定 3）
        let!(:plain_player) { make_pitcher(starter_stamina: nil, relief_stamina: 3)[0] }

        def make_pitcher(starter_stamina: 7, relief_stamina: nil, is_relief_only: false, cost_type: "normal_cost")
          player = create(:player, :pitcher)
          card = create(:player_card, player: player, card_set: card_set, card_type: "pitcher", is_pitcher: true,
                                      starter_stamina: starter_stamina, relief_stamina: relief_stamina, is_relief_only: is_relief_only)
          tm = create(:team_membership, :first_squad, team: team, player: player, player_card: card, selected_cost_type: cost_type)
          create(:season_roster, team_membership: tm, squad: "first", registered_on: "2026-01-01")
          [ player, tm ]
        end

        def appear(player, date, role: "reliever", innings: nil, category: nil, consecutive: 0)
          game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
          create(:pitcher_game_state, pitcher: player, team: team, competition: competition, game: game,
                                      role: role, schedule_date: date, innings_pitched: innings,
                                      result_category: category, consecutive_short_rest_count: consecutive)
        end

        def entry_for(player, date)
          get_fatigue_summary(date: date)
          response.parsed_body.find { |e| e["player_id"] == player.id }
        end

        # 3/1 に登板 → 中 rest 日（3/1 から rest + 1 日後）の状態
        def target_after(rest) = (Date.new(2026, 3, 1) + rest + 1).to_s

        def reset_appearances(player) = PitcherGameState.where(pitcher_id: player.id).delete_all

        it "API は as_starter / as_reliever を {status, notes} で返す（既存の projected_status も残る）" do
          appear(plain_player, "2026-03-06", role: "starter", category: "normal")
          e = entry_for(plain_player, "2026-03-10") # 中3日
          expect(e["as_starter"]).to eq({ "status" => "injury_check", "notes" => [] })
          expect(e["as_reliever"]).to eq({ "status" => "reduced_0", "notes" => [] })
          expect(e["as_starter_omitted_reason"]).to be_nil
          expect(e["as_reliever_omitted_reason"]).to be_nil
          expect(e["projected_status"]).to eq("injury_check")
        end

        describe "先発なら: 前回が先発（§8.3.1 の既存表）" do
          it "前回の区分 × 中日数で既存の projected_status と同じ値を as_starter にも出す" do
            { "normal" => { 3 => "injury_check", 4 => "reduced_3", 5 => "reduced_1", 6 => "full" },
              "ko" => { 3 => "reduced_3", 4 => "full" },
              "no_game" => { 3 => "reduced_3", 4 => "full" },
              "long_loss" => { 3 => "injury_check", 4 => "reduced_4", 5 => "reduced_2", 6 => "reduced_1", 7 => "full" } }.each do |cat, rows|
              rows.each do |rest, expected|
                reset_appearances(plain_player)
                appear(plain_player, "2026-03-01", role: "starter", category: cat)
                e = entry_for(plain_player, target_after(rest))
                expect([ cat, rest, e["as_starter"]["status"] ]).to eq([ cat, rest, expected ])
                expect(e["projected_status"]).to eq(expected)
              end
            end
          end
        end

        describe "先発なら: 前回がリリーフ（§8.3.4・§8.7.2）" do
          it "前回リリーフで中2日以内は先発不可（is_unavailable も true）。中3日から先発可" do
            [ 0, 1, 2 ].each do |rest|
              reset_appearances(plain_player)
              appear(plain_player, "2026-03-01", innings: 1.0)
              e = entry_for(plain_player, target_after(rest))
              expect([ rest, e["as_starter"]["status"], e["is_unavailable"] ]).to eq([ rest, "unavailable", true ])
            end
            reset_appearances(plain_player)
            appear(plain_player, "2026-03-01", innings: 1.0)
            expect(entry_for(plain_player, target_after(3))["is_unavailable"]).to be false
          end

          it "通常選手: 中3日 injury_check / 中4日 reduced_3 / 中5日 reduced_1 / 中6日 full（前回オープナーも同じ）" do
            %w[reliever opener].each do |role|
              expected = { 3 => "injury_check", 4 => "reduced_3", 5 => "reduced_1", 6 => "full" }
              got = expected.keys.to_h do |rest|
                reset_appearances(plain_player)
                appear(plain_player, "2026-03-01", role: role, innings: 1.0)
                [ rest, entry_for(plain_player, target_after(rest))["as_starter"]["status"] ]
              end
              expect(got).to eq(expected)
            end
          end

          it "スラッシュ選手: 直近リリーフ登板の累積 2 / 3 / 4 の 3 表（中3日〜中6日）" do
            tables = {
              2.0 => { 3 => "reduced_1", 4 => "full", 5 => "full" },
              3.0 => { 3 => "reduced_3", 4 => "reduced_1", 5 => "full" },
              4.0 => { 3 => "injury_check", 4 => "reduced_3", 5 => "reduced_1", 6 => "full" }
            }
            tables.each do |innings, rows|
              got = rows.keys.to_h do |rest|
                reset_appearances(slash_player)
                appear(slash_player, "2026-03-01", innings: innings)
                [ rest, entry_for(slash_player, target_after(rest))["as_starter"]["status"] ]
              end
              expect([ innings, got ]).to eq([ innings, rows ])
            end
          end

          it "スラッシュ選手の表は登板直後（減衰前）の累積で選ぶ（累積4 は中3日で減衰して 0 でも累積4 の表）" do
            appear(slash_player, "2026-03-01", innings: 4.0)
            expect(entry_for(slash_player, target_after(3))["as_starter"]["status"]).to eq("injury_check")
          end
        end

        describe "リリーフなら: 前回が先発（§8.3.3）" do
          # [前回区分, 中日数, 通常選手, スラッシュ選手]
          {
            "normal" => { 2 => %w[unavailable reduced_0], 3 => %w[reduced_0 full], 4 => %w[full full], 1 => %w[unavailable unavailable] },
            "ko" => { 1 => %w[unavailable reduced_0], 2 => %w[reduced_0 full], 3 => %w[full full], 0 => %w[unavailable unavailable] },
            "no_game" => { 1 => %w[unavailable reduced_0], 2 => %w[reduced_0 full], 3 => %w[full full] },
            "long_loss" => { 3 => %w[unavailable reduced_0], 4 => %w[reduced_0 full], 5 => %w[full full], 2 => %w[unavailable unavailable] }
          }.each do |category, rows|
            rows.each do |rest, (plain_status, slash_status)|
              it "#{category} 中#{rest}日: 通常選手 #{plain_status} / スラッシュ選手 #{slash_status}" do
                # as_reliever の通常選手は relief_stamina があり relief_only でも starter 側が無い選手（plain_player）
                appear(plain_player, "2026-03-01", role: "starter", category: category)
                appear(slash_player, "2026-03-01", role: "starter", category: category)
                expect(entry_for(plain_player, target_after(rest))["as_reliever"]["status"]).to eq(plain_status)
                expect(entry_for(slash_player, target_after(rest))["as_reliever"]["status"]).to eq(slash_status)
              end
            end
          end
        end

        describe "リリーフなら: 前回がリリーフ（§8.3.2・AMB-19 追補）" do
          # 登板 1 回（innings 回）で累積 N を作り、翌日（休養 0 日）の状態を見る
          it "累積0 は full / 1 は reduced_0（疲労P0）/ 2 は fatigued_start（最初から疲労状態）/ 3 以上は fatigued_start_check" do
            got = [ 1.0, 2.0, 3.0, 5.0 ].map do |innings|
              reset_appearances(plain_player)
              appear(plain_player, "2026-03-01", innings: innings)
              entry_for(plain_player, target_after(0))["as_reliever"]["status"]
            end
            expect(got).to eq(%w[reduced_0 fatigued_start fatigued_start_check fatigued_start_check])
            reset_appearances(plain_player)
            appear(plain_player, "2026-03-01", innings: 1.0)
            expect(entry_for(plain_player, target_after(1))["as_reliever"]["status"]).to eq("full") # 累積 1 が 1 日で 0 に減衰
          end
        end

        # Test Basis: AMB-21（2026-10-26）。中5日 → 累積1以下（P0）、中6日以上 → 累積0（カード値）が回復の上限。減衰でそれより良ければ累積の表
        describe "リリーフなら: 中5日・中6日は回復の上限（AMB-21）" do
          def status_for(innings, rest)
            reset_appearances(plain_player)
            appear(plain_player, "2026-03-01", innings: innings)
            entry_for(plain_player, target_after(rest))["as_reliever"]["status"]
          end

          it "累積8: 休養5日 → 減衰後 3 でも reduced_0（P0）/ 休養6日 → 減衰後 1 でも full（カード値）/ 休養4日 → 上限なし" do
            expect([ status_for(8.0, 4), status_for(8.0, 5), status_for(8.0, 6) ]).to eq(%w[fatigued_start_check reduced_0 full])
          end

          it "累積0（登板後に減衰しきった状態）: 休養5日でもカード値のまま（P0 に悪化させない）" do
            expect(status_for(1.0, 5)).to eq("full")
          end

          it "累積7: 休養5日 → 減衰後 1 で reduced_0 / 休養6日 → full（上限と減衰が一致する境）" do
            expect([ status_for(7.0, 4), status_for(7.0, 5), status_for(7.0, 6) ]).to eq(%w[fatigued_start_check reduced_0 full])
          end

          it "累積9・10: 休養5日 → reduced_0 / 休養6日 → full（減衰だけでは戻りきらない分を上限が引き上げる）" do
            [ 9.0, 10.0 ].each do |innings|
              expect([ status_for(innings, 5), status_for(innings, 6) ]).to eq(%w[reduced_0 full])
            end
          end

          it "累積6以下は減衰だけで中5日 full（上限が悪化させない）" do
            expect([ status_for(6.0, 5), status_for(4.0, 5), status_for(3.0, 5) ]).to eq(%w[full full full])
          end
        end

        describe "リリーフなら: 注記" do
          it "累積0 の先発明けには注記なし。前回リリーフで累積1以上ならオープナーの負傷チェックの注記（リリーフなら側のみ）" do
            appear(plain_player, "2026-03-01", role: "starter", category: "normal")
            expect(entry_for(plain_player, target_after(4))["as_reliever"]["notes"]).to eq([])
            reset_appearances(plain_player)
            appear(plain_player, "2026-03-01", innings: 1.0)
            e = entry_for(plain_player, target_after(0))
            expect(e["as_reliever"]["notes"]).to eq([ "opener_injury_check" ])
            expect(e["as_starter"]["notes"]).to eq([])
          end

          it "累積4以上かつ前日登板: 注意書きだけ出す（合否は記録しない）。累積3 の前日登板・累積4 の中1日には出さない" do
            appear(plain_player, "2026-03-01"); appear(plain_player, "2026-03-02"); appear(plain_player, "2026-03-03")
            expect(entry_for(plain_player, "2026-03-04")["as_reliever"]["notes"]).to eq([ "opener_injury_check" ]) # 累積3・前日登板
            appear(plain_player, "2026-03-04")
            e = entry_for(plain_player, "2026-03-05") # 累積4・前日登板
            expect(e["as_reliever"]["status"]).to eq("fatigued_start_check")
            expect(e["as_reliever"]["notes"]).to eq(%w[opener_injury_check previous_day_one_inning_only])
            expect(entry_for(plain_player, "2026-03-06")["as_reliever"]["notes"]).to eq([ "opener_injury_check" ]) # 累積4→3 に減衰・中1日
          end
        end

        describe "表示の省略" do
          it "リリーフ専門（カードの is_relief_only）は「先発なら」を出さない。「リリーフなら」は出す" do
            player, = make_pitcher(starter_stamina: nil, relief_stamina: 3, is_relief_only: true)
            appear(player, "2026-03-01", role: "starter", category: "normal")
            e = entry_for(player, target_after(3))
            expect(e["as_starter"]).to be_nil
            expect(e["as_starter_omitted_reason"]).to eq("relief_only_card")
            expect(e["as_reliever"]["status"]).to eq("reduced_0")
            expect(e["is_unavailable"]).to be false
          end

          it "救援専任契約（selected_cost_type = relief_only_cost）の選手も「先発なら」を出さない。先発もできる契約に変えると再び出す" do
            player, tm = make_pitcher(starter_stamina: 7, relief_stamina: 3, cost_type: "relief_only_cost")
            appear(player, "2026-03-01", role: "starter", category: "normal")
            e = entry_for(player, target_after(3))
            expect(e["as_starter"]).to be_nil
            expect(e["as_starter_omitted_reason"]).to eq("relief_only_contract")
            expect(e["as_reliever"]).not_to be_nil

            tm.update!(selected_cost_type: "normal_cost")
            e = entry_for(player, target_after(3))
            expect(e["as_starter"]["status"]).to eq("injury_check")
            expect(e["as_starter_omitted_reason"]).to be_nil

            %w[pitcher_only_cost two_way_cost].each do |type|
              tm.update!(selected_cost_type: type)
              expect(entry_for(player, target_after(3))["as_starter"]).not_to be_nil, type
            end
            tm.update!(selected_cost_type: "relief_only_cost")
            expect(entry_for(player, target_after(3))["as_starter"]).to be_nil
          end

          it "リリーフ向けの疲労P（relief_stamina）をカードに持たない先発は「リリーフなら」を出さない。「先発なら」は出す" do
            player, = make_pitcher(starter_stamina: 7, relief_stamina: nil)
            appear(player, "2026-03-01", role: "starter", category: "normal")
            e = entry_for(player, target_after(3))
            expect(e["as_reliever"]).to be_nil
            expect(e["as_reliever_omitted_reason"]).to eq("no_relief_stamina")
            expect(e["as_starter"]["status"]).to eq("injury_check")
          end

          it "relief_only のカードは relief_stamina が無くても「リリーフなら」を出す（リリーフ専門だから）" do
            player, = make_pitcher(starter_stamina: nil, relief_stamina: nil, is_relief_only: true)
            appear(player, "2026-03-01", role: "starter", category: "normal")
            expect(entry_for(player, target_after(3))["as_reliever"]).not_to be_nil
          end

          it "スラッシュ選手（starter_stamina と relief_stamina の両方あり relief_only でない）は両方出す" do
            appear(slash_player, "2026-03-01", role: "starter", category: "normal")
            e = entry_for(slash_player, target_after(5))
            expect(e["as_starter"]).not_to be_nil
            expect(e["as_reliever"]).not_to be_nil
          end
        end

        # Test Basis: 台帳 D-11 再確認（2026-10-26 Operator）「ノーゲームは負傷と登板の疲労計算だけはする」。
        #   ノーゲームの日の登板は、休養日数・累積イニング・先発→リリーフの表のいずれからも外れない（勝敗・成績だけが対象外）
        describe "ノーゲームの日の登板も疲労・累積の計算に入る（D-11）" do
          it "ノーゲームの日のリリーフ登板（3回）は累積に入る: 翌日は 最初から疲労 + 負傷CK（通常の日と同じ）" do
            appear(plain_player, "2026-03-01", innings: 3.0, category: "no_game")
            e = entry_for(plain_player, "2026-03-02")
            expect(e["cumulative_innings"]).to eq(3)
            expect(e["as_reliever"]["status"]).to eq("fatigued_start_check")
          end

          it "ノーゲームの日と通常の日の登板は、連日なら累積が足される（1 + 1 + 1 = 3）" do
            appear(plain_player, "2026-03-01", innings: 1.0, category: "no_game")
            appear(plain_player, "2026-03-02", innings: 1.0)
            appear(plain_player, "2026-03-03", innings: 1.0, category: "no_game")
            expect(entry_for(plain_player, "2026-03-04")["cumulative_innings"]).to eq(3)
          end

          it "ノーゲームの日の先発登板は休養日数の起点になる: 前日なら rest_days 0・先発は登板不可" do
            appear(plain_player, "2026-03-01", role: "starter", category: "no_game")
            e = entry_for(plain_player, "2026-03-02")
            expect(e["rest_days"]).to eq(0)
            expect(e["as_starter"]["status"]).to eq("unavailable")
            expect(e["last_result_category"]).to eq("no_game")
          end

          it "ノーゲームの日の先発登板は、KO・ノーゲーム表で次の登板を補正する（中3日で P-3。通常なら 負傷CK）" do
            appear(plain_player, "2026-03-01", role: "starter", category: "no_game")
            expect(entry_for(plain_player, target_after(3))["as_starter"]["status"]).to eq("reduced_3")
          end

          it "ノーゲームの日の先発登板の後、リリーフは KO・ノーゲーム表（中2日 P0・AMB-22 で中1日以内は不可）" do
            appear(plain_player, "2026-03-01", role: "starter", category: "no_game")
            expect([ 1, 2, 3 ].map { |r| entry_for(plain_player, target_after(r))["as_reliever"]["status"] }).to eq(%w[unavailable reduced_0 full])
          end

          it "ノーゲームの日の登板から中10日で、通常どおりリセットされる" do
            appear(slash_player, "2026-03-01", innings: 9.0, category: "no_game")
            e = entry_for(slash_player, target_after(10))
            expect([ e["as_starter"]["status"], e["as_reliever"]["status"] ]).to eq(%w[full full])
          end

          it "負傷離脱（試合数単位）は、ノーゲームの日も試合日として数える" do
            tm = TeamMembership.find_by(team: team, player: plain_player)
            create(:season_schedule, season: season_first, date: Date.new(2026, 3, 10), no_game: true)
            create(:season_schedule, season: season_first, date: Date.new(2026, 3, 11))
            absence = create(:player_absence, team_membership: tm, season: season_first, absence_type: :injury,
                                              start_date: Date.new(2026, 3, 10), duration: 2, duration_unit: "games")
            expect(absence.effective_end_date).to eq(Date.new(2026, 3, 12))
            appear(plain_player, "2026-03-01", innings: 1.0, category: "no_game")
            expect(entry_for(plain_player, "2026-03-11")["is_injured"]).to be true
          end
        end

        describe "中10日リセット・負傷" do
          it "実日数中10日: どの前回の役割でも「先発なら」「リリーフなら」とも full（前回リリーフ・累積大でも）" do
            appear(slash_player, "2026-03-01", innings: 9.0)
            e = entry_for(slash_player, target_after(10))
            expect([ e["as_starter"]["status"], e["as_reliever"]["status"] ]).to eq(%w[full full])
          end

          it "負傷中は両方 injured" do
            appear(plain_player, "2026-03-01", innings: 1.0)
            tm = TeamMembership.find_by(team: team, player: plain_player)
            create(:player_absence, team_membership: tm, season: season_first, absence_type: :injury,
                                    start_date: Date.new(2026, 3, 5), duration: 10, duration_unit: "days")
            e = entry_for(plain_player, "2026-03-08")
            expect([ e["as_starter"]["status"], e["as_reliever"]["status"] ]).to eq(%w[injured injured])
          end

          it "負傷離脱は控除後の中日数で見る: 前回リリーフ・実日数中4日 - 負傷3日 = 中1日 → 先発不可。リセットは差し引かない実日数" do
            appear(plain_player, "2026-03-01", innings: 1.0)
            tm = TeamMembership.find_by(team: team, player: plain_player)
            create(:player_absence, team_membership: tm, season: season_first, absence_type: :injury,
                                    start_date: Date.new(2026, 3, 2), duration: 3, duration_unit: "days")
            expect(entry_for(plain_player, target_after(4))["as_starter"]["status"]).to eq("unavailable")
          end
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
