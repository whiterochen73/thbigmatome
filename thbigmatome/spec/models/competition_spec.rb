require 'rails_helper'

RSpec.describe Competition, type: :model do
  describe 'validations' do
    describe 'presence validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:competition_type) }
      it { is_expected.to validate_presence_of(:year) }
    end

    describe 'uniqueness validations' do
      subject { create(:competition) }
      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:year) }
    end

    describe 'inclusion validations' do
      it { is_expected.to validate_inclusion_of(:competition_type).in_array(Competition::COMPETITION_TYPES) }
    end

    describe 'numericality validations' do
      it { is_expected.to validate_numericality_of(:year).only_integer.is_greater_than(0) }
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:competition_entries).dependent(:destroy) }
    it { is_expected.to have_many(:teams).through(:competition_entries) }
    it { is_expected.to have_many(:games).dependent(:destroy) }
    it { is_expected.to have_many(:pitcher_game_states).dependent(:destroy) }
    it { is_expected.to have_many(:imported_stats).dependent(:destroy) }
  end

  describe 'constants' do
    it 'defines COMPETITION_TYPES' do
      expect(Competition::COMPETITION_TYPES).to eq(%w[league_pennant tournament])
    end
  end

  describe 'factory' do
    it 'creates a valid competition' do
      competition = build(:competition)
      expect(competition).to be_valid
    end

    it 'creates unique competitions with sequence' do
      comp1 = create(:competition)
      comp2 = create(:competition)
      expect(comp1.name).not_to eq(comp2.name)
    end
  end
end
