require "rails_helper"

RSpec.describe PitcherGameState, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:pitcher).class_name("Player") }
    it { is_expected.to belong_to(:competition).optional }
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

  describe ".calculate_result_category" do
    context "game_result が no_game のとき" do
      it "no_game を返す" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 6.0, game_result: "no_game", pitchers_in_game: 1
        )).to eq("no_game")
      end
    end

    context "role が starter 以外（reliever / opener）のとき" do
      it "reliever は normal を返す" do
        expect(described_class.calculate_result_category(
          role: "reliever", innings_pitched: 2.0, game_result: "win", pitchers_in_game: 3
        )).to eq("normal")
      end

      it "opener は normal を返す" do
        expect(described_class.calculate_result_category(
          role: "opener", innings_pitched: 1.0, game_result: "win", pitchers_in_game: 2
        )).to eq("normal")
      end
    end

    context "starter で innings < 5 かつ 後続投手あり（pitchers_in_game > 1）のとき" do
      it "ko を返す（負け試合かつ decision='L'）" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 4.2, game_result: "lose", pitchers_in_game: 2, decision: "L"
        )).to eq("ko")
      end
    end

    context "starter で負け + fatigue_p > 0 + innings > fp+1 のとき" do
      it "long_loss を返す" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 7.1, game_result: "lose", pitchers_in_game: 1, fatigue_p: 6
        )).to eq("long_loss")
      end
    end

    context "それ以外（先発・5イニング以上等）" do
      it "normal を返す" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 7.0, game_result: "win", pitchers_in_game: 1
        )).to eq("normal")
      end
    end

    describe "境界値テスト" do
      it "innings==5.0 は KO にならない（normal）" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 5.0, game_result: "lose", pitchers_in_game: 2
        )).to eq("normal")
      end

      it "innings==4.2 は KO（< 5 かつ後続あり かつ decision='L'）" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 4.2, game_result: "lose", pitchers_in_game: 2, decision: "L"
        )).to eq("ko")
      end

      it "innings==fp+1.0 は normal（long_loss でない）" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 7.0, game_result: "lose", pitchers_in_game: 1, fatigue_p: 6
        )).to eq("normal")
      end

      it "innings==fp+1.1 は long_loss" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 7.1, game_result: "lose", pitchers_in_game: 1, fatigue_p: 6
        )).to eq("long_loss")
      end

      it "pitchers_in_game==1（完投）は KO にならない" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 4.0, game_result: "win", pitchers_in_game: 1
        )).to eq("normal")
      end

      it "勝ち試合で先発が4回降板 → KO にならない（normal）" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 4.0, game_result: "win", pitchers_in_game: 2, decision: nil
        )).to eq("normal")
      end

      it "負け試合で先発が4回降板 + decision='L' → KO" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 2, decision: "L"
        )).to eq("ko")
      end

      it "負け試合で先発が4回降板 + decision=nil（リリーフがLを持つ） → KO にならない" do
        expect(described_class.calculate_result_category(
          role: "starter", innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 2, decision: nil
        )).to eq("normal")
      end
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
