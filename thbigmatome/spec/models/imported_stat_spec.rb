require "rails_helper"

RSpec.describe ImportedStat, type: :model do
  let(:player) { create(:player) }
  let(:competition) { create(:competition) }
  let(:team) { create(:team) }

  describe "validations" do
    describe "presence validations" do
      it "validates presence of stat_type" do
        imported_stat = build(:imported_stat, stat_type: nil)
        expect(imported_stat).not_to be_valid
        expect(imported_stat.errors[:stat_type]).to include("can't be blank")
      end
    end

    describe "inclusion validations" do
      it "validates stat_type is either 'batting' or 'pitching'" do
        imported_stat = build(:imported_stat, stat_type: "invalid")
        expect(imported_stat).not_to be_valid
        expect(imported_stat.errors[:stat_type]).to include("is not included in the list")
      end

      it "allows 'batting' as stat_type" do
        imported_stat = build(:imported_stat, stat_type: "batting")
        imported_stat.validate
        expect(imported_stat.errors[:stat_type]).to be_empty
      end

      it "allows 'pitching' as stat_type" do
        imported_stat = build(:imported_stat, stat_type: "pitching")
        imported_stat.validate
        expect(imported_stat.errors[:stat_type]).to be_empty
      end
    end

    describe "uniqueness validations" do
      it "validates uniqueness of [player_id, competition_id, stat_type]" do
        existing = create(:imported_stat, player: player, competition: competition, stat_type: "batting")
        duplicate = build(:imported_stat, player: player, competition: competition, stat_type: "batting")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:player_id]).to include("has already been taken")
      end

      it "allows same player and competition with different stat_type" do
        existing = create(:imported_stat, player: player, competition: competition, stat_type: "batting")
        different_type = build(:imported_stat, player: player, competition: competition, stat_type: "pitching")

        expect(different_type).to be_valid
      end

      it "allows same player and stat_type with different competition" do
        existing = create(:imported_stat, player: player, competition: competition, stat_type: "batting")
        different_competition = create(:competition)
        different_comp = build(:imported_stat, player: player, competition: different_competition, stat_type: "batting")

        expect(different_comp).to be_valid
      end

      it "allows same competition and stat_type with different player" do
        existing = create(:imported_stat, player: player, competition: competition, stat_type: "batting")
        different_player = create(:player)
        different_plyr = build(:imported_stat, player: different_player, competition: competition, stat_type: "batting")

        expect(different_plyr).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to player" do
      association = ImportedStat.reflect_on_association(:player)
      expect(association.macro).to eq :belongs_to
    end

    it "belongs to competition" do
      association = ImportedStat.reflect_on_association(:competition)
      expect(association.macro).to eq :belongs_to
    end

    it "belongs to team" do
      association = ImportedStat.reflect_on_association(:team)
      expect(association.macro).to eq :belongs_to
    end
  end

  describe "constants" do
    it "defines STAT_TYPES constant" do
      expect(ImportedStat::STAT_TYPES).to eq(%w[batting pitching])
    end
  end
end
