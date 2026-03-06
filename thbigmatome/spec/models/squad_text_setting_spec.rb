require "rails_helper"

RSpec.describe SquadTextSetting, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:team) }
  end

  describe "デフォルト値" do
    subject(:setting) { SquadTextSetting.new }

    it "batting_stats_config にデフォルトが設定される" do
      expect(setting.batting_stats_config["avg"]).to eq(true)
      expect(setting.batting_stats_config["hr"]).to eq(true)
      expect(setting.batting_stats_config["rbi"]).to eq(true)
      expect(setting.batting_stats_config["sb"]).to eq(false)
      expect(setting.batting_stats_config["obp"]).to eq(false)
      expect(setting.batting_stats_config["ops"]).to eq(false)
      expect(setting.batting_stats_config["ab_h"]).to eq(false)
    end

    it "pitching_stats_config にデフォルトが設定される" do
      expect(setting.pitching_stats_config["w_l"]).to eq(true)
      expect(setting.pitching_stats_config["games"]).to eq(true)
      expect(setting.pitching_stats_config["era"]).to eq(true)
      expect(setting.pitching_stats_config["so"]).to eq(true)
      expect(setting.pitching_stats_config["ip"]).to eq(true)
      expect(setting.pitching_stats_config["hold"]).to eq(false)
      expect(setting.pitching_stats_config["save"]).to eq(false)
    end

    it "既存の値はデフォルトに上書きされない" do
      setting = SquadTextSetting.new(batting_stats_config: { "avg" => false, "sb" => true })
      expect(setting.batting_stats_config["avg"]).to eq(false)
      expect(setting.batting_stats_config["sb"]).to eq(true)
      expect(setting.batting_stats_config["hr"]).to eq(true)
    end
  end
end
