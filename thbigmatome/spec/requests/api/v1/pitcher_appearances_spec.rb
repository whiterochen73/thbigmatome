require "rails_helper"

RSpec.describe "Api::V1::PitcherAppearancesController", type: :request, pitcher_fatigue: true do
  describe "POST /api/v1/pitcher_appearances" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:team) { create(:team) }
    let(:pitcher) { create(:player, :pitcher) }
    let(:game) do
      create(:game, competition: competition, home_team: team, visitor_team: create(:team),
                    home_schedule_date: "2026-03-20")
    end

    let(:valid_params) do
      {
        pitcher_appearance: {
          pitcher_id: pitcher.id,
          team_id: team.id,
          competition_id: competition.id,
          game_id: game.id,
          role: "starter",
          innings_pitched: 7.0,
          earned_runs: 1,
          fatigue_p_used: 5,
          decision: "W",
          schedule_date: "2026-03-20",
          is_opener: false
        }
      }
    end

    context "game_idあり" do
      it "201を返し登板を登録する" do
        post "/api/v1/pitcher_appearances", params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["pitcher_id"]).to eq(pitcher.id)
        expect(json["pitcher_appearance"]["decision"]).to eq("W")
        expect(json["warnings"]).to be_an(Array)
      end

      it "DB にレコードが作成される" do
        expect {
          post "/api/v1/pitcher_appearances", params: valid_params, as: :json
        }.to change(PitcherGameState, :count).by(1)
      end
    end

    context "game_idなし・schedule_date指定" do
      let(:params_without_game_id) do
        {
          pitcher_appearance: {
            pitcher_id: pitcher.id,
            team_id: team.id,
            competition_id: competition.id,
            role: "reliever",
            innings_pitched: 2.0,
            earned_runs: 0,
            fatigue_p_used: 0,
            schedule_date: "2026-03-21",
            is_opener: false
          }
        }
      end

      it "Gameを自動作成して登板を登録する" do
        expect {
          post "/api/v1/pitcher_appearances", params: params_without_game_id, as: :json
        }.to change(Game, :count).by(1).and change(PitcherGameState, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "既存Gameを再利用する" do
        existing_game = create(:game,
          competition: competition,
          home_team: team,
          visitor_team: create(:team),
          home_schedule_date: "2026-03-21"
        )

        expect {
          post "/api/v1/pitcher_appearances", params: params_without_game_id, as: :json
        }.not_to change(Game, :count)

        expect(PitcherGameState.last.game_id).to eq(existing_game.id)
      end
    end

    context "game_idなし・competition_idなし（CompetitionEntry未登録チーム）" do
      let(:params_without_competition) do
        {
          pitcher_appearance: {
            pitcher_id: pitcher.id,
            team_id: team.id,
            role: "reliever",
            innings_pitched: 2.0,
            earned_runs: 0,
            fatigue_p_used: 0,
            schedule_date: "2026-04-01",
            is_opener: false
          }
        }
      end

      it "competition_idなしでもGameを作成して登板を登録できる" do
        expect {
          post "/api/v1/pitcher_appearances", params: params_without_competition, as: :json
        }.to change(Game, :count).by(1).and change(PitcherGameState, :count).by(1)

        expect(response).to have_http_status(:created)
        created_game = Game.last
        expect(created_game.competition_id).to be_nil
      end
    end

    context "バリデーション: W/L/S/H制約" do
      before { game }  # ensure game exists

      it "同じ試合に2人目のWがいる場合warningを返す" do
        other_pitcher = create(:player, :pitcher)
        create(:pitcher_game_state, game: game, team: team, pitcher: other_pitcher,
                                    competition: competition, role: "starter", decision: "W",
                                    earned_runs: 0)

        post "/api/v1/pitcher_appearances", params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("W（勝利投手）は試合に1人のみです")
      end

      it "同じ試合に2人目のLがいる場合warningを返す" do
        other_pitcher = create(:player, :pitcher)
        create(:pitcher_game_state, game: game, team: team, pitcher: other_pitcher,
                                    competition: competition, role: "starter", decision: "L",
                                    earned_runs: 2)

        params = valid_params.deep_merge(pitcher_appearance: { decision: "L" })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("L（敗戦投手）は試合に1人のみです")
      end
    end

    context "result_category 自動計算" do
      it "先発でinnings < 5かつ後続投手ありの場合 ko になる" do
        other_pitcher = create(:player, :pitcher)
        create(:pitcher_game_state, game: game, team: team, pitcher: other_pitcher,
                                    competition: competition, role: "reliever", earned_runs: 0)

        params = valid_params.deep_merge(pitcher_appearance: {
          role: "starter",
          innings_pitched: 3.0,
          decision: "L",
          game_result: "lose"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["result_category"]).to eq("ko")
      end

      it "game_result == no_game の場合 no_game になる" do
        params = valid_params.deep_merge(pitcher_appearance: {
          role: "starter",
          innings_pitched: 3.0,
          decision: nil,
          game_result: "no_game",
          result_category: nil
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["result_category"]).to eq("no_game")
      end

      # E1: 疲労P は画面の fatigue_p_used ではなく、チームの登録カード + 試合前のスタミナ補正からサーバが求める。
      # 旧テストは「画面が fatigue_p_used=5 を送る」「0 なら既定3」を前提にしていたが、裁定 2026-10-25 で廃止した。
      it "E1: 画面が fatigue_p_used=0 を送っても、カード疲労P 7 の先発が負け試合で 8.0回 → normal、8.1回 → long_loss" do
        create(:team_membership, team: team, player: pitcher,
                                 player_card: create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: 7))
        [ [ 8.0, "normal" ], [ 8.1, "long_loss" ] ].each do |innings, expected|
          PitcherGameState.where(game_id: game.id).delete_all
          params = valid_params.deep_merge(pitcher_appearance: {
            role: "starter", innings_pitched: innings, fatigue_p_used: 0, decision: nil, game_result: "lose"
          })
          post "/api/v1/pitcher_appearances", params: params, as: :json

          expect(response).to have_http_status(:created)
          json = response.parsed_body["pitcher_appearance"]
          expect(json["result_category"]).to eq(expected)
          expect(json["fatigue_p_used"]).to eq(7) # サーバが求めた値を保存する
        end
      end

      it "E1: カードに先発疲労P の記載が無い先発だけ既定3（4.0回 → normal、4.1回 → long_loss）" do
        create(:team_membership, team: team, player: pitcher,
                                 player_card: create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: nil))
        [ [ 4.0, "normal" ], [ 4.1, "long_loss" ] ].each do |innings, expected|
          PitcherGameState.where(game_id: game.id).delete_all
          params = valid_params.deep_merge(pitcher_appearance: { role: "starter", innings_pitched: innings, fatigue_p_used: 0, game_result: "lose" })
          post "/api/v1/pitcher_appearances", params: params, as: :json
          expect(response.parsed_body["pitcher_appearance"]["result_category"]).to eq(expected)
        end
      end

      it "E1: チームの登録にカードが無い投手は既定3にせず判定保留（result_category nil + warning）" do
        params = valid_params.deep_merge(pitcher_appearance: { role: "starter", innings_pitched: 8.0, fatigue_p_used: 0, game_result: "lose" })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["result_category"]).to be_nil
        expect(json["pitcher_appearance"]["fatigue_p_used"]).to be_nil
        expect(json["warnings"].join).to include("判定保留")
      end

      it "E1: 前回登板から中4日(-3)で P7→4 の先発は 5.1回・負け → long_loss、5.0回 → normal" do
        create(:team_membership, team: team, player: pitcher,
                                 player_card: create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: 7))
        create(:pitcher_game_state, team: team, pitcher: pitcher, schedule_date: "2026-03-15", role: "starter",
                                    innings_pitched: 6.0, result_category: "normal", competition: competition)
        [ [ 5.0, "normal" ], [ 5.1, "long_loss" ] ].each do |innings, expected|
          PitcherGameState.where(game_id: game.id).delete_all
          params = valid_params.deep_merge(pitcher_appearance: { role: "starter", innings_pitched: innings, fatigue_p_used: 0, game_result: "lose" })
          post "/api/v1/pitcher_appearances", params: params, as: :json
          json = response.parsed_body["pitcher_appearance"]
          expect([ json["result_category"], json["fatigue_p_used"] ]).to eq([ expected, 4 ])
        end
      end

      context "E4相当(裁定4): 勝敗は試合概要の得点から決める（画面の game_result に頼らない）" do
        let(:season) { create(:season, team: team) }

        before do
          create(:team_membership, team: team, player: pitcher,
                                   player_card: create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: 7))
        end

        def post_nine_innings(game_result)
          params = valid_params.deep_merge(pitcher_appearance: { role: "starter", innings_pitched: 9.0, fatigue_p_used: 0, game_result: game_result })
          post "/api/v1/pitcher_appearances", params: params, as: :json
          response.parsed_body["pitcher_appearance"]["result_category"]
        end

        it "得点が負けなら、画面が win を送っても long_loss（9回 > 7+1）" do
          create_schedule(season, "2026-03-20", score: 1, opponent_score: 2)
          expect(post_nine_innings("win")).to eq("long_loss")
        end

        it "得点が勝ちなら、画面が lose を送っても normal" do
          create_schedule(season, "2026-03-20", score: 3, opponent_score: 2)
          expect(post_nine_innings("lose")).to eq("normal")
        end

        it "同点・得点未入力は負けではない（画面が lose を送っても normal）" do
          schedule = create_schedule(season, "2026-03-20", score: 2, opponent_score: 2)
          expect(post_nine_innings("lose")).to eq("normal")
          PitcherGameState.where(game_id: game.id).delete_all
          schedule.update_columns(score: nil, opponent_score: nil)
          expect(post_nine_innings("lose")).to eq("normal")
        end
      end
    end

    context "E2: 試合の得点が後から変わると先発の result_category が作り直される" do
      it "PUT /api/v1/game/:id で負け→勝ちに直すと long_loss が normal になる" do
        season = create(:season, team: team)
        schedule = create_schedule(season, "2026-03-20", score: 1, opponent_score: 4)
        create(:team_membership, team: team, player: pitcher,
                                 player_card: create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: 7))
        state = create_start(team: team, pitcher: pitcher, date: "2026-03-20", innings: 9.0, category: "long_loss", game: game)

        put "/api/v1/game/#{schedule.id}", params: { score: 5, opponent_score: 4 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(state.reload.result_category).to eq("normal")
      end
    end

    context "result_category 自動計算（続き）" do
      it "先発で通常パターンの場合 normal になる" do
        params = valid_params.deep_merge(pitcher_appearance: {
          role: "starter",
          innings_pitched: 7.0,
          fatigue_p_used: 5,
          decision: nil,
          game_result: "win",
          result_category: nil
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["result_category"]).to eq("normal")
      end
    end

    context "validate_decision: W/L/S 試合結果制約" do
      before { game }

      it "Wは勝ち試合以外でwarningを返す" do
        params = valid_params.deep_merge(pitcher_appearance: {
          decision: "W",
          game_result: "lose"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("W（勝利投手）は勝ち試合のみです")
      end

      it "Lは負け試合以外でwarningを返す" do
        params = valid_params.deep_merge(pitcher_appearance: {
          decision: "L",
          game_result: "win"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("L（敗戦投手）は負け試合のみです")
      end

      it "Sは勝ち試合以外でwarningを返す" do
        params = valid_params.deep_merge(pitcher_appearance: {
          role: "reliever",
          decision: "S",
          game_result: "lose"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("S（セーブ）は勝ち試合のみです")
      end

      it "Sを先発に付与するとwarningを返す" do
        params = valid_params.deep_merge(pitcher_appearance: {
          role: "starter",
          decision: "S",
          game_result: "win"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("S（セーブ）は先発以外（リリーフ/オープナー）のみです")
      end

      it "Hを先発に付与するとwarningを返す" do
        params = valid_params.deep_merge(pitcher_appearance: {
          role: "starter",
          decision: "H",
          game_result: "win"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["warnings"]).to include("H（ホールド）は先発以外（リリーフ/オープナー）のみです")
      end
    end

    context "必須パラメータ不足" do
      it "game_idもschedule_dateもなければエラー" do
        params = {
          pitcher_appearance: {
            pitcher_id: pitcher.id,
            role: "starter",
            earned_runs: 0
          }
        }
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/pitcher_appearances/bulk_save" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:team) { create(:team) }
    let(:pitcher1) { create(:player, :pitcher) }
    let(:pitcher2) { create(:player, :pitcher) }
    let(:game) do
      create(:game, competition: competition, home_team: team, visitor_team: create(:team),
                    home_schedule_date: "2026-03-20")
    end

    let(:bulk_params) do
      {
        pitcher_appearances_bulk: {
          team_id: team.id,
          competition_id: competition.id,
          game_id: game.id,
          schedule_date: "2026-03-20",
          game_result: "win",
          appearances: [
            {
              pitcher_id: pitcher1.id,
              role: "starter",
              innings_pitched: 6.0,
              earned_runs: 1,
              fatigue_p_used: 4,
              decision: "W",
              is_opener: false,
              consecutive_short_rest_count: 0,
              pre_injury_days_excluded: 0
            },
            {
              pitcher_id: pitcher2.id,
              role: "reliever",
              innings_pitched: 3.0,
              earned_runs: 0,
              fatigue_p_used: 0,
              decision: "S",
              is_opener: false,
              consecutive_short_rest_count: 0,
              pre_injury_days_excluded: 0
            }
          ]
        }
      }
    end

    context "bulk_save: result_category は試合概要の得点とカードからサーバが決める（E1・裁定4・関与イニング）" do
      let(:season) { create(:season, team: team) }

      def bulk_with(appearances)
        { pitcher_appearances_bulk: { team_id: team.id, competition_id: competition.id, game_id: game.id,
                                      schedule_date: "2026-03-20", game_result: "win", appearances: appearances } }
      end

      def ap(pitcher, role, innings, **extra)
        { pitcher_id: pitcher.id, role: role, innings_pitched: innings, earned_runs: 0, fatigue_p_used: 0,
          is_opener: false, consecutive_short_rest_count: 0, pre_injury_days_excluded: 0 }.merge(extra)
      end

      it "画面が game_result=win を送っても、試合概要が負けなら先発(疲労P7)の 8.1回は long_loss、fatigue_p_used に 7 を保存" do
        create(:team_membership, team: team, player: pitcher1,
                                 player_card: create(:player_card, player: pitcher1, card_type: "pitcher", starter_stamina: 7))
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        post "/api/v1/pitcher_appearances/bulk_save", params: bulk_with([ ap(pitcher1, "starter", 8.1), ap(pitcher2, "reliever", 0.2) ]), as: :json

        expect(response).to have_http_status(:ok)
        state = PitcherGameState.find_by(game: game, pitcher: pitcher1)
        expect(state).to have_attributes(result_category: "long_loss", fatigue_p_used: 7)
      end

      it "前の投手が1回1/3を投げた後に入った先発扱い(role=starter)の投手が 6.2回 → 関与7（疲労P6 は normal、疲労P5 は long_loss）" do
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        { 6 => "normal", 5 => "long_loss" }.each do |stamina, expected|
          second = create(:player, :pitcher)
          create(:team_membership, team: team, player: second,
                                   player_card: create(:player_card, player: second, card_type: "pitcher", starter_stamina: stamina))
          PitcherGameState.where(game_id: game.id).delete_all
          post "/api/v1/pitcher_appearances/bulk_save",
               params: bulk_with([ ap(pitcher2, "opener", 1.1), ap(second, "starter", 6.2) ]), as: :json
          expect(PitcherGameState.find_by(game: game, pitcher: second).result_category).to eq(expected)
        end
      end

      it "カードを特定できない先発は result_category nil + 判定保留の warning（既定3 にしない）" do
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        post "/api/v1/pitcher_appearances/bulk_save", params: bulk_with([ ap(pitcher1, "starter", 8.0) ]), as: :json

        expect(response).to have_http_status(:ok)
        expect(PitcherGameState.find_by(game: game, pitcher: pitcher1).result_category).to be_nil
        expect(response.parsed_body["warnings"].join).to include("判定保留")
      end
    end

    # Test Basis: cmd_1775 第2段 E3（rulebook §8.5.1 条件2・§8.7.1 手順3）/ E4（AMB-04 出場停止と負傷は別枠）
    context "bulk_save: 連続中4日カウント consecutive_short_rest_count はサーバが書く（E3）" do
      let(:season) { create(:season, team: team) }
      let!(:membership) do
        create(:team_membership, team: team, player: pitcher1,
                                 player_card: create(:player_card, player: pitcher1, card_type: "pitcher", starter_stamina: 7))
      end

      def bulk_with(appearances)
        { pitcher_appearances_bulk: { team_id: team.id, competition_id: competition.id, game_id: game.id,
                                      schedule_date: "2026-03-20", game_result: "win", appearances: appearances } }
      end

      def ap(pitcher, role, innings, **extra)
        { pitcher_id: pitcher.id, role: role, innings_pitched: innings, earned_runs: 0, fatigue_p_used: 0,
          is_opener: false, consecutive_short_rest_count: 0, pre_injury_days_excluded: 0 }.merge(extra)
      end

      def saved_count(pitcher = pitcher1)
        PitcherGameState.find_by(game: game, pitcher: pitcher).consecutive_short_rest_count
      end

      def save_start(**extra)
        post "/api/v1/pitcher_appearances/bulk_save", params: bulk_with([ ap(pitcher1, "starter", 6.0, **extra) ]), as: :json
        expect(response).to have_http_status(:ok)
      end

      it "中4日（3/15 → 3/20）なら前回値 +1。画面が 0 を送っても 0 で上書きしない" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-15", innings: 6.0, consecutive_short_rest_count: 0)
        save_start(consecutive_short_rest_count: 0)
        expect(saved_count).to eq(1)
      end

      it "前回が 1 なら 2（連続中4日の 3 回目）。画面が別の値(5)を送っても無視してサーバの値になる" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-15", innings: 6.0, consecutive_short_rest_count: 1)
        save_start(consecutive_short_rest_count: 5)
        expect(saved_count).to eq(2)
      end

      it "中5日（3/14 → 3/20）は 0 にリセット（前回 2、画面 3 でも）" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-14", innings: 6.0, consecutive_short_rest_count: 2)
        save_start(consecutive_short_rest_count: 3)
        expect(saved_count).to eq(0)
      end

      it "中3日（3/16 → 3/20）も 0" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-16", innings: 6.0, consecutive_short_rest_count: 1)
        save_start
        expect(saved_count).to eq(0)
      end

      it "同じ登板記録を保存し直しても増えない（冪等: 1 のまま）" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-15", innings: 6.0, consecutive_short_rest_count: 0)
        save_start
        save_start
        expect(saved_count).to eq(1)
      end

      it "負傷を挟んだ中日数は控除する（実日数中5日 - 負傷1日 = 中4日 → +1）" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-14", innings: 6.0, consecutive_short_rest_count: 0)
        create(:player_absence, team_membership: membership, season: season, absence_type: :injury,
                                start_date: Date.new(2026, 3, 15), duration: 1, duration_unit: "days")
        save_start
        expect(saved_count).to eq(1)
      end

      it "出場停止を挟んだ中日数は控除しない（実日数中5日のまま → 0。負傷なら +1 になる日付）" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-14", innings: 6.0, consecutive_short_rest_count: 1)
        create(:player_absence, team_membership: membership, season: season, absence_type: :suspension,
                                start_date: Date.new(2026, 3, 15), duration: 1, duration_unit: "days")
        save_start
        expect(saved_count).to eq(0)
      end

      it "リリーフ登板のカウントは 0（画面が値を送っても書かない）" do
        post "/api/v1/pitcher_appearances/bulk_save",
             params: bulk_with([ ap(pitcher1, "starter", 6.0), ap(pitcher2, "reliever", 2.0, consecutive_short_rest_count: 2) ]), as: :json
        expect(saved_count(pitcher2)).to eq(0)
      end

      it "単発登録 POST /pitcher_appearances でも同じ規則で書く（中4日 → +1）" do
        create_start(team: team, pitcher: pitcher1, date: "2026-03-15", innings: 6.0, consecutive_short_rest_count: 0)
        post "/api/v1/pitcher_appearances",
             params: { pitcher_appearance: { pitcher_id: pitcher1.id, team_id: team.id, competition_id: competition.id,
                                             game_id: game.id, role: "starter", innings_pitched: 6.0, earned_runs: 0,
                                             schedule_date: "2026-03-20", consecutive_short_rest_count: 0 } }, as: :json
        expect(response).to have_http_status(:created)
        expect(response.parsed_body["pitcher_appearance"]["consecutive_short_rest_count"]).to eq(1)
      end
    end

    # Test Basis: rulebook §8.4.2（第二先発候補の2番手は先発として扱う）/ cmd_1775 第2段 E6
    context "bulk_save: 第二先発（2番手を role=starter で保存）は先発として扱われる（E6）" do
      let(:pitcher3) { create(:player, :pitcher) }
      let(:season) { create(:season, team: team) }

      def bulk_with(appearances, date: "2026-03-20", game_id: game.id)
        { pitcher_appearances_bulk: { team_id: team.id, competition_id: competition.id, game_id: game_id,
                                      schedule_date: date, game_result: "win", appearances: appearances } }
      end

      def ap(pitcher, role, innings, **extra)
        { pitcher_id: pitcher.id, role: role, innings_pitched: innings, earned_runs: 0, fatigue_p_used: 0,
          is_opener: false, pre_injury_days_excluded: 0 }.merge(extra)
      end

      before do
        create(:team_membership, team: team, player: pitcher2,
                                 player_card: create(:player_card, player: pitcher2, card_type: "pitcher", starter_stamina: 7))
      end

      it "保存した role=starter が GET で role=starter のまま返る（開き直しで先発のまま復元できる）" do
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        post "/api/v1/pitcher_appearances/bulk_save",
             params: bulk_with([ ap(pitcher1, "opener", 1.0), ap(pitcher2, "starter", 6.0), ap(pitcher3, "reliever", 2.0) ]), as: :json
        expect(response).to have_http_status(:ok)

        get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-03-20" }
        expect(response.parsed_body.map { |a| [ a["pitcher_id"], a["role"] ] })
          .to eq([ [ pitcher1.id, "opener" ], [ pitcher2.id, "starter" ], [ pitcher3.id, "reliever" ] ])
      end

      it "KO 判定が効く: 負け・L・3.0回・後続あり の第二先発は ko" do
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        post "/api/v1/pitcher_appearances/bulk_save",
             params: bulk_with([ ap(pitcher1, "opener", 1.0), ap(pitcher2, "starter", 3.0, decision: "L"), ap(pitcher3, "reliever", 4.0) ]), as: :json
        expect(PitcherGameState.find_by(game: game, pitcher: pitcher2).result_category).to eq("ko")
      end

      it "長イニング敗戦が効き、次回登板の休養表も先発のもの（長イニング敗戦・中4日 -4）が効く" do
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        # opener 1.1 の後に入って 8.0 回: 関与 9（入った回2 → 終了回10 → 9）> 7+1 → long_loss
        post "/api/v1/pitcher_appearances/bulk_save",
             params: bulk_with([ ap(pitcher1, "opener", 1.1), ap(pitcher2, "starter", 8.0) ]), as: :json
        expect(PitcherGameState.find_by(game: game, pitcher: pitcher2).result_category).to eq("long_loss")

        next_game = create(:game, competition: competition, home_team: team, visitor_team: create(:team),
                                  home_schedule_date: "2026-03-25")
        # 3/20 → 3/25 は中4日。長イニング敗戦後の中4日は -4 → 7 - 4 = 3（リリーフ扱いなら通常表の -3 → 4 か累積）
        post "/api/v1/pitcher_appearances/bulk_save",
             params: bulk_with([ ap(pitcher2, "starter", 5.0) ], date: "2026-03-25", game_id: next_game.id), as: :json
        expect(PitcherGameState.find_by(game: next_game, pitcher: pitcher2).fatigue_p_used).to eq(3)
      end

      it "role=reliever のままだと先発の判定を受けない（比較: 同じ入力で result_category は normal）" do
        create_schedule(season, "2026-03-20", score: 0, opponent_score: 1)
        post "/api/v1/pitcher_appearances/bulk_save",
             params: bulk_with([ ap(pitcher1, "opener", 1.1), ap(pitcher2, "reliever", 8.0) ]), as: :json
        expect(PitcherGameState.find_by(game: game, pitcher: pitcher2).result_category).to eq("normal")
      end
    end

    # Test Basis: cmd_1775 第1段 QC の残り(1)（日付なしで 500 → 422）
    context "bulk_save: schedule_date が無い・読めない時は 500 ではなく 422（第1段QC 注意点1）" do
      let(:body) do
        { pitcher_appearances_bulk: { team_id: team.id, competition_id: competition.id, game_id: game.id, game_result: "win",
                                      appearances: [ { pitcher_id: pitcher1.id, role: "starter", innings_pitched: 6.0, earned_runs: 0 } ] } }
      end

      it "schedule_date なし（game_id だけ）の先発は 422 と schedule_date を示すメッセージ" do
        post "/api/v1/pitcher_appearances/bulk_save", params: body, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"].join).to include("schedule_date")
      end

      it "空文字の schedule_date も 422" do
        body[:pitcher_appearances_bulk][:schedule_date] = ""
        post "/api/v1/pitcher_appearances/bulk_save", params: body, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "日付として読めない schedule_date は 422（値を含めて示す）" do
        body[:pitcher_appearances_bulk][:schedule_date] = "not-a-date"
        post "/api/v1/pitcher_appearances/bulk_save", params: body, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"].join).to include("not-a-date")
      end

      it "game_id なしで日付が読めない場合も 500 にならず 422" do
        body[:pitcher_appearances_bulk].delete(:game_id)
        body[:pitcher_appearances_bulk][:schedule_date] = "garbage"
        post "/api/v1/pitcher_appearances/bulk_save", params: body, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "登板が空でも game_id なしで日付が読めなければ（試合を日付で探せない）422" do
        params = { pitcher_appearances_bulk: { team_id: team.id, schedule_date: "garbage", appearances: [] } }
        post "/api/v1/pitcher_appearances/bulk_save", params: params, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "422 の時は何も保存しない" do
        expect { post "/api/v1/pitcher_appearances/bulk_save", params: body, as: :json }.not_to change(PitcherGameState, :count)
      end

      it "単発登録 POST /pitcher_appearances も schedule_date なし（game_id だけ）は 422" do
        post "/api/v1/pitcher_appearances",
             params: { pitcher_appearance: { pitcher_id: pitcher1.id, team_id: team.id, game_id: game.id, role: "starter",
                                             innings_pitched: 6.0, earned_runs: 0 } }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"].join).to include("schedule_date")
      end

      it "単発登録で日付が読めなくても 422" do
        post "/api/v1/pitcher_appearances",
             params: { pitcher_appearance: { pitcher_id: pitcher1.id, team_id: team.id, game_id: game.id, role: "starter",
                                             innings_pitched: 6.0, earned_runs: 0, schedule_date: "xx" } }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "正常系: 複数投手を一括保存" do
      it "200を返し全投手を登録する" do
        post "/api/v1/pitcher_appearances/bulk_save", params: bulk_params, as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["pitcher_appearances"].length).to eq(2)
        expect(json["warnings"]).to be_an(Array)
      end

      it "DBに2件レコードが作成される" do
        expect {
          post "/api/v1/pitcher_appearances/bulk_save", params: bulk_params, as: :json
        }.to change(PitcherGameState, :count).by(2)
      end
    end

    context "upsert: 既存レコードを更新する" do
      it "既存レコードがある投手は更新される" do
        existing = create(:pitcher_game_state,
          game: game, team: team, pitcher: pitcher1, competition: competition,
          role: "starter", earned_runs: 3, innings_pitched: 5.0)

        post "/api/v1/pitcher_appearances/bulk_save", params: bulk_params, as: :json

        expect(response).to have_http_status(:ok)
        expect { existing.reload }.not_to raise_error
        expect(existing.reload.earned_runs).to eq(1)
        expect(PitcherGameState.where(game: game, team: team).count).to eq(2)
      end
    end

    context "トランザクション: 1件でもエラーなら全件ロールバック" do
      it "バリデーションエラーで全件ロールバックされる" do
        invalid_params = bulk_params.deep_merge(
          pitcher_appearances_bulk: {
            appearances: bulk_params[:pitcher_appearances_bulk][:appearances].map.with_index do |ap, i|
              i == 1 ? ap.merge(role: "invalid_role") : ap
            end
          }
        )

        expect {
          post "/api/v1/pitcher_appearances/bulk_save", params: invalid_params, as: :json
        }.not_to change(PitcherGameState, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["errors"]).to be_present
        expect(json["pitcher_id"]).to eq(pitcher2.id)
      end
    end

    context "game_idなし: schedule_dateからGame自動検索" do
      let(:params_without_game_id) do
        {
          pitcher_appearances_bulk: {
            team_id: team.id,
            competition_id: competition.id,
            schedule_date: "2026-03-20",
            game_result: "win",
            appearances: [
              {
                pitcher_id: pitcher1.id,
                role: "starter",
                innings_pitched: 9.0,
                earned_runs: 0,
                fatigue_p_used: 0,
                decision: "W",
                is_opener: false,
                consecutive_short_rest_count: 0,
                pre_injury_days_excluded: 0
              }
            ]
          }
        }
      end

      it "既存Gameを利用して登録できる" do
        game  # ensure game exists

        expect {
          post "/api/v1/pitcher_appearances/bulk_save", params: params_without_game_id, as: :json
        }.not_to change(Game, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context "appearances が空の場合" do
      it "0件で成功する" do
        params = { pitcher_appearances_bulk: { team_id: team.id, game_id: game.id, game_result: "win", appearances: [] } }
        post "/api/v1/pitcher_appearances/bulk_save", params: params, as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["pitcher_appearances"]).to be_empty
      end
    end
  end

  describe "POST /api/v1/pitcher_appearances" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:team) { create(:team) }
    let(:pitcher) { create(:player, :pitcher) }
    let(:game) do
      create(:game, competition: competition, home_team: team, visitor_team: create(:team),
                    home_schedule_date: "2026-03-20")
    end

    let(:valid_params) do
      {
        pitcher_appearance: {
          pitcher_id: pitcher.id,
          team_id: team.id,
          competition_id: competition.id,
          game_id: game.id,
          role: "starter",
          innings_pitched: 7.0,
          earned_runs: 1,
          fatigue_p_used: 5,
          decision: "W",
          schedule_date: "2026-03-20",
          is_opener: false
        }
      }
    end

    context "game_idあり" do
      it "game_idもschedule_dateもなければエラー" do
        params = {
          pitcher_appearance: {
            pitcher_id: pitcher.id,
            role: "starter",
            earned_runs: 0
          }
        }
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "新規カラム is_opener" do
      it "is_opener: true で登録できる" do
        params = valid_params.deep_merge(pitcher_appearance: {
          role: "opener",
          is_opener: true,
          decision: nil
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["is_opener"]).to eq(true)
      end
    end
  end

  describe "GET /api/v1/pitcher_appearances" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:team) { create(:team) }
    let(:pitcher) { create(:player, :pitcher) }
    let(:game) do
      create(:game, competition: competition, home_team: team, visitor_team: create(:team),
                    home_schedule_date: "2026-03-22")
    end

    context "team_id と schedule_date を指定" do
      it "一致する登板記録を返す" do
        create(:pitcher_game_state,
          pitcher: pitcher,
          team: team,
          game: game,
          competition: competition,
          schedule_date: "2026-03-22",
          role: "starter",
          innings_pitched: 6.0,
          earned_runs: 1
        )

        get "/api/v1/pitcher_appearances",
          params: { team_id: team.id, schedule_date: "2026-03-22" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.length).to eq(1)
        expect(json[0]["pitcher_id"]).to eq(pitcher.id)
        expect(json[0]["role"]).to eq("starter")
        expect(json[0]["innings_pitched"]).to eq(6.0)
      end
    end

    context "該当日に登板記録なし" do
      it "空配列を返す" do
        get "/api/v1/pitcher_appearances",
          params: { team_id: team.id, schedule_date: "2026-03-22" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end

    context "パラメータなし" do
      it "空配列を返す" do
        get "/api/v1/pitcher_appearances"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end

    context "別チームの登板記録は含まない" do
      it "指定チームのレコードのみ返す" do
        other_team = create(:team)
        other_game = create(:game, competition: competition, home_team: other_team,
                                   visitor_team: create(:team), home_schedule_date: "2026-03-22")
        create(:pitcher_game_state,
          pitcher: pitcher,
          team: other_team,
          game: other_game,
          competition: competition,
          schedule_date: "2026-03-22",
          role: "starter"
        )

        get "/api/v1/pitcher_appearances",
          params: { team_id: team.id, schedule_date: "2026-03-22" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end
  end
end
