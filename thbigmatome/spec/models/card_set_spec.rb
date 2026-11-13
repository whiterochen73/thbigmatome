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

  describe "series の決まり方（PM という系列が版を重ねる）" do
    it "既存の set_type は従来どおり" do
      expect(CardSet.series_for("annual")).to eq("touhou")
      expect(CardSet.series_for("hachinai61")).to eq("hachinai")
      expect(CardSet.series_for("pm2026")).to eq("original")
      expect(CardSet.series_for("tamayomi2")).to eq("tamayomi")
    end

    it "pm + 4 桁の年なら original（PM2027・PM2028 …）。対応表の追加は要らない" do
      expect(CardSet.series_for("pm2027")).to eq("original")
      expect(CardSet.series_for("pm2028")).to eq("original")
    end

    it "知らない set_type は nil" do
      expect(CardSet.series_for("unknown")).to be_nil
      expect(CardSet.series_for("pm27")).to be_nil
    end

    it "series を渡さずに作ると set_type から入る（rake の取込でも series が入る）" do
      cs = CardSet.create!(year: 2027, name: "PM2027", set_type: "pm2027")
      expect(cs.series).to eq("original")
    end

    it "series を明示した場合はそれを使う" do
      cs = CardSet.create!(year: 2030, name: "x", set_type: "pm2030", series: "touhou")
      expect(cs.series).to eq("touhou")
    end
  end
end
