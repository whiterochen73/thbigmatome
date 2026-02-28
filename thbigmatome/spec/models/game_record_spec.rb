require "rails_helper"

RSpec.describe GameRecord, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:at_bat_records).dependent(:destroy) }
  end

  describe "バリデーション: status" do
    it "draft は有効" do
      game_record = build(:game_record, status: "draft")
      expect(game_record).to be_valid
    end

    it "confirmed は有効" do
      game_record = build(:game_record, status: "confirmed")
      expect(game_record).to be_valid
    end

    it "不正なstatusはエラー" do
      game_record = build(:game_record, status: "invalid")
      expect(game_record).not_to be_valid
      expect(game_record.errors[:status]).to be_present
    end
  end

  describe "バリデーション: result" do
    it "win は有効" do
      expect(build(:game_record, result: "win")).to be_valid
    end

    it "lose は有効" do
      expect(build(:game_record, result: "lose")).to be_valid
    end

    it "draw は有効" do
      expect(build(:game_record, result: "draw")).to be_valid
    end

    it "nil は有効（任意）" do
      expect(build(:game_record, result: nil)).to be_valid
    end

    it "不正なresultはエラー" do
      game_record = build(:game_record, result: "invalid")
      expect(game_record).not_to be_valid
      expect(game_record.errors[:result]).to be_present
    end
  end

  describe "#draft?" do
    it "status=draftのとき true" do
      expect(build(:game_record, status: "draft").draft?).to be true
    end

    it "status=confirmedのとき false" do
      expect(build(:game_record, status: "confirmed").draft?).to be false
    end
  end

  describe "#confirmed?" do
    it "status=confirmedのとき true" do
      expect(build(:game_record, status: "confirmed").confirmed?).to be true
    end

    it "status=draftのとき false" do
      expect(build(:game_record, status: "draft").confirmed?).to be false
    end
  end

  describe "スコープ" do
    it ".draft でdraftレコードのみ返す" do
      draft = create(:game_record, status: "draft")
      create(:game_record, :confirmed)
      expect(GameRecord.draft).to eq([ draft ])
    end

    it ".confirmed でconfirmedレコードのみ返す" do
      confirmed = create(:game_record, :confirmed)
      create(:game_record, status: "draft")
      expect(GameRecord.confirmed).to eq([ confirmed ])
    end
  end
end
