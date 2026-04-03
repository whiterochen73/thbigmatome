require "rails_helper"

RSpec.describe PlayerCardPlayerType, type: :model do
  let(:player_card) { create(:player_card) }
  let(:player_type) { create(:player_type) }

  describe "validations" do
    describe "uniqueness validations" do
      it "validates uniqueness of [player_card_id, player_type_id]" do
        existing = create(:player_card_player_type, player_card: player_card, player_type: player_type)
        duplicate = build(:player_card_player_type, player_card: player_card, player_type: player_type)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:player_card_id]).to include("has already been taken")
      end

      it "allows same player_type with different player_card" do
        existing = create(:player_card_player_type, player_card: player_card, player_type: player_type)
        different_card = create(:player_card)
        new_association = build(:player_card_player_type, player_card: different_card, player_type: player_type)

        expect(new_association).to be_valid
      end

      it "allows same player_card with different player_type" do
        existing = create(:player_card_player_type, player_card: player_card, player_type: player_type)
        different_type = create(:player_type)
        new_association = build(:player_card_player_type, player_card: player_card, player_type: different_type)

        expect(new_association).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to player_card" do
      association = PlayerCardPlayerType.reflect_on_association(:player_card)
      expect(association.macro).to eq :belongs_to
    end

    it "belongs to player_type" do
      association = PlayerCardPlayerType.reflect_on_association(:player_type)
      expect(association.macro).to eq :belongs_to
    end
  end
end
