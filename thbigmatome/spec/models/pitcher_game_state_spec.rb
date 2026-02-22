require "rails_helper"

RSpec.describe PitcherGameState, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:pitcher).class_name("Player") }
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to belong_to(:team) }
  end

  describe "バリデーション: pitcher_id の一意性（scope: game_id）" do
    it "同じゲームで同じ投手は登録できない" do
      game = create(:game)
      pitcher = create(:player, :pitcher)
      create(:pitcher_game_state, game: game, pitcher: pitcher)
      duplicate = build(:pitcher_game_state, game: game, pitcher: pitcher)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:pitcher_id]).to be_present
    end

    it "別ゲームで同じ投手は有効" do
      pitcher = create(:player, :pitcher)
      create(:pitcher_game_state, pitcher: pitcher)
      pgs2 = build(:pitcher_game_state, pitcher: pitcher)
      expect(pgs2).to be_valid
    end
  end

  describe "バリデーション: role" do
    %w[starter reliever opener].each do |valid_role|
      it "#{valid_role} は有効" do
        pgs = build(:pitcher_game_state, role: valid_role)
        expect(pgs).to be_valid
      end
    end

    it "invalid はエラー" do
      pgs = build(:pitcher_game_state, role: "invalid")
      expect(pgs).not_to be_valid
      expect(pgs.errors[:role]).to be_present
    end
  end

  describe "バリデーション: result_category" do
    %w[normal ko no_game long_loss].each do |valid_category|
      it "#{valid_category} は有効" do
        pgs = build(:pitcher_game_state, result_category: valid_category)
        expect(pgs).to be_valid
      end
    end

    it "nil は有効（allow_nil）" do
      pgs = build(:pitcher_game_state, result_category: nil)
      expect(pgs).to be_valid
    end

    it "invalid はエラー" do
      pgs = build(:pitcher_game_state, result_category: "invalid")
      expect(pgs).not_to be_valid
      expect(pgs.errors[:result_category]).to be_present
    end
  end

  describe "バリデーション: injury_check" do
    %w[safe injured].each do |valid_check|
      it "#{valid_check} は有効" do
        pgs = build(:pitcher_game_state, injury_check: valid_check)
        expect(pgs).to be_valid
      end
    end

    it "nil は有効（allow_nil）" do
      pgs = build(:pitcher_game_state, injury_check: nil)
      expect(pgs).to be_valid
    end

    it "invalid はエラー" do
      pgs = build(:pitcher_game_state, injury_check: "invalid")
      expect(pgs).not_to be_valid
      expect(pgs.errors[:injury_check]).to be_present
    end
  end
end
