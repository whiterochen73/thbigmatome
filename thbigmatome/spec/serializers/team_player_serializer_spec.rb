require "rails_helper"

RSpec.describe TeamPlayerSerializer, type: :serializer do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }
  let(:hachinai_card_set) { create(:card_set, set_type: "hachinai61", series: "hachinai", name: "ハチナイ6.1") }
  let(:pm_card_set) { create(:card_set, set_type: "pm2026", series: "original", name: "PM2026") }
  let(:player) { create(:player, number: "34", series: "hachinai") }
  let!(:base_card) { create(:player_card, player: player, card_set: hachinai_card_set, card_type: "batter", is_pitcher: false) }
  let!(:variant_card) { create(:player_card, player: player, card_set: pm_card_set, card_type: "batter", is_pitcher: false) }

  subject(:serialized) do
    serializer = described_class.new(player, team: team, cost_list_id: cost.id)
    JSON.parse(serializer.to_json)
  end

  before do
    variant_card.player_card_defenses.create!(position: "1B", range_value: 5, error_rank: "C")
    create(:team_membership, team: team, player: player, player_card: variant_card, selected_cost_type: "fielder_only_cost")
    create(:cost_player, cost: cost, player: player, player_card_id: nil, fielder_only_cost: 4, pitcher_only_cost: 1, two_way_cost: 5)
    create(:cost_player, cost: cost, player: player, player_card_id: variant_card.id)
  end

  it "variant rowが空でもcurrent_costはbase rowへフォールバックする" do
    expect(serialized["current_cost"]).to eq(4)
  end
end
