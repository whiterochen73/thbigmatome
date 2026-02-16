require 'rails_helper'

RSpec.describe SeasonRoster, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to belong_to(:season) }
    it { is_expected.to belong_to(:team_membership) }
  end

  describe 'バリデーション' do
    describe 'squad' do
      it { is_expected.to validate_presence_of(:squad) }

      it '値が設定されていれば有効' do
        roster = build(:season_roster, squad: 'first')
        expect(roster).to be_valid
      end

      it 'nilはエラー' do
        roster = build(:season_roster, squad: nil)
        expect(roster).not_to be_valid
        expect(roster.errors[:squad]).to be_present
      end

      it '空文字はエラー' do
        roster = build(:season_roster, squad: '')
        expect(roster).not_to be_valid
        expect(roster.errors[:squad]).to be_present
      end
    end

    describe 'registered_on' do
      it { is_expected.to validate_presence_of(:registered_on) }

      it '日付が設定されていれば有効' do
        roster = build(:season_roster, registered_on: Date.current)
        expect(roster).to be_valid
      end

      it 'nilはエラー' do
        roster = build(:season_roster, registered_on: nil)
        expect(roster).not_to be_valid
        expect(roster.errors[:registered_on]).to be_present
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効' do
      expect(build(:season_roster)).to be_valid
    end
  end
end
