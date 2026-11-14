require 'rails_helper'

RSpec.describe PlayerCardSerializer, type: :serializer do
  let(:player) { create(:player) }
  let(:player_card) { create(:player_card, player: player, variant: "湘南") }

  subject(:serialized) do
    serializer = described_class.new(player_card)
    JSON.parse(serializer.to_json)
  end

  it "includes variant" do
    expect(serialized["variant"]).to eq("湘南")
  end

  describe "version_label / team_label（cmd_1901）" do
    it "variant があれば version_label は variant（team_label は別に返す）" do
      player_card.update!(team_label: "東方PROJECT")
      expect(serialized).to include("version_label" => "湘南", "team_label" => "東方PROJECT")
    end

    it "variant が無ければ version_label は帯の team_label" do
      player_card.update!(variant: nil, team_label: "永山")
      expect(serialized).to include("version_label" => "永山", "team_label" => "永山", "variant" => nil)
    end

    it "どちらも無ければ version_label は nil" do
      player_card.update!(variant: nil, team_label: nil)
      expect(serialized["version_label"]).to be_nil
    end
  end

  describe "#image_url" do
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
