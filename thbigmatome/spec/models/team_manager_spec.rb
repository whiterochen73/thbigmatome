require 'rails_helper'

RSpec.describe TeamManager, type: :model do
  describe 'バリデーション' do
    describe 'director_team_limit' do
      let(:manager) { create(:manager) }

      it 'directorが1チームなら有効' do
        create(:team_manager, manager: manager, role: :director)
        new_team = create(:team)
        new_tm = build(:team_manager, manager: manager, team: new_team, role: :director)
        expect(new_tm).to be_valid
      end

      it 'directorが2チームまでなら有効' do
        create(:team_manager, manager: manager, role: :director)
        create(:team_manager, manager: manager, team: create(:team), role: :director)
        new_team = create(:team)
        new_tm = build(:team_manager, manager: manager, team: new_team, role: :director)
        expect(new_tm).not_to be_valid
        expect(new_tm.errors[:manager_id]).to be_present
      end

      it 'directorが3チーム目を作ろうとした場合に失敗' do
        create(:team_manager, manager: manager, role: :director)
        create(:team_manager, manager: manager, team: create(:team), role: :director)
        third_team = create(:team)
        third_tm = build(:team_manager, manager: manager, team: third_team, role: :director)
        expect(third_tm).not_to be_valid
        expect(third_tm.errors[:manager_id]).to be_present
      end

      it 'is_active: false のチームは制約にカウントされない' do
        inactive_team = create(:team, is_active: false)
        create(:team_manager, manager: manager, team: inactive_team, role: :director)
        create(:team_manager, manager: manager, team: create(:team), role: :director)
        # 非アクティブ1チーム + アクティブ1チーム → 新チーム作成可能
        new_team = create(:team)
        new_tm = build(:team_manager, manager: manager, team: new_team, role: :director)
        expect(new_tm).to be_valid
      end

      it 'coachロールは制約を受けない' do
        create(:team_manager, manager: manager, role: :director)
        create(:team_manager, manager: manager, team: create(:team), role: :director)
        # coachとして3チーム目は問題なし
        third_team = create(:team)
        coach_tm = build(:team_manager, manager: manager, team: third_team, role: :coach)
        expect(coach_tm).to be_valid
      end
    end
  end
end
