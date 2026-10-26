require "rails_helper"

# Test Basis: cmd_1775 第2段 E3 / rulebook §8.5.1 条件2・§8.7.1 手順3（連続中4日先発カウントの更新）/
#   AMB-04 出場停止と負傷は別枠（2026-09-12。中日数から引くのは負傷離脱のみ）
RSpec.describe PitcherConsecutiveShortRest, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher_and_membership) { create_card_pitcher(team: team, starter_stamina: 7) }
  let(:pitcher) { pitcher_and_membership[0] }
  let(:membership) { pitcher_and_membership[1] }

  def count_for(date, overrides: {})
    described_class.call(team_id: team.id, pitcher_id: pitcher.id, schedule_date: date, count_overrides: overrides)
  end

  describe "直前の先発との中日数でカウントを決める" do
    it "初登板（前の先発なし）は 0" do
      expect(count_for("2026-06-10")).to eq(0)
    end

    it "中4日なら前回値 +1（前回 0 → 1、前回 1 → 2）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      expect(count_for("2026-06-06")).to eq(1) # 中4日

      PitcherGameState.where(pitcher_id: pitcher.id).update_all(consecutive_short_rest_count: 1)
      expect(count_for("2026-06-06")).to eq(2)
    end

    it "中5日は 0 にリセットする（前回値が残っていても）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      expect(count_for("2026-06-07")).to eq(0) # 中5日
    end

    it "中3日も 0（中4日ちょうどだけが +1）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      expect(count_for("2026-06-05")).to eq(0) # 中3日
    end

    it "前の登板がリリーフだけなら、先発の連続は始まらない（0）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 2.0, role: "reliever", consecutive_short_rest_count: 0)
      expect(count_for("2026-06-06")).to eq(0)
    end

    it "直前の先発は、間にリリーフ登板があっても先発同士で数える（先発 6/1 → リリーフ 6/4 → 先発 6/6 は中4日）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      create_start(team: team, pitcher: pitcher, date: "2026-06-04", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-06")).to eq(1)
    end

    it "別チームの登板は数えない" do
      other_team = create(:team)
      create_start(team: other_team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      expect(count_for("2026-06-06")).to eq(0)
    end

    it "対象日以降の登板は前の先発に数えない（同日・後日）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 6.0, consecutive_short_rest_count: 1)
      expect(count_for("2026-06-06")).to eq(0)
    end

    it "count_overrides があれば保存済みの前回値より優先する（試運転の連鎖用）" do
      prev = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      expect(count_for("2026-06-06", overrides: { prev.id => 3 })).to eq(4)
    end
  end

  describe "離脱の控除（E4: 控除は負傷のみ。出場停止・再調整は控除しない）" do
    before { create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0) }

    def absence(type, days: 2, start: "2026-06-02")
      create(:player_absence, team_membership: membership, season: season, absence_type: type,
                              start_date: Date.parse(start), duration: days, duration_unit: "days")
    end

    it "負傷を挟むと中日数から引く: 実日数中6日 - 負傷2日 = 中4日 → +1" do
      absence(:injury)
      expect(count_for("2026-06-08")).to eq(1)
    end

    it "出場停止を挟んでも引かない: 実日数中6日のまま → 0（中4日にならない）" do
      absence(:suspension)
      expect(count_for("2026-06-08")).to eq(0)
    end

    it "再調整も引かない" do
      absence(:reconditioning)
      expect(count_for("2026-06-08")).to eq(0)
    end

    it "負傷と出場停止が同時にあっても、引くのは負傷分だけ（実日数中7日 - 負傷3日 = 中4日 → +1）" do
      absence(:injury, days: 3)
      absence(:suspension, days: 2, start: "2026-06-03")
      expect(count_for("2026-06-09")).to eq(1)
    end
  end
end
