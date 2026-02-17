require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    describe 'has_secure_password' do
      it 'パスワードなしでは作成できない' do
        user = build(:user, password: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present
      end

      it 'パスワードが設定されていれば有効' do
        user = build(:user, password: 'password123')
        expect(user).to be_valid
      end

      it 'authenticateメソッドが使える' do
        user = create(:user, password: 'password123')
        expect(user.authenticate('password123')).to eq(user)
        expect(user.authenticate('wrong_password')).to be false
      end
    end

    describe 'name' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_uniqueness_of(:name) }

      it '同じnameのユーザーは作成できない' do
        create(:user, name: 'duplicate_name')
        duplicate = build(:user, name: 'duplicate_name')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to be_present
      end

      it 'nilはエラー' do
        user = build(:user, name: nil)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to be_present
      end

      it '空文字はエラー' do
        user = build(:user, name: '')
        expect(user).not_to be_valid
        expect(user.errors[:name]).to be_present
      end
    end

    describe 'display_name' do
      it { is_expected.to validate_presence_of(:display_name) }

      it 'nilはエラー' do
        user = build(:user, display_name: nil)
        expect(user).not_to be_valid
        expect(user.errors[:display_name]).to be_present
      end

      it '空文字はエラー' do
        user = build(:user, display_name: '')
        expect(user).not_to be_valid
        expect(user.errors[:display_name]).to be_present
      end
    end
  end

  describe 'enum' do
    it { is_expected.to define_enum_for(:role).with_values(general: 0, commissioner: 1) }

    it 'デフォルトはgeneral' do
      user = User.new
      expect(user.role).to eq('general')
    end

    it 'commissionerに設定できる' do
      user = create(:user, :commissioner)
      expect(user).to be_commissioner
    end

    it 'generalに設定できる' do
      user = create(:user)
      expect(user).to be_general
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効' do
      expect(build(:user)).to be_valid
    end

    it 'commissionerトレイトが有効' do
      expect(build(:user, :commissioner)).to be_valid
    end
  end
end
