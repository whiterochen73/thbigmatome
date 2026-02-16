require 'rails_helper'

RSpec.describe TeamMembership, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:player) }
    it { is_expected.to have_many(:season_rosters) }
    it { is_expected.to have_many(:player_absences).dependent(:restrict_with_error) }
  end

  describe 'バリデーション' do
    describe 'squad' do
      it 'firstは有効' do
        membership = build(:team_membership, squad: 'first')
        expect(membership).to be_valid
      end

      it 'secondは有効' do
        membership = build(:team_membership, squad: 'second')
        expect(membership).to be_valid
      end

      it '無効な値はエラー' do
        membership = build(:team_membership, squad: 'third')
        expect(membership).not_to be_valid
        expect(membership.errors[:squad]).to be_present
      end

      it '空文字はエラー' do
        membership = build(:team_membership, squad: '')
        expect(membership).not_to be_valid
        expect(membership.errors[:squad]).to be_present
      end
    end

    describe 'selected_cost_type' do
      %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost].each do |cost_type|
        it "#{cost_type}は有効" do
          membership = build(:team_membership, selected_cost_type: cost_type)
          expect(membership).to be_valid
        end
      end

      it '無効な値はエラー' do
        membership = build(:team_membership, selected_cost_type: 'invalid_cost')
        expect(membership).not_to be_valid
        expect(membership.errors[:selected_cost_type]).to be_present
      end

      it '空文字はエラー（presence）' do
        membership = build(:team_membership, selected_cost_type: '')
        expect(membership).not_to be_valid
        expect(membership.errors[:selected_cost_type]).to be_present
      end

      it 'nilはエラー（presence）' do
        membership = build(:team_membership, selected_cost_type: nil)
        expect(membership).not_to be_valid
        expect(membership.errors[:selected_cost_type]).to be_present
      end
    end

    describe 'team_idとplayer_idの一意制約（DB層）' do
      it '同じチーム・同じ選手の重複登録はDBエラー' do
        team = create(:team)
        player = create(:player)
        create(:team_membership, team: team, player: player)

        duplicate = build(:team_membership, team: team, player: player)
        expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it '同じ選手でも別チームなら有効' do
        player = create(:player)
        create(:team_membership, team: create(:team), player: player)

        different_team = build(:team_membership, team: create(:team), player: player)
        expect(different_team).to be_valid
      end
    end
  end

  describe 'スコープ' do
    let!(:team) { create(:team) }
    let!(:included_membership) { create(:team_membership, team: team, excluded_from_team_total: false) }
    let!(:excluded_membership) { create(:team_membership, :excluded, team: team) }

    describe '.included_in_team_total' do
      it 'excluded_from_team_total=falseのレコードのみ返す' do
        result = TeamMembership.included_in_team_total
        expect(result).to include(included_membership)
        expect(result).not_to include(excluded_membership)
      end
    end

    describe '.excluded_from_team_total' do
      it 'excluded_from_team_total=trueのレコードのみ返す' do
        result = TeamMembership.excluded_from_team_total
        expect(result).to include(excluded_membership)
        expect(result).not_to include(included_membership)
      end
    end
  end

  describe 'デフォルト値' do
    it 'squadのデフォルトはsecond' do
      membership = TeamMembership.new
      expect(membership.squad).to eq('second')
    end

    it 'selected_cost_typeのデフォルトはnormal_cost' do
      membership = TeamMembership.new
      expect(membership.selected_cost_type).to eq('normal_cost')
    end

    it 'excluded_from_team_totalのデフォルトはfalse' do
      membership = TeamMembership.new
      expect(membership.excluded_from_team_total).to be false
    end
  end
end
