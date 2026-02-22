require "rails_helper"

RSpec.describe AtBat, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:batter).class_name("Player") }
    it { is_expected.to belong_to(:pitcher).class_name("Player") }
    it { is_expected.to belong_to(:pinch_hit_for).class_name("Player").optional }
  end

  describe "enum: status" do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, confirmed: 1) }

    it "draft は有効" do
      at_bat = build(:at_bat, status: :draft)
      expect(at_bat).to be_valid
    end

    it "confirmed は有効" do
      at_bat = build(:at_bat, status: :confirmed)
      expect(at_bat).to be_valid
    end
  end

  describe "バリデーション: seq" do
    it "presence: 必須" do
      at_bat = build(:at_bat, seq: nil)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:seq]).to be_present
    end

    it "整数 1 以上は有効" do
      at_bat = build(:at_bat, seq: 1)
      expect(at_bat).to be_valid
    end

    it "0 はエラー（greater_than: 0）" do
      at_bat = build(:at_bat, seq: 0)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:seq]).to be_present
    end

    it "小数はエラー" do
      at_bat = build(:at_bat, seq: 1.5)
      expect(at_bat).not_to be_valid
    end

    it "game_id スコープで一意性制約" do
      game = create(:game)
      create(:at_bat, game: game, seq: 1)
      at_bat2 = build(:at_bat, game: game, seq: 1)
      expect(at_bat2).not_to be_valid
      expect(at_bat2.errors[:seq]).to be_present
    end

    it "別ゲームの同 seq は有効" do
      create(:at_bat, seq: 1)
      at_bat2 = build(:at_bat, seq: 1)
      expect(at_bat2).to be_valid
    end
  end

  describe "バリデーション: half" do
    %w[top bottom].each do |valid_half|
      it "#{valid_half} は有効" do
        at_bat = build(:at_bat, half: valid_half)
        expect(at_bat).to be_valid
      end
    end

    it "invalid はエラー" do
      at_bat = build(:at_bat, half: "middle")
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:half]).to be_present
    end
  end

  describe "バリデーション: play_type" do
    %w[normal bunt squeeze safety_bunt hit_and_run].each do |valid_type|
      it "#{valid_type} は有効" do
        at_bat = build(:at_bat, play_type: valid_type)
        expect(at_bat).to be_valid
      end
    end

    it "invalid はエラー" do
      at_bat = build(:at_bat, play_type: "invalid")
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:play_type]).to be_present
    end
  end

  describe "バリデーション: result_code" do
    it "presence: 必須" do
      at_bat = build(:at_bat, result_code: nil)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:result_code]).to be_present
    end
  end

  describe "バリデーション: inning" do
    it "1 は有効" do
      at_bat = build(:at_bat, inning: 1)
      expect(at_bat).to be_valid
    end

    it "0 はエラー（greater_than: 0）" do
      at_bat = build(:at_bat, inning: 0)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:inning]).to be_present
    end

    it "小数はエラー" do
      at_bat = build(:at_bat, inning: 1.5)
      expect(at_bat).not_to be_valid
    end
  end

  describe "バリデーション: outs" do
    [ 0, 1, 2 ].each do |valid_outs|
      it "#{valid_outs} は有効" do
        at_bat = build(:at_bat, outs: valid_outs)
        expect(at_bat).to be_valid
      end
    end

    it "-1 はエラー（greater_than_or_equal_to: 0）" do
      at_bat = build(:at_bat, outs: -1)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:outs]).to be_present
    end

    it "3 はエラー（less_than_or_equal_to: 2）" do
      at_bat = build(:at_bat, outs: 3)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:outs]).to be_present
    end
  end

  describe "バリデーション: outs_after" do
    [ 0, 1, 2, 3 ].each do |valid_outs|
      it "#{valid_outs} は有効" do
        at_bat = build(:at_bat, outs_after: valid_outs)
        expect(at_bat).to be_valid
      end
    end

    it "-1 はエラー（greater_than_or_equal_to: 0）" do
      at_bat = build(:at_bat, outs_after: -1)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:outs_after]).to be_present
    end

    it "4 はエラー（less_than_or_equal_to: 3）" do
      at_bat = build(:at_bat, outs_after: 4)
      expect(at_bat).not_to be_valid
      expect(at_bat.errors[:outs_after]).to be_present
    end
  end
end
