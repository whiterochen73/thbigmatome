require "rails_helper"

# Test Basis: cmd_1896。時限選手の起用の記録（登板・先発メンバー）は止めず警告にして保存する（1軍でない投手の登板と同じ扱い）。
RSpec.describe TimeLimitedPlayerCheck, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  before { create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day") }

  def warnings_on(date) = described_class.warnings(team: team, date: Date.parse(date), player_ids: [ pitcher.id ])

  it "時限でなければ警告なし" do
    expect(warnings_on("2026-04-02")).to eq([])
  end

  context "「4/22~」の時限選手" do
    before { pitcher.player_cards.first.update!(unique_traits: "4/22~") }

    it "4/21 は警告、4/22 は警告なし" do
      expect(warnings_on("2026-04-21").first).to include(pitcher.name, "4/22 から", "2026-04-21")
      expect(warnings_on("2026-04-22")).to eq([])
    end
  end

  context "「~9/24」の時限選手" do
    before { pitcher.player_cards.first.update!(unique_traits: "~9/24\n左手突き指") }

    it "9/24 は警告なし、9/25 は警告" do
      expect(warnings_on("2026-09-24")).to eq([])
      expect(warnings_on("2026-09-25").size).to eq(1)
    end
  end

  it "選手が空・チームの在籍が無い選手なら空" do
    expect(described_class.warnings(team: team, date: Date.new(2026, 4, 2), player_ids: [])).to eq([])
    expect(described_class.warnings(team: team, date: Date.new(2026, 4, 2), player_ids: [ create(:player).id ])).to eq([])
  end
end
