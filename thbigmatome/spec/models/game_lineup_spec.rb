require "rails_helper"

RSpec.describe GameLineup, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:team) }
  end

  describe "バリデーション: lineup_data" do
    it "データがある場合は有効" do
      game_lineup = build(:game_lineup)
      expect(game_lineup).to be_valid
    end

    it "nil はエラー" do
      game_lineup = build(:game_lineup, lineup_data: nil)
      expect(game_lineup).not_to be_valid
      expect(game_lineup.errors[:lineup_data]).to be_present
    end
  end
end
