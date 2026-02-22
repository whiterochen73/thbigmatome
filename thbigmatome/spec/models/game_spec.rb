require "rails_helper"

RSpec.describe Game, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to belong_to(:home_team).class_name("Team") }
    it { is_expected.to belong_to(:visitor_team).class_name("Team") }
    it { is_expected.to belong_to(:stadium) }
    it { is_expected.to have_many(:at_bats).dependent(:destroy) }
    it { is_expected.to have_many(:game_events).dependent(:destroy) }
    it { is_expected.to have_many(:pitcher_game_states).dependent(:destroy) }
  end

  describe "バリデーション: status" do
    it "draft は有効" do
      game = build(:game, status: "draft")
      expect(game).to be_valid
    end

    it "confirmed は有効" do
      game = build(:game, status: "confirmed")
      expect(game).to be_valid
    end

    it "invalid_status はエラー" do
      game = build(:game, status: "invalid")
      expect(game).not_to be_valid
      expect(game.errors[:status]).to be_present
    end

    it "空文字はエラー" do
      game = build(:game, status: "")
      expect(game).not_to be_valid
    end
  end

  describe "バリデーション: source" do
    %w[live log_import summary].each do |valid_source|
      it "#{valid_source} は有効" do
        game = build(:game, source: valid_source)
        expect(game).to be_valid
      end
    end

    it "invalid_source はエラー" do
      game = build(:game, source: "invalid")
      expect(game).not_to be_valid
      expect(game.errors[:source]).to be_present
    end
  end

  describe "#draft?" do
    it "status が draft のとき true を返す" do
      game = build(:game, status: "draft")
      expect(game.draft?).to be true
    end

    it "status が confirmed のとき false を返す" do
      game = build(:game, status: "confirmed")
      expect(game.draft?).to be false
    end
  end
end
