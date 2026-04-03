require "rails_helper"

RSpec.describe AtBatRecord, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game_record) }
  end

  describe "バリデーション: half" do
    it "top は有効" do
      expect(build(:at_bat_record, half: "top")).to be_valid
    end

    it "bottom は有効" do
      expect(build(:at_bat_record, half: "bottom")).to be_valid
    end

    it "nil は有効（任意）" do
      expect(build(:at_bat_record, half: nil)).to be_valid
    end

    it "不正なhalfはエラー" do
      ab = build(:at_bat_record, half: "middle")
      expect(ab).not_to be_valid
      expect(ab.errors[:half]).to be_present
    end
  end

  describe "バリデーション: strategy" do
    %w[hitting bunt endrun steal intentional_walk].each do |s|
      it "#{s} は有効" do
        expect(build(:at_bat_record, strategy: s)).to be_valid
      end
    end

    it "nil は有効（任意）" do
      expect(build(:at_bat_record, strategy: nil)).to be_valid
    end

    it "不正なstrategyはエラー" do
      ab = build(:at_bat_record, strategy: "invalid")
      expect(ab).not_to be_valid
      expect(ab.errors[:strategy]).to be_present
    end
  end

  describe "バリデーション: runs_scored" do
    it "0は有効" do
      expect(build(:at_bat_record, runs_scored: 0)).to be_valid
    end

    it "負数はエラー" do
      ab = build(:at_bat_record, runs_scored: -1)
      expect(ab).not_to be_valid
      expect(ab.errors[:runs_scored]).to be_present
    end
  end

  describe "バリデーション: ab_num ユニーク制約" do
    it "同じgame_record内でab_numが重複するとエラー" do
      game_record = create(:game_record)
      create(:at_bat_record, game_record: game_record, ab_num: 1)
      ab = build(:at_bat_record, game_record: game_record, ab_num: 1)
      expect(ab).not_to be_valid
      expect(ab.errors[:ab_num]).to be_present
    end

    it "異なるgame_recordなら同じab_numでも有効" do
      gr1 = create(:game_record)
      gr2 = create(:game_record)
      create(:at_bat_record, game_record: gr1, ab_num: 1)
      ab = build(:at_bat_record, game_record: gr2, ab_num: 1)
      expect(ab).to be_valid
    end
  end
end
