require 'rails_helper'

RSpec.describe PlayerCardDetailSerializer, type: :serializer do
  let(:player) do
    create(:player, throwing_hand: :right_throw, batting_hand: :right_bat)
  end

  subject(:serialized) do
    serializer = described_class.new(player_card)
    JSON.parse(serializer.to_json)
  end

  context "when handedness is nil on player_card" do
    let(:player_card) { create(:player_card, player: player, handedness: nil) }

    it "returns fallback from player throwing_hand/batting_hand" do
      expect(serialized["handedness"]).to eq("right_throw/right_bat")
    end

    context "when player has switch_hitter batting hand" do
      let(:player) { create(:player, throwing_hand: :left_throw, batting_hand: :switch_hitter) }

      it "returns fallback with switch_hitter" do
        expect(serialized["handedness"]).to eq("left_throw/switch_hitter")
      end
    end
  end

  context "when handedness is set on player_card" do
    let(:player_card) { create(:player_card, player: player, handedness: "right/right") }

    it "returns the stored handedness value" do
      expect(serialized["handedness"]).to eq("right/right")
    end
  end
end
