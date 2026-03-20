require "rails_helper"

RSpec.describe "Api::V1::PitcherAppearancesController", type: :request do
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
          decision: nil,
          game_result: "lose"
        })
        post "/api/v1/pitcher_appearances", params: params, as: :json

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["pitcher_appearance"]["result_category"]).to eq("ko")
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
end
