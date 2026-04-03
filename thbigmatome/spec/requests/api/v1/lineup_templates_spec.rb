require "rails_helper"

RSpec.describe "Api::V1::LineupTemplates", type: :request do
  let(:team) { create(:team) }
  let(:player1) { create(:player, name: "霊夢", number: "1") }
  let(:player2) { create(:player, name: "魔理沙", number: "2") }

  def templates_url
    "/api/v1/teams/#{team.id}/lineup_templates"
  end

  def template_url(id)
    "/api/v1/teams/#{team.id}/lineup_templates/#{id}"
  end

  describe "認証なしアクセス" do
    it "GET /lineup_templates → 401" do
      get templates_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "POST /lineup_templates → 401" do
      post templates_url, params: { lineup_template: { dh_enabled: true, opponent_pitcher_hand: "right" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/teams/:team_id/lineup_templates" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    context "テンプレートが存在する場合" do
      let!(:template) do
        t = create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
        create(:lineup_template_entry, lineup_template: t, player: player1, batting_order: 1, position: "RF")
        create(:lineup_template_entry, lineup_template: t, player: player2, batting_order: 2, position: "3B")
        t
      end

      it "200を返す" do
        get templates_url
        expect(response).to have_http_status(:ok)
      end

      it "テンプレート一覧を返す" do
        get templates_url
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json[0]["id"]).to eq(template.id)
        expect(json[0]["dh_enabled"]).to eq(true)
        expect(json[0]["opponent_pitcher_hand"]).to eq("right")
      end

      it "entries に player_name, player_number が含まれる" do
        get templates_url
        json = JSON.parse(response.body)
        entries = json[0]["entries"]
        expect(entries.length).to eq(2)
        expect(entries[0]["player_name"]).to eq("霊夢")
        expect(entries[0]["player_number"]).to eq("1")
        expect(entries[0]["batting_order"]).to eq(1)
        expect(entries[0]["position"]).to eq("RF")
      end
    end

    context "テンプレートが存在しない場合" do
      it "空配列を返す" do
        get templates_url
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end
  end

  describe "GET /api/v1/teams/:team_id/lineup_templates/:id" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    let!(:template) do
      t = create(:lineup_template, team: team)
      create(:lineup_template_entry, lineup_template: t, player: player1, batting_order: 1, position: "C")
      t
    end

    it "200を返す" do
      get template_url(template.id)
      expect(response).to have_http_status(:ok)
    end

    it "テンプレート詳細を返す" do
      get template_url(template.id)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(template.id)
      expect(json["entries"].length).to eq(1)
    end

    it "存在しないIDは404" do
      get template_url(9999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/teams/:team_id/lineup_templates" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    let(:valid_params) do
      {
        lineup_template: {
          dh_enabled: true,
          opponent_pitcher_hand: "right",
          entries_attributes: [
            { batting_order: 1, player_id: player1.id, position: "RF" },
            { batting_order: 2, player_id: player2.id, position: "3B" }
          ]
        }
      }
    end

    it "201を返す" do
      post templates_url, params: valid_params, as: :json
      expect(response).to have_http_status(:created)
    end

    it "テンプレートが作成される" do
      expect {
        post templates_url, params: valid_params, as: :json
      }.to change(LineupTemplate, :count).by(1)
    end

    it "entriesも作成される" do
      expect {
        post templates_url, params: valid_params, as: :json
      }.to change(LineupTemplateEntry, :count).by(2)
    end

    it "重複パターンは422" do
      create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      post templates_url, params: valid_params, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PUT /api/v1/teams/:team_id/lineup_templates/:id" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    let!(:template) do
      t = create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      create(:lineup_template_entry, lineup_template: t, player: player1, batting_order: 1, position: "RF")
      t
    end

    let(:update_params) do
      {
        lineup_template: {
          entries_attributes: [
            { batting_order: 1, player_id: player2.id, position: "CF" },
            { batting_order: 2, player_id: player1.id, position: "RF" }
          ]
        }
      }
    end

    it "200を返す" do
      put template_url(template.id), params: update_params, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "entriesが全件洗い替えされる" do
      put template_url(template.id), params: update_params, as: :json
      json = JSON.parse(response.body)
      entries = json["entries"]
      expect(entries.length).to eq(2)
      expect(entries[0]["batting_order"]).to eq(1)
      expect(entries[0]["player_id"]).to eq(player2.id)
      expect(entries[0]["position"]).to eq("CF")
    end

    it "旧entriesが削除される" do
      old_entry_id = template.lineup_template_entries.first.id
      put template_url(template.id), params: update_params, as: :json
      expect(LineupTemplateEntry.exists?(old_entry_id)).to be false
    end

    it "entries_attributesなしの場合はentries変更なし" do
      put template_url(template.id), params: { lineup_template: {} }, as: :json
      expect(response).to have_http_status(:ok)
      expect(template.reload.lineup_template_entries.count).to eq(1)
    end
  end

  describe "DELETE /api/v1/teams/:team_id/lineup_templates/:id" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    let!(:template) { create(:lineup_template, team: team) }

    it "204を返す" do
      delete template_url(template.id)
      expect(response).to have_http_status(:no_content)
    end

    it "テンプレートが削除される" do
      expect {
        delete template_url(template.id)
      }.to change(LineupTemplate, :count).by(-1)
    end
  end
end
