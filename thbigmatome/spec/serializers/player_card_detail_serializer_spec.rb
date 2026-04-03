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

  describe "#image_url" do
    let(:player_card) { create(:player_card, player: player) }

    context "when card_image is not attached" do
      it "returns nil" do
        allow(player_card.card_image).to receive(:attached?).and_return(false)
        expect(serialized["image_url"]).to be_nil
      end
    end

    context "when card_image is attached" do
      before do
        allow(player_card.card_image).to receive(:attached?).and_return(true)
        allow(Rails.application.routes.url_helpers).to receive(:rails_blob_url) do |_blob, options|
          "http://#{options[:host]}/rails/active_storage/blobs/fake"
        end
      end

      context "when APP_HOST is set" do
        before { allow(ENV).to receive(:fetch).with("APP_HOST", "localhost:3000").and_return("dugout.thbig.fun") }

        it "uses APP_HOST as the host" do
          expect(serialized["image_url"]).to include("dugout.thbig.fun")
        end
      end

      context "when APP_HOST is not set" do
        before { allow(ENV).to receive(:fetch).with("APP_HOST", "localhost:3000").and_return("localhost:3000") }

        it "falls back to localhost:3000" do
          expect(serialized["image_url"]).to include("localhost:3000")
        end
      end
    end
  end
end
