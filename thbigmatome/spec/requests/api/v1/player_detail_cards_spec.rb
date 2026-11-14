require "rails_helper"

# 選手詳細（GET /api/v1/players/:id）の「カード一覧」と「コスト表」が、どのカード（版）のものか分かるようにする（cmd_1902）。
# 実画面の不具合: カードセット列が全行「—」（AMS の既定の深さで belongs_to :card_set が落ちていた）、
# コスト表の行が「2025年12月コスト改定」だけで、どのカードの値か分からなかった。
# Test Basis: Operator 2026-11-14「選手一覧、本当にうまく表示できてる？」（/players/142 八雲 紫 のスクリーンショット）
RSpec.describe "選手詳細のカード一覧・コスト表", type: :request do
  include_context "authenticated user"

  let(:player) { create(:player, name: "八雲 紫") }
  let(:pm2026) { create(:card_set, name: "PM2026", is_current: false) }
  let(:pm2027) { create(:card_set, name: "PM2027", is_current: true) }

  def attach_image(card)
    card.card_image.attach(io: StringIO.new("png"), filename: "c.png", content_type: "image/png")
  end

  def fetch(id = player.id)
    get "/api/v1/players/#{id}", as: :json
    response.parsed_body
  end

  describe "player_cards" do
    it "カードが 1 枚（版の印なし・画像なし）でもセット名が出て、版は null・画像は null" do
      create(:player_card, player: player, card_set: pm2027, variant: nil, team_label: nil)

      json = fetch
      card = json["player_cards"].sole
      expect(card["card_set"]).to include("name" => "PM2027")
      expect(card["card_set_name"]).to eq("PM2027")
      expect(card["version_label"]).to be_nil
      expect(card["image_url"]).to be_nil
    end

    it "複数枚（同じセットに版違い 3 枚・旧セット 1 枚）は現行セットが先で、セット名・版の印・画像が行ごとに出る" do
      old = create(:player_card, player: player, card_set: pm2026, variant: "筑紫野")
      april = create(:player_card, player: player, card_set: pm2027, variant: "エイプリル", card_type: "batter")
      hanno = create(:player_card, player: player, card_set: pm2027, variant: "飯能")
      band = create(:player_card, player: player, card_set: pm2027, variant: nil, team_label: "下館")
      attach_image(hanno)

      cards = fetch["player_cards"]
      expect(cards.map { |c| c["id"] }).to eq([ april.id, hanno.id, band.id, old.id ])
      expect(cards.map { |c| c["card_set_name"] }).to eq(%w[PM2027 PM2027 PM2027 PM2026])
      expect(cards.map { |c| c["version_label"] }).to eq([ "エイプリル", "飯能", "下館", "筑紫野" ])
      expect(cards.map { |c| c["card_set_current"] }).to eq([ true, true, true, false ])
      expect(cards.map { |c| c["image_url"].present? }).to eq([ false, true, false, false ])
    end

    it "一覧（GET /api/v1/players）の各選手にも同じ項目が入る" do
      create(:player_card, player: player, card_set: pm2027, variant: "飯能")

      get "/api/v1/players", as: :json
      card = response.parsed_body.find { |p| p["id"] == player.id }["player_cards"].sole
      expect(card).to include("card_set_name" => "PM2027", "version_label" => "飯能")
    end
  end

  describe "costs" do
    let!(:cost2024) { create(:cost, name: "2024年12月コスト改定", start_date: Date.new(2024, 12, 14), end_date: Date.new(2025, 12, 27)) }
    let!(:cost2025) { create(:cost, name: "2025年12月コスト改定", start_date: Date.new(2025, 12, 28), end_date: nil) }
    let!(:card_a) { create(:player_card, player: player, card_set: pm2027, variant: "飯能") }
    let!(:card_b) { create(:player_card, player: player, card_set: pm2026, variant: "筑紫野") }

    it "新しい改定が上・各改定の中は『選手の既定』が先でカードの行が続き、カードの行にはセット名・版の印が付く" do
      create(:cost_player, cost: cost2024, player: player, player_card_id: nil, normal_cost: 6)
      create(:cost_player, cost: cost2025, player: player, player_card_id: card_b.id, normal_cost: 10)
      create(:cost_player, cost: cost2025, player: player, player_card_id: nil, normal_cost: 6)
      create(:cost_player, cost: cost2025, player: player, player_card_id: card_a.id, normal_cost: 5)

      costs = fetch["costs"]
      expect(costs.map { |c| [ c["cost_name"], c["player_card_id"], c["normal_cost"] ] }).to eq(
        [
          [ "2025年12月コスト改定", nil, 6 ],
          [ "2025年12月コスト改定", card_a.id, 5 ],
          [ "2025年12月コスト改定", card_b.id, 10 ],
          [ "2024年12月コスト改定", nil, 6 ]
        ]
      )
      default_row, hanno_row = costs.first(2)
      expect(default_row).to include("card_set_name" => nil, "version_label" => nil, "is_current" => true)
      expect(hanno_row).to include("card_set_name" => "PM2027", "version_label" => "飯能")
      expect(costs.last["is_current"]).to be(false)
    end

    it "選手の既定の行が無く、カードの行だけの改定もそのまま出る" do
      create(:cost_player, cost: cost2025, player: player, player_card_id: card_a.id, normal_cost: 5)

      costs = fetch["costs"]
      expect(costs.sole).to include("player_card_id" => card_a.id, "normal_cost" => 5)
    end

    it "コストが無い選手は空配列" do
      expect(fetch["costs"]).to eq([])
    end

    it "存在しないカードを指す行（孤児）でも落ちず、既定扱いにしない（card 項目は null・player_card_id は残す）" do
      row = create(:cost_player, cost: cost2025, player: player, player_card_id: nil, normal_cost: 6)
      other_card = create(:player_card, card_set: pm2027) # 別の選手のカード
      row.update_columns(player_card_id: other_card.id)

      costs = fetch["costs"]
      expect(costs.sole).to include("player_card_id" => other_card.id, "card_set_name" => nil)
    end
  end
end
