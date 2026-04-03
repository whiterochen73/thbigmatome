require "rails_helper"

RSpec.describe LineupTemplate, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:lineup_template_entries).dependent(:destroy) }
  end

  describe "バリデーション: opponent_pitcher_hand" do
    it "'left' は有効" do
      template = build(:lineup_template, opponent_pitcher_hand: "left")
      expect(template).to be_valid
    end

    it "'right' は有効" do
      template = build(:lineup_template, opponent_pitcher_hand: "right")
      expect(template).to be_valid
    end

    it "無効な値はエラー" do
      template = build(:lineup_template, opponent_pitcher_hand: "center")
      expect(template).not_to be_valid
      expect(template.errors[:opponent_pitcher_hand]).to be_present
    end
  end

  describe "バリデーション: ユニーク制約 [team_id, dh_enabled, opponent_pitcher_hand]" do
    let(:team) { create(:team) }

    it "同じチームで同一パターンは重複エラー" do
      create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      duplicate = build(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:team_id]).to be_present
    end

    it "同じチームで異なるdh_enabledは有効" do
      create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      template = build(:lineup_template, team: team, dh_enabled: false, opponent_pitcher_hand: "right")
      expect(template).to be_valid
    end

    it "同じチームで異なるopponent_pitcher_handは有効" do
      create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      template = build(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "left")
      expect(template).to be_valid
    end

    it "異なるチームは有効" do
      team2 = create(:team)
      create(:lineup_template, team: team, dh_enabled: true, opponent_pitcher_hand: "right")
      template = build(:lineup_template, team: team2, dh_enabled: true, opponent_pitcher_hand: "right")
      expect(template).to be_valid
    end
  end
end
