require "rails_helper"

# Test Basis: cmd_1775 Operator 裁定 2026-10-25 #2 #3 / rulebook §8.2.1（未記載は先発3）・§8.3.1・§8.6 訂正(2026-09-13)
RSpec.describe PitcherStarterFatigue, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }

  def fatigue(pitcher, date, overrides: {})
    described_class.call(team_id: team.id, pitcher_id: pitcher.id, schedule_date: date, result_category_overrides: overrides)
  end

  describe "カードの引き方" do
    it "チームの登録(team_memberships)で紐づくカードの先発疲労P を使う" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: 7)
      # 同じ選手の別カードがあっても、チームに紐づくカードだけを見る
      other_card = create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: 4, variant: "alt")
      expect(other_card).to be_persisted
      expect(fatigue(pitcher, "2026-06-10").fatigue_p).to eq(7)
    end

    it "チームに登録が無い投手は判定保留（membership_not_found）。既定3にしない" do
      pitcher = create(:player, :pitcher)
      res = fatigue(pitcher, "2026-06-10")
      expect(res.pending).to eq(:membership_not_found)
      expect(res.fatigue_p).to be_nil
    end

    it "登録はあるがカードが紐づいていない投手は判定保留（card_not_identified）。既定3にしない" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: 7, with_card: false)
      res = fatigue(pitcher, "2026-06-10")
      expect(res.pending).to eq(:card_not_identified)
      expect(res.fatigue_p).to be_nil
    end
  end

  describe "カード未記載だけ既定3（裁定 3）" do
    it "カードの先発疲労P が未記載（nil）なら 3、card_unset が立つ" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: nil)
      res = fatigue(pitcher, "2026-06-10")
      expect(res.fatigue_p).to eq(3)
      expect(res.card_unset).to be(true)
    end

    it "カード未記載でも補正は既定3に対してかかる（中4日 -3 → 0）" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: nil)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      expect(fatigue(pitcher, "2026-06-06").fatigue_p).to eq(0)
    end

    it "補正の結果 0 はカード未記載とは別物（カード疲労P4・中3日 P0 → 0 のまま。3 にならない）" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: 4)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      res = fatigue(pitcher, "2026-06-05") # 中3日
      expect(res.fatigue_p).to eq(0)
      expect(res.card_unset).to be(false)
    end
  end

  describe "試合前のスタミナ補正（§8.3.1）" do
    let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

    it "初登板（前登板なし）は補正なし" do
      expect(fatigue(pitcher, "2026-06-10").fatigue_p).to eq(7)
    end

    it "通常 中4日 -3 → 4 / 中5日 -1 → 6 / 中6日 → 7" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      expect(fatigue(pitcher, "2026-06-06").fatigue_p).to eq(4) # 中4日
      expect(fatigue(pitcher, "2026-06-07").fatigue_p).to eq(6) # 中5日
      expect(fatigue(pitcher, "2026-06-08").fatigue_p).to eq(7) # 中6日
    end

    it "長イニング敗戦後 中4日 -4 → 3 / 中5日 -2 → 5 / 中6日 -1 → 6 / 中7日 → 7" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      expect([ "2026-06-06", "2026-06-07", "2026-06-08", "2026-06-09" ].map { |d| fatigue(pitcher, d).fatigue_p }).to eq([ 3, 5, 6, 7 ])
    end

    it "KO 後 中3日 -3 → 4 / 中4日 → 7" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 3.0, category: "ko")
      expect(fatigue(pitcher, "2026-06-05").fatigue_p).to eq(4)
      expect(fatigue(pitcher, "2026-06-06").fatigue_p).to eq(7)
    end

    it "中3日の通常は P0（置き換え）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      expect(fatigue(pitcher, "2026-06-05").fatigue_p).to eq(0)
    end

    it "中2日以内は登板不可として判定保留（rest_too_short）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      res = fatigue(pitcher, "2026-06-04") # 中2日
      expect(res.pending).to eq(:rest_too_short)
      expect(res.fatigue_p).to be_nil
    end

    it "result_category_overrides があれば保存済みの区分より優先する（試運転の連鎖用）" do
      prev = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "normal")
      expect(fatigue(pitcher, "2026-06-06").fatigue_p).to eq(4)
      expect(fatigue(pitcher, "2026-06-06", overrides: { prev.id => "long_loss" }).fatigue_p).to eq(3)
    end

    it "別チームでの登板は前登板に数えない" do
      other_team = create(:team)
      create_start(team: other_team, pitcher: pitcher, date: "2026-06-05", innings: 6.0)
      expect(fatigue(pitcher, "2026-06-06").fatigue_p).to eq(7)
    end
  end

  describe "中10日リフレッシュ（実日数差・離脱は関与しない。裁定 2026-09-13）" do
    let!(:pitcher_and_membership) { create_card_pitcher(team: team, starter_stamina: 7) }
    let(:pitcher) { pitcher_and_membership[0] }
    let(:membership) { pitcher_and_membership[1] }

    it "中9日は通常の表（中6日以上=カード値）、中10日は補正なし。長イニング敗戦でも中10日は補正なし" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      expect(fatigue(pitcher, "2026-06-11").fatigue_p).to eq(7) # 中9日: 長イニングの中7日以上=カード値
      expect(fatigue(pitcher, "2026-06-12").fatigue_p).to eq(7) # 中10日
    end

    it "離脱を挟んで実日数中10日なら、離脱控除後の中日数が短くても補正なし" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      # 6/2〜6/6 の 5 日離脱。実日数差 中10日（6/12 登板）、離脱控除後なら中5日(-1)になるところ
      create(:player_absence, team_membership: membership, season: season, start_date: Date.new(2026, 6, 2), duration: 5, duration_unit: "days")
      expect(fatigue(pitcher, "2026-06-12").fatigue_p).to eq(7)
    end

    it "実日数中9日 + 離脱 は離脱を引いた中日数で補正する（中10日に届かない）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      create(:player_absence, team_membership: membership, season: season, start_date: Date.new(2026, 6, 2), duration: 5, duration_unit: "days")
      # 実日数中9日(6/11)、離脱5日を引くと中4日 → -3
      expect(fatigue(pitcher, "2026-06-11").fatigue_p).to eq(4)
    end
  end

  # Test Basis: cmd_1775 第2段 E4（AMB-04「出場停止と負傷は別枠」2026-09-12）/ E5（AMB-04 追補・追補2）
  describe "離脱の種別と中10日の境（E4・E5）" do
    let!(:pitcher_and_membership) { create_card_pitcher(team: team, starter_stamina: 7) }
    let(:pitcher) { pitcher_and_membership[0] }
    let(:membership) { pitcher_and_membership[1] }

    def absence(type, start:, days:)
      create(:player_absence, team_membership: membership, season: season, absence_type: type,
                              start_date: Date.parse(start), duration: days, duration_unit: "days")
    end

    before { create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0) }

    it "E4: 負傷は中日数から引く（実日数中6日 - 負傷2日 = 中4日 → -3 → 4）" do
      absence(:injury, start: "2026-06-02", days: 2)
      expect(fatigue(pitcher, "2026-06-08").fatigue_p).to eq(4)
    end

    it "E4: 出場停止は引かない（同じ日付で中6日のままカード値 7）" do
      absence(:suspension, start: "2026-06-02", days: 2)
      expect(fatigue(pitcher, "2026-06-08").fatigue_p).to eq(7)
    end

    it "E4: 再調整も引かない" do
      absence(:reconditioning, start: "2026-06-02", days: 2)
      expect(fatigue(pitcher, "2026-06-08").fatigue_p).to eq(7)
    end

    it "E4: 出場停止で実日数中3日が中1日に短くならない（引かないので中3日 P0。負傷なら判定保留になる日数）" do
      absence(:suspension, start: "2026-06-02", days: 2)
      expect(fatigue(pitcher, "2026-06-05").fatigue_p).to eq(0)
    end

    it "E5: 実日数中9日は離脱を引いた中日数で補正する（負傷6日 → 中3日 P0）" do
      absence(:injury, start: "2026-06-02", days: 6)
      expect(fatigue(pitcher, "2026-06-11").fatigue_p).to eq(0) # 実日数 9 日 - 6 = 中3日
    end

    it "E5: 実日数中10日ちょうどでリセット（離脱の種別・長さを問わずカード値）" do
      absence(:injury, start: "2026-06-02", days: 6)
      expect(fatigue(pitcher, "2026-06-12").fatigue_p).to eq(7) # 実日数 10 日 → リセット
    end

    it "E5: 離脱が 10 日未満でも、実日数中10日ならリセットする（旧: 10日超の離脱が条件だった）" do
      absence(:injury, start: "2026-06-03", days: 3)
      expect(fatigue(pitcher, "2026-06-12").fatigue_p).to eq(7)
    end

    it "E5: 離脱が10日ちょうどで控除後 0 日でも、実日数中10日ならリセット成立（AMB-04 追補2。登板可・カード値）" do
      absence(:injury, start: "2026-06-02", days: 10)
      res = fatigue(pitcher, "2026-06-12")
      expect(res.pending).to be_nil
      expect(res.fatigue_p).to eq(7)
    end

    it "E5: 実日数中9日で離脱 10日は控除後 0 日 → 登板不可（リセット不成立）" do
      absence(:injury, start: "2026-06-02", days: 10)
      res = fatigue(pitcher, "2026-06-11")
      expect(res.pending).to eq(:rest_too_short)
    end
  end

  describe "前回がリリーフ/オープナー（§8.3.4。Operator 裁定追加 2026-10-25）" do
    it "通常選手は通常の先発の表（P6・中4日 -3 → 3）" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: 6)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 2.0, role: "reliever")
      expect([ "2026-06-05", "2026-06-06", "2026-06-07", "2026-06-08" ].map { |d| fatigue(pitcher, d).fatigue_p }).to eq([ 0, 3, 5, 6 ])
    end

    it "オープナー登板もリリーフとして扱う" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: 6)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 1.0, role: "opener")
      expect(fatigue(pitcher, "2026-06-06").fatigue_p).to eq(3)
    end

    context "スラッシュ選手（先発・リリーフ両方の疲労Pあり）: 直近リリーフ登板直後の累積イニングで表を選ぶ" do
      def slash_pitcher(relief_innings)
        pitcher, = create_card_pitcher(team: team, starter_stamina: 7, relief_stamina: 2)
        create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: relief_innings, role: "reliever")
        pitcher
      end

      it "累積2I以下: 中3日 -1 / 中4日以上 カード値" do
        pitcher = slash_pitcher(2.0)
        expect([ "2026-06-05", "2026-06-06", "2026-06-07" ].map { |d| fatigue(pitcher, d).fatigue_p }).to eq([ 6, 7, 7 ])
      end

      it "累積3I: 中3日 -3 / 中4日 -1 / 中5日以上 カード値" do
        pitcher = slash_pitcher(3.0)
        expect([ "2026-06-05", "2026-06-06", "2026-06-07", "2026-06-08" ].map { |d| fatigue(pitcher, d).fatigue_p }).to eq([ 4, 6, 7, 7 ])
      end

      it "累積4I以上: 中3日 P0 / 中4日 -3 / 中5日 -1 / 中6日以上 カード値" do
        pitcher = slash_pitcher(4.0)
        expect([ "2026-06-05", "2026-06-06", "2026-06-07", "2026-06-08" ].map { |d| fatigue(pitcher, d).fatigue_p }).to eq([ 0, 4, 6, 7 ])
      end

      it "中2日以内は登板不可として判定保留" do
        expect(fatigue(slash_pitcher(2.0), "2026-06-04").pending).to eq(:rest_too_short)
      end

      it "中10日以上空いていれば補正なし" do
        expect(fatigue(slash_pitcher(4.0), "2026-06-12").fatigue_p).to eq(7)
      end
    end
  end
end
