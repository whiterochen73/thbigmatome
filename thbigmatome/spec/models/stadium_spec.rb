require 'rails_helper'

RSpec.describe Stadium, type: :model do
  describe 'validations' do
    describe 'presence validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:code) }
    end

    describe 'uniqueness validations' do
      subject { create(:stadium) }
      it { is_expected.to validate_uniqueness_of(:name) }
      it { is_expected.to validate_uniqueness_of(:code) }
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:games).dependent(:restrict_with_error) }
  end

  describe 'factory' do
    it 'creates a valid stadium' do
      stadium = build(:stadium)
      expect(stadium).to be_valid
    end

    it 'creates unique stadiums with sequence' do
      stadium1 = create(:stadium)
      stadium2 = create(:stadium)
      expect(stadium1.name).not_to eq(stadium2.name)
      expect(stadium1.code).not_to eq(stadium2.code)
    end
  end
end
