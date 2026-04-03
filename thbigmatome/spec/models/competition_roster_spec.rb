require 'rails_helper'

RSpec.describe CompetitionRoster, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:competition_entry) }
    it { is_expected.to belong_to(:player_card) }
  end

  describe 'validations' do
    describe 'squad presence' do
      it 'is invalid without squad' do
        roster = build(:competition_roster, squad: nil)
        expect(roster).not_to be_valid
        expect(roster.errors[:squad]).to be_present
      end
    end

    describe 'uniqueness of player_card per competition_entry' do
      it 'is invalid when the same player_card is added twice to the same entry' do
        existing = create(:competition_roster)
        duplicate = build(:competition_roster,
          competition_entry: existing.competition_entry,
          player_card: existing.player_card
        )
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:competition_entry_id]).to be_present
      end

      it 'allows the same player_card in different competition entries' do
        roster1 = create(:competition_roster)
        roster2 = build(:competition_roster, player_card: roster1.player_card)
        expect(roster2).to be_valid
      end
    end
  end

  describe 'enum squad' do
    it 'has first_squad and second_squad values' do
      expect(CompetitionRoster.squads).to eq({ "first_squad" => 0, "second_squad" => 1 })
    end

    it 'defaults to first_squad from factory' do
      roster = create(:competition_roster)
      expect(roster.first_squad?).to be true
    end
  end

  describe 'factory' do
    it 'creates a valid competition_roster' do
      roster = build(:competition_roster)
      expect(roster).to be_valid
    end
  end
end
