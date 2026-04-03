require "rails_helper"

RSpec.describe CardSet, type: :model do
  let(:card_set) { create(:card_set, year: 2020, set_type: "annual") }

  describe "validations" do
    describe "presence validations" do
      it "validates presence of year" do
        card_set = build(:card_set, year: nil)
        expect(card_set).not_to be_valid
        expect(card_set.errors[:year]).to include("can't be blank")
      end

      it "validates presence of name" do
        card_set = build(:card_set, name: nil)
        expect(card_set).not_to be_valid
        expect(card_set.errors[:name]).to include("can't be blank")
      end

      it "validates presence of set_type" do
        card_set = build(:card_set, set_type: nil)
        expect(card_set).not_to be_valid
        expect(card_set.errors[:set_type]).to include("can't be blank")
      end
    end

    describe "numericality validations" do
      it "validates year is integer" do
        card_set = build(:card_set, year: 2020.5)
        expect(card_set).not_to be_valid
        expect(card_set.errors[:year]).to include("must be an integer")
      end
    end

    describe "uniqueness of [year, set_type]" do
      it "allows creating a card set with same year and set_type as first one to fail" do
        card_set
        duplicate = build(:card_set, year: 2020, set_type: "annual")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:year]).to include("has already been taken")
      end

      it "allows creating a card set with different year but same set_type" do
        card_set
        new_card_set = build(:card_set, year: 2021, set_type: "annual")

        expect(new_card_set).to be_valid
      end

      it "allows creating a card set with same year but different set_type" do
        card_set
        new_card_set = build(:card_set, year: 2020, set_type: "special")

        expect(new_card_set).to be_valid
      end
    end
  end

  describe "associations" do
    it "has many player_cards with dependent destroy" do
      association = CardSet.reflect_on_association(:player_cards)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end
  end
end
