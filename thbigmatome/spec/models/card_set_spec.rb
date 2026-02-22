require "rails_helper"

RSpec.describe CardSet, type: :model do
  let(:card_set) { create(:card_set, year: 2020, set_type: "annual") }

  describe "validations" do
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
end
