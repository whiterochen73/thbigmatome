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

  describe 'phase' do
    it { is_expected.to belong_to(:recorded_by_user).class_name('User').optional }

    it '既定は pre_game（試合前）' do
      expect(described_class.new.phase).to eq('pre_game')
      expect(create(:season_roster).reload.phase).to eq('pre_game')
    end

    %w[pre_game in_game post_game].each do |phase|
      it "#{phase} は有効" do
        expect(build(:season_roster, phase: phase)).to be_valid
      end
    end

    it '不正な区分はエラー（空文字・nil・未知の値）' do
      [ '', nil, 'midnight', 'POST_GAME' ].each do |value|
        roster = build(:season_roster, phase: value)
        expect(roster).not_to be_valid
        expect(roster.errors[:phase]).to be_present
      end
    end

    it 'DB の制約も不正な区分を弾く' do
      roster = build(:season_roster)
      roster.phase = 'midnight'
      expect { roster.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /season_rosters_phase_check/)
    end

    it '区分の順は pre_game < in_game < post_game' do
      expect(%w[post_game pre_game in_game].sort_by { |p| described_class.phase_rank(p) }).to eq(%w[pre_game in_game post_game])
      expect { described_class.phase_rank('midnight') }.to raise_error(ArgumentError)
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効' do
      expect(build(:season_roster)).to be_valid
    end
  end
end
