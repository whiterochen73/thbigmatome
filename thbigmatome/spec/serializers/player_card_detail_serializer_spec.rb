require 'rails_helper'

RSpec.describe PlayerCardDetailSerializer, type: :serializer do
  let(:player) { create(:player) }

  subject(:serialized) do
    serializer = described_class.new(player_card)
    JSON.parse(serializer.to_json)
  end

  context "when handedness is set on player_card" do
    let(:player_card) { create(:player_card, player: player, handedness: "right_throw/right_bat") }

    it "returns the stored handedness value" do
      expect(serialized["handedness"]).to eq("right_throw/right_bat")
    end
  end

  context "when handedness is nil on player_card" do
    let(:player_card) { create(:player_card, player: player, handedness: nil) }

    it "returns nil" do
      expect(serialized["handedness"]).to be_nil
    end
  end
end
