require "rails_helper"

RSpec.describe GameLineupEntry, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:player_card) }
  end

  describe "enum :role" do
    it "starter: 0" do
      expect(GameLineupEntry.roles[:starter]).to eq(0)
    end

    it "bench: 1" do
      expect(GameLineupEntry.roles[:bench]).to eq(1)
    end

    it "off: 2" do
      expect(GameLineupEntry.roles[:off]).to eq(2)
    end

    it "designated_player: 3" do
      expect(GameLineupEntry.roles[:designated_player]).to eq(3)
    end
  end

  describe "バリデーション: batting_order" do
    it "1〜9 は有効" do
      (1..9).each do |order|
        entry = build(:game_lineup_entry, batting_order: order)
        expect(entry).to be_valid, "batting_order #{order} should be valid"
      end
    end

    it "0 はエラー" do
      entry = build(:game_lineup_entry, batting_order: 0)
      expect(entry).not_to be_valid
      expect(entry.errors[:batting_order]).to be_present
    end

    it "10 はエラー" do
      entry = build(:game_lineup_entry, batting_order: 10)
      expect(entry).not_to be_valid
      expect(entry.errors[:batting_order]).to be_present
    end

    it "nil は有効（allow_nil）" do
      entry = build(:game_lineup_entry, role: :bench, batting_order: nil, position: nil)
      expect(entry).to be_valid
    end
  end

  describe "バリデーション: batting_order uniqueness per game" do
    it "同一game内で batting_order が重複するとエラー" do
      game = create(:game)
      player_card1 = create(:player_card)
      player_card2 = create(:player_card)
      create(:game_lineup_entry, game: game, player_card: player_card1, batting_order: 1, position: "P")
      entry2 = build(:game_lineup_entry, game: game, player_card: player_card2, batting_order: 1, position: "C")
      expect(entry2).not_to be_valid
      expect(entry2.errors[:batting_order]).to be_present
    end

    it "nil の batting_order は重複チェック対象外" do
      game = create(:game)
      player_card1 = create(:player_card)
      player_card2 = create(:player_card)
      create(:game_lineup_entry, game: game, player_card: player_card1, role: :bench, batting_order: nil, position: nil)
      entry2 = build(:game_lineup_entry, game: game, player_card: player_card2, role: :bench, batting_order: nil, position: nil)
      expect(entry2).to be_valid
    end
  end

  describe "バリデーション: position" do
    %w[P C 1B 2B 3B SS LF CF RF DH].each do |pos|
      it "#{pos} は有効" do
        entry = build(:game_lineup_entry, position: pos)
        expect(entry).to be_valid
      end
    end

    it "無効なポジションはエラー" do
      entry = build(:game_lineup_entry, position: "XX")
      expect(entry).not_to be_valid
      expect(entry.errors[:position]).to be_present
    end
  end

  describe "カスタムバリデーション: starter は batting_order と position が必須" do
    it "starter で batting_order が nil ならエラー" do
      entry = build(:game_lineup_entry, role: :starter, batting_order: nil, position: "P")
      expect(entry).not_to be_valid
      expect(entry.errors[:batting_order]).to be_present
    end

    it "starter で position が nil ならエラー" do
      entry = build(:game_lineup_entry, role: :starter, batting_order: 1, position: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:position]).to be_present
    end

    it "bench では batting_order と position が nil でも有効" do
      entry = build(:game_lineup_entry, role: :bench, batting_order: nil, position: nil)
      expect(entry).to be_valid
    end

    it "off では batting_order と position が nil でも有効" do
      entry = build(:game_lineup_entry, role: :off, batting_order: nil, position: nil)
      expect(entry).to be_valid
    end

    it "designated_player では batting_order と position が nil でも有効" do
      entry = build(:game_lineup_entry, role: :designated_player, batting_order: nil, position: nil)
      expect(entry).to be_valid
    end
  end
end
