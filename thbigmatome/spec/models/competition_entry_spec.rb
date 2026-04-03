require 'rails_helper'

RSpec.describe CompetitionEntry, type: :model do
  describe 'validations' do
    describe 'uniqueness validations' do
      subject { create(:competition_entry) }
      it { is_expected.to validate_uniqueness_of(:competition_id).scoped_to(:team_id) }
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:base_team).class_name('Team').optional(true) }
  end

  describe 'factory' do
    it 'creates a valid competition_entry' do
      competition_entry = build(:competition_entry)
      expect(competition_entry).to be_valid
    end
  end
end
