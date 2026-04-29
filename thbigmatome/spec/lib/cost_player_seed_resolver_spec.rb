require "rails_helper"

RSpec.describe CostPlayerSeedResolver do
  before do
    described_class.clear_cache!
  end

  after do
    described_class.clear_cache!
  end

  describe ".resolve" do
    it "resolves a variant seed row to the base player and variant player card" do
      base_player = create(:player, name: "初瀬 麻里安")
      create(:player, name: "初瀬 麻里安 (湘南)")
      card_set = create(:card_set, name: "PM2026", set_type: "pm2026")
      player_card = create(:player_card, player: base_player, card_set: card_set, variant: "湘南")

      resolution = described_class.resolve("初瀬　麻里安（湘南）")

      expect(resolution.player).to eq(base_player)
      expect(resolution.player_card).to eq(player_card)
    end

    it "keeps exact variant players when cards use suffix names without variant metadata" do
      create(:player, name: "川崎 稜")
      exact_player = create(:player, name: "川崎 稜 (1年)")
      create(:player_card, player: exact_player, variant: nil)

      resolution = described_class.resolve("川崎　稜（１年）")

      expect(resolution.player).to eq(exact_player)
      expect(resolution.player_card).to be_nil
    end
  end

  describe ".assign!" do
    it "creates cost players with player_card_id for variant rows" do
      cost = create(:cost)
      base_player = create(:player, name: "初瀬 麻里安")
      player_card = create(:player_card, player: base_player, variant: "町田")
      row = {
        "player_name" => "初瀬　麻里安（町田）",
        "normal_cost" => "8",
        "relief_only_cost" => nil,
        "pitcher_only_cost" => nil,
        "fielder_only_cost" => nil,
        "two_way_cost" => nil,
        "cost_exempt" => "false"
      }

      cost_player = described_class.assign!(cost, row)

      expect(cost_player.player).to eq(base_player)
      expect(cost_player.player_card).to eq(player_card)
      expect(cost_player.normal_cost).to eq(8)
    end
  end
end
