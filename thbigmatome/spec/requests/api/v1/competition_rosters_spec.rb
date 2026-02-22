require 'rails_helper'

RSpec.describe "Api::V1::CompetitionRosters", type: :request do
  let(:cost) { create(:cost) }
  let(:competition) { create(:competition) }
  let(:team) { create(:team) }
  let(:entry) { create(:competition_entry, competition: competition, team: team) }

  def create_player_card_with_cost(normal_cost: 5, is_pitcher: false, is_relief_only: false)
    player = create(:player)
    create(:cost_player, cost: cost, player: player, normal_cost: normal_cost)
    create(:player_card, player: player, is_pitcher: is_pitcher, is_relief_only: is_relief_only)
  end

  def roster_url(suffix = "")
    "/api/v1/competitions/#{competition.id}/roster#{suffix}?team_id=#{team.id}"
  end

  describe "認証なしアクセス" do
    let!(:entry) { create(:competition_entry, competition: competition, team: team) }

    it "GET /roster → 401" do
      get roster_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /roster/players → 401" do
      post roster_url("/players"), params: { player_card_id: 1, squad: "first_squad" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "DELETE /roster/players/:id → 401" do
      delete roster_url("/players/1"), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "GET /roster/cost_check → 401" do
      get roster_url("/cost_check")
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/competitions/:id/roster" do
    include_context "authenticated user"

    context "エントリーが存在する場合" do
      let!(:first_card) do
        pc = create_player_card_with_cost(normal_cost: 5)
        create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        pc
      end
      let!(:second_card) do
        pc = create_player_card_with_cost(normal_cost: 4)
        create(:competition_roster, competition_entry: entry, player_card: pc, squad: :second_squad)
        pc
      end

      it "200を返し first_squad/second_squad 構造を持つ" do
        get roster_url
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key("first_squad")
        expect(json).to have_key("second_squad")
        expect(json["first_squad"].length).to eq(1)
        expect(json["second_squad"].length).to eq(1)
      end

      it "各選手に player_card_id, player_name, squad, is_reliever, cost が含まれる" do
        get roster_url
        json = JSON.parse(response.body)
        player = json["first_squad"].first
        expect(player).to have_key("player_card_id")
        expect(player).to have_key("player_name")
        expect(player).to have_key("squad")
        expect(player).to have_key("is_reliever")
        expect(player).to have_key("cost")
      end
    end

    context "エントリーが存在しない場合" do
      it "404を返す" do
        other_team = create(:team)
        get "/api/v1/competitions/#{competition.id}/roster?team_id=#{other_team.id}"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/competitions/:id/roster/players" do
    include_context "authenticated user"

    context "コスト超過の場合" do
      before do
        # 25人 × 5 = 125 > 上限114
        25.times do
          pc = create_player_card_with_cost(normal_cost: 5)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it "422を返す" do
        new_card = create_player_card_with_cost(normal_cost: 5)
        post roster_url("/players"),
          params: { player_card_id: new_card.id, squad: "first_squad" },
          as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "正常な追加の場合" do
      before do
        # 25人 × 4 = 100 < 114（上限以内）
        25.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it "201を返す" do
        new_card = create_player_card_with_cost(normal_cost: 2)
        post roster_url("/players"),
          params: { player_card_id: new_card.id, squad: "first_squad" },
          as: :json
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "DELETE /api/v1/competitions/:id/roster/players/:player_card_id" do
    include_context "authenticated user"

    let!(:player_card) { create_player_card_with_cost }
    let!(:roster) { create(:competition_roster, competition_entry: entry, player_card: player_card) }

    it "204を返し選手を削除する" do
      delete roster_url("/players/#{player_card.id}"), as: :json
      expect(response).to have_http_status(:no_content)
      expect(CompetitionRoster.find_by(id: roster.id)).to be_nil
    end
  end

  describe "GET /api/v1/competitions/:id/roster/cost_check" do
    include_context "authenticated user"

    before do
      25.times do
        pc = create_player_card_with_cost(normal_cost: 4)
        create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
      end
    end

    it "200を返しvalidate結果を含む" do
      get roster_url("/cost_check")
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("valid")
      expect(json).to have_key("errors")
      expect(json).to have_key("current_total_cost")
      expect(json).to have_key("total_limit")
      expect(json).to have_key("first_squad_cost")
      expect(json).to have_key("first_squad_limit")
      expect(json).to have_key("first_squad_count")
    end
  end
end
