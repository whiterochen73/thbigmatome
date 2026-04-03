require "rails_helper"

RSpec.describe LineupTemplateEntry, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:lineup_template) }
    it { is_expected.to belong_to(:player) }
  end

  describe "バリデーション: batting_order" do
    it "1〜9 は有効" do
      (1..9).each do |order|
        entry = build(:lineup_template_entry, batting_order: order)
        expect(entry).to be_valid, "batting_order #{order} should be valid"
      end
    end

    it "0 はエラー" do
      entry = build(:lineup_template_entry, batting_order: 0)
      expect(entry).not_to be_valid
      expect(entry.errors[:batting_order]).to be_present
    end

    it "10 はエラー" do
      entry = build(:lineup_template_entry, batting_order: 10)
      expect(entry).not_to be_valid
      expect(entry.errors[:batting_order]).to be_present
    end

    it "nil はエラー" do
      entry = build(:lineup_template_entry, batting_order: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:batting_order]).to be_present
    end
  end

  describe "バリデーション: position" do
    it "存在する場合は有効" do
      entry = build(:lineup_template_entry, position: "RF")
      expect(entry).to be_valid
    end

    it "nil はエラー" do
      entry = build(:lineup_template_entry, position: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:position]).to be_present
    end

    it "空文字はエラー" do
      entry = build(:lineup_template_entry, position: "")
      expect(entry).not_to be_valid
      expect(entry.errors[:position]).to be_present
    end
  end
end
