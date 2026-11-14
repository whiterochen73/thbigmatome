require "rails_helper"

# 版違いのカードが同じコストに見えていた（一覧の「コスト」欄・カード詳細のコスト表）。cmd_1902。
# Test Basis: Operator 2026-11-14 /players/142（八雲 紫）。カード別のコスト行（cost_players.player_card_id）がある時は、そのカードの値を出す。
RSpec.describe "カードごとのコスト表示", type: :request do
  include_context "authenticated user"

  let(:player) { create(:player) }
  let(:set) { create(:card_set, name: "PM2027") }
  let!(:old_cost) { create(:cost, name: "旧改定", start_date: Date.new(2024, 12, 14), end_date: Date.new(2025, 12, 27)) }
  let!(:cost) { create(:cost, name: "新改定", start_date: Date.new(2025, 12, 28), end_date: nil) }
  let!(:plain) { create(:player_card, player: player, card_set: set, variant: nil) }
  let!(:hanno) { create(:player_card, player: player, card_set: set, variant: "飯能") }
  let!(:tsukushino) { create(:player_card, player: player, card_set: set, variant: "筑紫野") }

  before do
    create(:cost_player, cost: old_cost, player: player, player_card_id: nil, normal_cost: 6)
    create(:cost_player, cost: cost, player: player, player_card_id: nil, normal_cost: 6)
    create(:cost_player, cost: cost, player: player, player_card_id: hanno.id, normal_cost: 5)
    # 筑紫野のカードは新しい改定でカード別の行が無い → 選手の既定
  end

  def cost_by_id
    get "/api/v1/player_cards", params: { player_id: player.id }
    response.parsed_body["player_cards"].to_h { |c| [ c["id"], c["cost"] ] }
  end

  it "一覧の cost は、そのカードの行があればそれ・無ければ選手の既定（他のカードの行を拾わない）" do
    expect(cost_by_id).to eq(plain.id => 6, hanno.id => 5, tsukushino.id => 6)
  end

  it "最新の改定に選手の既定が無く、他のカードの行だけなら nil（他のカードの値を出さない）" do
    CostPlayer.where(cost: cost, player_card_id: nil).delete_all
    expect(cost_by_id).to eq(plain.id => nil, hanno.id => 5, tsukushino.id => nil)
  end

  it "カード詳細の cost・costs は、そのカードに効く行だけ（改定ごとに 1 行・他のカードの行は出ない）" do
    get "/api/v1/player_cards/#{hanno.id}", as: :json
    json = response.parsed_body
    expect(json["cost"]).to eq(5)
    expect(json["costs"].map { |c| [ c["cost_name"], c["player_card_id"], c["normal_cost"] ] }).to eq(
      [ [ "新改定", hanno.id, 5 ], [ "旧改定", nil, 6 ] ]
    )

    get "/api/v1/player_cards/#{tsukushino.id}", as: :json
    expect(response.parsed_body["costs"].map { |c| [ c["player_card_id"], c["normal_cost"] ] }).to eq([ [ nil, 6 ], [ nil, 6 ] ])
  end
end
