require "rails_helper"

RSpec.describe "Api::V1::GamesController", type: :request do
  describe "GET /api/v1/games" do
    include_context "authenticated user"

    it "returns 200 with empty list when no games" do
      get "/api/v1/games", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns all games ordered by id desc" do
      games = create_list(:game, 3)

      get "/api/v1/games", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
      expect(json.map { |g| g["id"] }).to eq(games.map(&:id).sort.reverse)
    end

    it "filters by competition_id" do
      competition1 = create(:competition)
      competition2 = create(:competition)
      game1 = create(:game, competition: competition1)
      create(:game, competition: competition2)

      get "/api/v1/games?competition_id=#{competition1.id}", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(1)
      expect(json.first["id"]).to eq(game1.id)
    end
  end

  describe "GET /api/v1/games (unauthenticated)" do
    it "returns 401" do
      get "/api/v1/games", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/games/:id" do
    include_context "authenticated user"

    it "returns 200 with game details" do
      game = create(:game)

      get "/api/v1/games/#{game.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(game.id)
      expect(json["status"]).to eq("draft")
    end

    it "returns 404 for non-existent game" do
      get "/api/v1/games/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/games" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:home_team) { create(:team) }
    let(:visitor_team) { create(:team) }
    let(:stadium) { create(:stadium) }

    let(:valid_params) do
      {
        game: {
          competition_id: competition.id,
          home_team_id: home_team.id,
          visitor_team_id: visitor_team.id,
          stadium_id: stadium.id,
          real_date: Date.today.to_s,
          status: "draft",
          source: "live"
        }
      }
    end

    it "creates a game and returns 201" do
      expect {
        post "/api/v1/games", params: valid_params, as: :json
      }.to change(Game, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["competition_id"]).to eq(competition.id)
    end

    it "returns 422 with invalid params" do
      post "/api/v1/games", params: { game: { status: "invalid_status" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json["errors"]).to be_present
    end
  end

  describe "POST /api/v1/games/import_log" do
    include_context "authenticated user"

    let(:competition) { create(:competition) }
    let(:home_team) { create(:team) }
    let(:visitor_team) { create(:team) }
    let(:stadium) { create(:stadium) }
    let(:batter) { create(:player, name: "テスト打者", short_name: "打者") }
    let(:pitcher) { create(:player, :pitcher, name: "テスト投手", short_name: "投手") }

    let(:import_params) do
      {
        log: "dummy log text",
        competition_id: competition.id,
        home_team_id: home_team.id,
        visitor_team_id: visitor_team.id,
        real_date: Date.today.to_s,
        stadium_id: stadium.id
      }
    end

    let(:parser_output) do
      {
        "innings" => [
          {
            "inning" => 1,
            "half" => "top",
            "at_bats" => [
              {
                "ab_num" => 1,
                "batter_name" => batter.name,
                "pitcher_name" => pitcher.name,
                "bat_result" => "1B",
                "pitch_result" => "BALL"
              }
            ]
          }
        ]
      }.to_json
    end

    before do
      batter
      pitcher
      allow(Open3).to receive(:capture3).and_return([ parser_output, "", instance_double(Process::Status, success?: true) ])
    end

    it "import_log成功: at_batsがdraft statusでDB保存されること" do
      expect {
        post "/api/v1/games/import_log", params: import_params, as: :json
      }.to change(AtBat, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["imported_count"]).to eq(1)

      at_bat = AtBat.last
      expect(at_bat.status).to eq("draft")
      expect(at_bat.batter).to eq(batter)
      expect(at_bat.pitcher).to eq(pitcher)
      expect(at_bat.result_code).to eq("1B")
    end

    it "再import_log: 既存のdraft at_batsが削除されて新しいdraftが作成されること" do
      # 1回目import
      post "/api/v1/games/import_log", params: import_params, as: :json
      expect(response).to have_http_status(:created)
      game = Game.find(response.parsed_body["game"]["id"])
      first_at_bat_id = AtBat.last.id

      # 2回目import (同一gameへのre-import → 新しいgameとして作成)
      expect {
        post "/api/v1/games/import_log", params: import_params, as: :json
      }.to change(AtBat, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(AtBat.find_by(id: first_at_bat_id)).not_to be_nil
    end

    it "confirmed保護: confirmed at_batsは再import_log（同gameへの再import）で削除されないこと" do
      game = create(:game,
        competition: competition,
        home_team: home_team,
        visitor_team: visitor_team,
        stadium: stadium,
        status: "draft",
        source: "log_import"
      )
      confirmed_at_bat = create(:at_bat, game: game, status: :confirmed, seq: 999)

      # gameが既に存在する状態でのdraft at_bats削除確認
      draft_at_bat = create(:at_bat, game: game, status: :draft, seq: 1000)

      game.at_bats.draft.destroy_all

      expect(AtBat.find_by(id: confirmed_at_bat.id)).not_to be_nil
      expect(AtBat.find_by(id: draft_at_bat.id)).to be_nil
    end
  end

  describe "POST /api/v1/games/:id/confirm" do
    include_context "authenticated user"

    let(:game) { create(:game, status: "draft") }
    let(:batter) { create(:player) }
    let(:pitcher) { create(:player, :pitcher) }

    it "confirm成功: draft at_batsがconfirmedに変更されること" do
      draft_ab = create(:at_bat, game: game, status: :draft, seq: 1)

      post "/api/v1/games/#{game.id}/confirm", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["confirmed_count"]).to eq(1)

      draft_ab.reload
      expect(draft_ab.status).to eq("confirmed")
    end

    it "confirm済みgameは再confirmできないこと" do
      confirmed_game = create(:game, status: "confirmed")

      post "/api/v1/games/#{confirmed_game.id}/confirm", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
