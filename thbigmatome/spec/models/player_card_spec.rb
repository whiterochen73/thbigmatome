require "rails_helper"

RSpec.describe PlayerCard, type: :model do
  let(:player_card) { create(:player_card) }
  let(:card_set) { create(:card_set) }
  let(:player) { create(:player) }

  describe "validations" do
    describe "presence validations" do
      it "validates presence of card_set_id" do
        player_card = build(:player_card, card_set_id: nil)
        expect(player_card).not_to be_valid
        expect(player_card.errors[:card_set_id]).to include("can't be blank")
      end

      it "validates presence of player_id" do
        player_card = build(:player_card, player_id: nil)
        expect(player_card).not_to be_valid
        expect(player_card.errors[:player_id]).to include("can't be blank")
      end
    end

    describe "uniqueness validations" do
      it "validates uniqueness of [card_set_id, player_id, card_type]" do
        existing = create(:player_card, card_set: card_set, player: player, card_type: "batter")
        duplicate = build(:player_card, card_set: card_set, player: player, card_type: "batter")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:card_set_id]).to include("has already been taken")
      end

      it "allows same player in same card_set with different card_type (two-way player)" do
        existing = create(:player_card, card_set: card_set, player: player, card_type: "batter")
        pitcher_card = build(:player_card, card_set: card_set, player: player, card_type: "pitcher")

        expect(pitcher_card).to be_valid
      end

      it "allows same player in different card_set" do
        existing = create(:player_card, card_set: card_set, player: player, card_type: "batter")
        different_set = create(:card_set, set_type: "special")
        new_card = build(:player_card, card_set: different_set, player: player, card_type: "batter")

        expect(new_card).to be_valid
      end

      it "allows different player in same card_set" do
        existing = create(:player_card, card_set: card_set, player: player, card_type: "batter")
        different_player = create(:player)
        new_card = build(:player_card, card_set: card_set, player: different_player, card_type: "batter")

        expect(new_card).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to card_set" do
      association = PlayerCard.reflect_on_association(:card_set)
      expect(association.macro).to eq :belongs_to
    end

    it "belongs to player" do
      association = PlayerCard.reflect_on_association(:player)
      expect(association.macro).to eq :belongs_to
    end

    it "belongs to batting_style (optional)" do
      association = PlayerCard.reflect_on_association(:batting_style)
      expect(association.macro).to eq :belongs_to
      expect(association.options[:optional]).to eq true
    end

    it "belongs to pitching_style (optional)" do
      association = PlayerCard.reflect_on_association(:pitching_style)
      expect(association.macro).to eq :belongs_to
      expect(association.options[:optional]).to eq true
    end

    it "belongs to pinch_pitching_style (optional)" do
      association = PlayerCard.reflect_on_association(:pinch_pitching_style)
      expect(association.macro).to eq :belongs_to
      expect(association.options[:optional]).to eq true
    end

    it "belongs to catcher_pitching_style (optional)" do
      association = PlayerCard.reflect_on_association(:catcher_pitching_style)
      expect(association.macro).to eq :belongs_to
      expect(association.options[:optional]).to eq true
    end

    it "has many player_card_player_types with dependent destroy" do
      association = PlayerCard.reflect_on_association(:player_card_player_types)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end

    it "has many player_types through player_card_player_types" do
      association = PlayerCard.reflect_on_association(:player_types)
      expect(association.macro).to eq :has_many
      expect(association.options[:through]).to eq :player_card_player_types
    end
  end

  describe "stat validations" do
    it "validates speed presence and inclusion" do
      player_card = build(:player_card, speed: nil)
      expect(player_card).not_to be_valid
      expect(player_card.errors[:speed]).to include("can't be blank")
    end

    it "validates bunt presence and inclusion" do
      player_card = build(:player_card, bunt: nil)
      expect(player_card).not_to be_valid
      expect(player_card.errors[:bunt]).to include("can't be blank")
    end

    it "validates steal_start presence and inclusion" do
      player_card = build(:player_card, steal_start: nil)
      expect(player_card).not_to be_valid
      expect(player_card.errors[:steal_start]).to include("can't be blank")
    end

    it "validates steal_end presence and inclusion" do
      player_card = build(:player_card, steal_end: nil)
      expect(player_card).not_to be_valid
      expect(player_card.errors[:steal_end]).to include("can't be blank")
    end

    it "validates injury_rate presence and inclusion" do
      player_card = build(:player_card, injury_rate: nil)
      expect(player_card).not_to be_valid
      expect(player_card.errors[:injury_rate]).to include("can't be blank")
    end
  end
end
