require "rails_helper"

RSpec.describe "Api::V1::GameLineupEntries", type: :request do
  let(:game) { create(:game) }
  let(:player1) { create(:player, name: "霊夢") }
  let(:player2) { create(:player, name: "魔理沙") }
  let(:player_card1) { create(:player_card, player: player1) }
  let(:player_card2) { create(:player_card, player: player2) }

  def lineup_url
    "/api/v1/games/#{game.id}/lineup"
  end

  describe "認証なしアクセス" do
    it "GET /lineup → 401" do
      get lineup_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /lineup → 401" do
      post lineup_url, params: { lineup: [] }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "PUT /lineup → 401" do
      put lineup_url, params: { lineup: [] }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/games/:game_id/lineup" do
    include_context "authenticated user"

    context "エントリーが存在する場合" do
      before do
        create(:game_lineup_entry, game: game, player_card: player_card1, batting_order: 1, position: "P")
        create(:game_lineup_entry, game: game, player_card: player_card2, role: :bench, batting_order: nil, position: nil)
      end

      it "200を返す" do
        get lineup_url
        expect(response).to have_http_status(:ok)
      end

      it "lineup キーを含む" do
        get lineup_url
        json = JSON.parse(response.body)
        expect(json).to have_key("lineup")
        expect(json["lineup"].length).to eq(2)
      end

      it "各エントリに必要なキーが含まれる" do
        get lineup_url
        json = JSON.parse(response.body)
        entry = json["lineup"].first
        expect(entry).to have_key("id")
        expect(entry).to have_key("player_card_id")
        expect(entry).to have_key("player_name")
        expect(entry).to have_key("role")
        expect(entry).to have_key("batting_order")
        expect(entry).to have_key("position")
        expect(entry).to have_key("is_dh_pitcher")
        expect(entry).to have_key("is_reliever")
      end

      it "player_name が正しく返る" do
        get lineup_url
        json = JSON.parse(response.body)
        names = json["lineup"].map { |e| e["player_name"] }
        expect(names).to include("霊夢", "魔理沙")
      end
    end

    context "エントリーが存在しない場合" do
      it "空のlineupを返す" do
        get lineup_url
        json = JSON.parse(response.body)
        expect(json["lineup"]).to eq([])
      end
    end
  end

  describe "POST /api/v1/games/:game_id/lineup" do
    include_context "authenticated user"

    let(:valid_params) do
      {
        lineup: [
          { player_card_id: player_card1.id, role: "starter", batting_order: 1, position: "P", is_dh_pitcher: false, is_reliever: false },
          { player_card_id: player_card2.id, role: "bench", is_dh_pitcher: false, is_reliever: false }
        ]
      }
    end

    it "201を返す" do
      post lineup_url, params: valid_params, as: :json
      expect(response).to have_http_status(:created)
    end

    it "lineupを作成する" do
      post lineup_url, params: valid_params, as: :json
      expect(GameLineupEntry.where(game: game).count).to eq(2)
    end

    it "レスポンスに lineup を含む" do
      post lineup_url, params: valid_params, as: :json
      json = JSON.parse(response.body)
      expect(json).to have_key("lineup")
      expect(json["lineup"].length).to eq(2)
    end

    context "バリデーションエラーの場合" do
      let(:invalid_params) do
        {
          lineup: [
            { player_card_id: player_card1.id, role: "starter", batting_order: nil, position: nil, is_dh_pitcher: false, is_reliever: false }
          ]
        }
      end

      it "422を返す" do
        post lineup_url, params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "errors キーを含む" do
        post lineup_url, params: invalid_params, as: :json
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end
  end

  describe "PUT /api/v1/games/:game_id/lineup" do
    include_context "authenticated user"

    before do
      create(:game_lineup_entry, game: game, player_card: player_card1, batting_order: 1, position: "P")
    end

    let(:player3) { create(:player, name: "咲夜") }
    let(:player_card3) { create(:player_card, player: player3) }

    let(:update_params) do
      {
        lineup: [
          { player_card_id: player_card3.id, role: "starter", batting_order: 1, position: "C", is_dh_pitcher: false, is_reliever: false }
        ]
      }
    end

    it "200を返す" do
      put lineup_url, params: update_params, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "既存エントリを全削除して新規作成する" do
      put lineup_url, params: update_params, as: :json
      entries = GameLineupEntry.where(game: game)
      expect(entries.count).to eq(1)
      expect(entries.first.player_card_id).to eq(player_card3.id)
    end

    it "レスポンスに lineup を含む" do
      put lineup_url, params: update_params, as: :json
      json = JSON.parse(response.body)
      expect(json).to have_key("lineup")
      expect(json["lineup"].first["player_name"]).to eq("咲夜")
    end
  end
end
