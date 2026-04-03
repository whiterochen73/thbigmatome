require "rails_helper"

RSpec.describe GameEvent, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game) }
  end

  describe "バリデーション: seq" do
    it "presence: 必須" do
      event = build(:game_event, seq: nil)
      expect(event).not_to be_valid
      expect(event.errors[:seq]).to be_present
    end

    it "1 は有効" do
      event = build(:game_event, seq: 1)
      expect(event).to be_valid
    end

    it "0 はエラー（greater_than: 0）" do
      event = build(:game_event, seq: 0)
      expect(event).not_to be_valid
      expect(event.errors[:seq]).to be_present
    end

    it "小数はエラー" do
      event = build(:game_event, seq: 1.5)
      expect(event).not_to be_valid
    end

    it "game_id スコープで一意性制約" do
      game = create(:game)
      create(:game_event, game: game, seq: 1)
      event2 = build(:game_event, game: game, seq: 1)
      expect(event2).not_to be_valid
      expect(event2.errors[:seq]).to be_present
    end

    it "別ゲームの同 seq は有効" do
      create(:game_event, seq: 1)
      event2 = build(:game_event, seq: 1)
      expect(event2).to be_valid
    end
  end

  describe "バリデーション: event_type" do
    it "presence: 必須" do
      event = build(:game_event, event_type: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to be_present
    end

    it "任意の文字列は有効" do
      event = build(:game_event, event_type: "score")
      expect(event).to be_valid
    end
  end

  describe "バリデーション: inning" do
    it "1 は有効" do
      event = build(:game_event, inning: 1)
      expect(event).to be_valid
    end

    it "0 はエラー（greater_than: 0）" do
      event = build(:game_event, inning: 0)
      expect(event).not_to be_valid
      expect(event.errors[:inning]).to be_present
    end

    it "小数はエラー" do
      event = build(:game_event, inning: 1.5)
      expect(event).not_to be_valid
    end
  end

  describe "バリデーション: half" do
    %w[top bottom].each do |valid_half|
      it "#{valid_half} は有効" do
        event = build(:game_event, half: valid_half)
        expect(event).to be_valid
      end
    end

    it "invalid はエラー" do
      event = build(:game_event, half: "middle")
      expect(event).not_to be_valid
      expect(event.errors[:half]).to be_present
    end
  end
end
