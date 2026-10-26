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

    it "中3日も +1（中4日以下が連続に数えられる。AMB-23）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      expect(count_for("2026-06-05")).to eq(2) # 中3日
    end

    it "前の登板がリリーフだけなら、先発の連続は始まらない（0）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 2.0, role: "reliever", consecutive_short_rest_count: 0)
      expect(count_for("2026-06-06")).to eq(0)
    end

    it "先発 6/1 → リリーフ 6/4 → 先発 6/6: 直前の登板がリリーフなので 0（先発 6/1 からは中4日でも飛ばして数えない）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      create_start(team: team, pitcher: pitcher, date: "2026-06-04", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-06")).to eq(0)
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

  # Test Basis: AMB-23（2026-10-26 Operator 確定）。連続は「起点の登板以降がすべて先発登板」の時だけ。
  #   間にリリーフ・オープナー登板が入れば 0。第二先発の 2 番手（role=starter で保存）は先発扱いで切らない（rulebook §8.4.2）。
  describe "連続中4日は直前の登板（役割を問わない）で数える（AMB-23）" do
    it "先発 → (中4日) 先発 → (中4日) 先発 で 0, 1, 2 と数える（保存時の連鎖）" do
      s1 = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: count_for("2026-06-01"))
      expect(s1.consecutive_short_rest_count).to eq(0)
      s2 = create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 6.0, consecutive_short_rest_count: count_for("2026-06-06"))
      expect(s2.consecutive_short_rest_count).to eq(1)
      expect(count_for("2026-06-11")).to eq(2)
    end

    # Test Basis: Operator 2026-10-26「連続する３回の先発登板で、その間隔が両方とも中４日以下」（AMB-23 追記）
    {
      "先発 → (中3日) 先発 → (中4日) 先発" => [ "2026-06-01", "2026-06-05", "2026-06-10" ],
      "先発 → (中4日) 先発 → (中3日) 先発" => [ "2026-06-01", "2026-06-06", "2026-06-10" ],
      "先発 → (中3日) 先発 → (中3日) 先発" => [ "2026-06-01", "2026-06-05", "2026-06-09" ],
      "先発 → (中4日) 先発 → (中4日) 先発" => [ "2026-06-01", "2026-06-06", "2026-06-11" ]
    }.each do |label, dates|
      it "#{label} は 0, 1, 2（3 回目はカウント 1 以上の先発 = 条件 2 の形）" do
        counts = dates.map do |d|
          c = count_for(d)
          create_start(team: team, pitcher: pitcher, date: d, innings: 6.0, consecutive_short_rest_count: c)
          c
        end
        expect(counts).to eq([ 0, 1, 2 ])
      end
    end

    it "先発 → (中5日) 先発 → (中4日) 先発 は 0, 0, 1（間隔の片方が中5日なら、3 回目の前の先発のカウントは 0）" do
      counts = %w[2026-06-01 2026-06-07 2026-06-12].map do |d|
        c = count_for(d)
        create_start(team: team, pitcher: pitcher, date: d, innings: 6.0, consecutive_short_rest_count: c)
        c
      end
      expect(counts).to eq([ 0, 0, 1 ])
    end

    it "先発 → (中4日) 先発 → (中5日) 先発 は 0, 1, 0（中5日で切れる）" do
      counts = %w[2026-06-01 2026-06-06 2026-06-12].map do |d|
        c = count_for(d)
        create_start(team: team, pitcher: pitcher, date: d, innings: 6.0, consecutive_short_rest_count: c)
        c
      end
      expect(counts).to eq([ 0, 1, 0 ])
    end

    it "中2日以内（先発不可の間隔。通常は現れない）は、中4日以下として数える（literal）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      expect(count_for("2026-06-03")).to eq(1) # 中1日
    end

    it "先発 6/1 → リリーフ 6/4 → 先発 6/9: リリーフから中4日でも、先発ではないので 0" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      create_start(team: team, pitcher: pitcher, date: "2026-06-04", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-09")).to eq(0)
    end

    it "先発 6/1 → (中4日) リリーフ 6/6 → (中4日) 先発 6/11 も 0" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-11")).to eq(0)
    end

    it "先発 → オープナー → 先発 は 0（オープナー登板はリリーフ扱い。§8.4.2）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 1.0, role: "opener")
      expect(count_for("2026-06-11")).to eq(0)
    end

    it "前の登板がオープナーだけなら、先発の連続は始まらない（0）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 1.0, role: "opener", consecutive_short_rest_count: 0)
      expect(count_for("2026-06-06")).to eq(0)
    end

    it "先発 → (中4日) 第二先発の 2 番手（role=starter）→ (中4日) 先発: 2 番手は先発扱いなので連続が切れない（0, 1, 2）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      second = create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 5.0, role: "starter",
                            appearance_order: 1, consecutive_short_rest_count: count_for("2026-06-06"))
      expect(second.consecutive_short_rest_count).to eq(1)
      expect(count_for("2026-06-11")).to eq(2)
    end

    it "先発 → (中4日) 先発 → リリーフ 6/8 → (中4日) 先発 6/13 で 0（途中までの連続は切れる）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 6.0, consecutive_short_rest_count: 1)
      create_start(team: team, pitcher: pitcher, date: "2026-06-08", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-13")).to eq(0)
    end

    it "直前が先発なら、その前にリリーフがあっても前回値 +1（前の連続は直前の先発の保存値が持っている）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 1.0, role: "reliever")
      create_start(team: team, pitcher: pitcher, date: "2026-06-03", innings: 6.0, consecutive_short_rest_count: 0)
      expect(count_for("2026-06-08")).to eq(1)
    end

    it "同じ日に登板が 2 件ある時は id の新しい方を直前の登板とする（決定性）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 6.0, consecutive_short_rest_count: 1)
      create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-11")).to eq(0)
    end

    it "リセット（実日数中10日以上）なら直前が先発でも 0（AMB-04 追補 3 と両立）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1)
      expect(count_for("2026-06-12")).to eq(0)
    end

    it "別チームのリリーフ登板は直前の登板に数えない（同チーム・対象日より前だけ）" do
      other_team = create(:team)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 0)
      create_start(team: other_team, pitcher: pitcher, date: "2026-06-04", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-06")).to eq(1)
    end

    it "count_overrides は直前の先発にだけ効く（直前がリリーフなら上書き値があっても 0）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      relief = create_start(team: team, pitcher: pitcher, date: "2026-06-04", innings: 1.0, role: "reliever")
      expect(count_for("2026-06-09", overrides: { relief.id => 3 })).to eq(0)
    end
  end

  # Test Basis: AMB-04 追補 3（2026-10-26 Operator 確定）。実日数差で中10日リセットが成立する時は、
  #   連続中4日のカウントも 0 に戻る（控除後がちょうど中4日でも +1 しない）。リセットは他の判定より先に見る。
  describe "中10日リセット（AMB-04 追補 3）" do
    def injury(days:, start: "2026-06-02")
      create(:player_absence, team_membership: membership, season: season, absence_type: :injury,
                              start_date: Date.parse(start), duration: days, duration_unit: "days")
    end

    before { create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0, consecutive_short_rest_count: 1) }

    it "実日数中10日 - 負傷6日 = 控除後ちょうど中4日でも +1 しない（0）" do
      injury(days: 6)
      expect(count_for("2026-06-12")).to eq(0) # 実日数: 6/1 → 6/12 = 中10日
    end

    it "実日数中9日 - 負傷5日 = 控除後中4日は、リセット不成立なので +1（境界の手前）" do
      injury(days: 5)
      expect(count_for("2026-06-11")).to eq(2) # 実日数中9日。前回値 1 + 1
    end

    it "実日数中11日 - 負傷7日 = 控除後中4日も 0（リセットの内側）" do
      injury(days: 7)
      expect(count_for("2026-06-13")).to eq(0)
    end

    it "負傷が無く実日数が中4日なら従来どおり +1（リセットの影響を受けない）" do
      expect(count_for("2026-06-06")).to eq(2)
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
