require "rails_helper"

# Test Basis: cmd_1775 E1・E2・過去分の作り直し / Operator 裁定 2026-10-25 #1〜#6
RSpec.describe PitcherResultCategoryRebuilder, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  def rebuild(**opts)
    described_class.new(apply: true, **opts)
  end

  describe "E2: 得点の変更で作り直す（rebuild_for_schedule）" do
    it "負け→勝ちに直すと long_loss が normal に作り直される" do
      schedule = create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "long_loss")
      schedule.update!(score: 6, opponent_score: 5)
      expect(state.reload.result_category).to eq("normal")
    end

    it "勝ち（未入力）→負けに直すと normal が long_loss に作り直される（疲労P7 で 9回）" do
      schedule = create_schedule(season, "2026-06-10")
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "normal")
      schedule.update!(score: 1, opponent_score: 2)
      expect(state.reload.result_category).to eq("long_loss")
      expect(state.fatigue_p_used).to eq(7)
    end

    it "KO も得点の変更で作り直される（負け+L+後続あり → ko、勝ちに直すと normal）" do
      schedule = create_schedule(season, "2026-06-10", score: 0, opponent_score: 3)
      game = create(:game)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 3.0, category: "ko", decision: "L", game: game)
      create_start(team: team, pitcher: create(:player, :pitcher), date: "2026-06-10", innings: 6.0, role: "reliever", game: game, appearance_order: 1)
      schedule.update!(score: 4, opponent_score: 3)
      expect(state.reload.result_category).to eq("normal")
    end

    it "得点以外の変更では作り直さない（スタジアム変更など）" do
      schedule = create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "normal") # 古い誤り値
      schedule.update!(stadium: "どこか")
      expect(state.reload.result_category).to eq("normal")
    end

    it "得点が消された（未入力に戻った）時は負けではないとして normal にする" do
      schedule = create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "long_loss")
      schedule.update!(score: nil, opponent_score: nil)
      expect(state.reload.result_category).to eq("normal")
    end

    it "区分が変わると次の登板の補正も連鎖して作り直される（波及は変わらなくなった所で止まる）" do
      schedule = create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
      create_schedule(season, "2026-06-06", score: 0, opponent_score: 1)
      create_schedule(season, "2026-06-11", score: 0, opponent_score: 1)
      first = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      # 6/6 は中4日。前が long_loss なら補正 -4 → P3、normal なら -3 → P4。5.1回(関与6)負けは P3 なら long_loss、P4 なら normal
      second = create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 5.1, category: "long_loss")
      # 6/11 は中4日。前が normal なら P4 で 5.0 回は normal、long_loss(P3)でも 5.0 回 → 5 > 4 で long_loss
      third = create_start(team: team, pitcher: pitcher, date: "2026-06-11", innings: 3.0, category: "normal")

      # 6/1 を勝ちに直す → first: normal / second: P4 で 5.1回(関与6 > 5) → long_loss のまま / ...
      schedule.update!(score: 3, opponent_score: 1)
      expect(first.reload.result_category).to eq("normal")
      # second は P4（中4日 -3）、関与6 > 4+1 → long_loss。変わらないので波及はここで止まる
      expect(second.reload.result_category).to eq("long_loss")
      expect(second.fatigue_p_used).to eq(4)
      expect(third.reload.fatigue_p_used).to eq(0) # 止まった所より後は触らない
    end
  end

  describe "過去分の作り直し（rebuild_all）" do
    it "試運転(apply: false)は DB を書かず、変わる件数を数える" do
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0, category: "long_loss") # 旧: 既定3で付いた誤り
      rebuilder = described_class.new(apply: false)
      rebuilder.rebuild_all
      expect(rebuilder.summary[:changed]).to eq(1)
      expect(state.reload.result_category).to eq("long_loss")
      expect(state.fatigue_p_used).to eq(0)
    end

    it "apply: true で書く（疲労P7・5.0回・負け → normal、fatigue_p_used=7）" do
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0, category: "long_loss")
      rebuild.rebuild_all
      expect(state.reload).to have_attributes(result_category: "normal", fatigue_p_used: 7)
    end

    it "日付順の連鎖: 前登板の作り直しが次の補正に効く（試運転でも同じ連鎖を再現する）" do
      create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
      create_schedule(season, "2026-06-06", score: 0, opponent_score: 1)
      # 6/1: 疲労P7 で 8.0回・負け → normal（旧: 既定3 で long_loss と誤記録されていた）
      first = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      # 6/6: 中4日。前が normal(作り直し後) なら P4、前が long_loss のままなら P3（-4）。使った疲労P の違いで連鎖を見る
      second = create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 4.1, category: "normal")

      dry = described_class.new(apply: false)
      dry.rebuild_all
      rows = dry.rows.index_by(&:state_id)
      expect(rows[first.id]).to have_attributes(status: :changed, old_category: "long_loss", new_category: "normal", new_fatigue_p: 7)
      # 作り直した値（normal）を使って P4 になる。long_loss のままなら P3
      expect(rows[second.id].new_fatigue_p).to eq(4)
      expect(first.reload.result_category).to eq("long_loss")

      rebuild.rebuild_all
      expect(second.reload.fatigue_p_used).to eq(4)
    end

    it "得点が未入力の試合は変えず、件数に出す" do
      create_schedule(season, "2026-06-10")
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "long_loss")
      r = rebuild
      r.rebuild_all
      expect(r.summary[:skipped_unscored]).to eq(1)
      expect(state.reload.result_category).to eq("long_loss")
    end

    it "試合概要が無い記録は変えず、件数に出す" do
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "long_loss")
      r = rebuild
      r.rebuild_all
      expect(r.summary[:skipped_no_schedule]).to eq(1)
      expect(state.reload.result_category).to eq("long_loss")
    end

    it "カード未特定の投手は変えず pending に数える（既定3 にしない）" do
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      no_card_pitcher, = create_card_pitcher(team: team, starter_stamina: 7, with_card: false)
      state = create_start(team: team, pitcher: no_card_pitcher, date: "2026-06-10", innings: 5.0, category: "long_loss")
      r = rebuild
      r.rebuild_all
      expect(r.summary[:pending]).to eq(1)
      expect(r.rows.first.reason).to eq(:card_not_identified)
      expect(state.reload.result_category).to eq("long_loss")
    end

    it "ノーゲームの記録は変えない" do
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 3.0, category: "no_game")
      r = rebuild
      r.rebuild_all
      expect(r.summary[:skipped_no_game]).to eq(1)
      expect(state.reload.result_category).to eq("no_game")
    end

    it "TEAM 指定で他チームを触らない" do
      other_team, other_season = create_team_with_season
      other_pitcher, = create_card_pitcher(team: other_team, starter_stamina: 7)
      create_schedule(other_season, "2026-06-10", score: 2, opponent_score: 5)
      other_state = create_start(team: other_team, pitcher: other_pitcher, date: "2026-06-10", innings: 5.0, category: "long_loss")
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0, category: "long_loss")
      rebuild.rebuild_all(team_id: team.id)
      expect(other_state.reload.result_category).to eq("long_loss")
    end

    it "リリーフ登板は対象外（先発のみ作り直す）" do
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      relief = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 3.0, role: "reliever", category: "normal")
      r = rebuild
      r.rebuild_all
      expect(r.rows).to be_empty
      expect(relief.reload.result_category).to eq("normal")
    end

    it "第二先発(role=starter)の関与イニングは同じ試合の前の投手のアウト数から出す（前が1回1/3 → 6.2回で関与7）" do
      create_schedule(season, "2026-06-10", score: 2, opponent_score: 5)
      game = create(:game)
      opener_pitcher = create(:player, :pitcher)
      create_start(team: team, pitcher: opener_pitcher, date: "2026-06-10", innings: 1.1, role: "opener", game: game, appearance_order: 0)
      second_pitcher, = create_card_pitcher(team: team, starter_stamina: 5) # 閾値 6。関与7 > 6 → long_loss（innings だけなら 6.2 > 6 でも long_loss なので、疲労6で区別）
      second_pitcher2, = create_card_pitcher(team: team, starter_stamina: 6) # 閾値 7。関与7 > 7 は偽 → normal（6.2 > 7 も偽）
      s1 = create_start(team: team, pitcher: second_pitcher, date: "2026-06-10", innings: 6.2, role: "starter", game: game, appearance_order: 1)
      s2 = create_start(team: team, pitcher: second_pitcher2, date: "2026-06-10", innings: 6.2, role: "starter", game: game, appearance_order: 2, category: "long_loss")
      rebuild.rebuild_all
      # s1: prior_outs=4（opener 1.1）→ 入った回2 → 終了8 → 関与7 > 5+1 → long_loss
      expect(s1.reload.result_category).to eq("long_loss")
      # s2: prior_outs=4+20=24 → 入った回9、6.2回(20アウト) → 終了 floor(43/3)+1=15 → 関与7。7 > 6+1 偽 → normal
      expect(s2.reload.result_category).to eq("normal")
    end
  end

  # Test Basis: cmd_1775 第2段 E3（過去分の連続中4日カウントを同じ規則で埋め直す）/ E4
  describe "連続中4日カウントの作り直し（E3）" do
    def starts(dates)
      dates.map { |d| create_start(team: team, pitcher: pitcher, date: d, innings: 6.0, consecutive_short_rest_count: 0) }
    end

    it "日付順に 0 → 1 → 2 → 0 を書く（中4日 / 中4日 / 中8日）。試合概要が無くて区分を作り直せない行でも、カウントは埋める" do
      s1, s2, s3, s4 = starts(%w[2026-06-01 2026-06-06 2026-06-11 2026-06-20])
      r = rebuild
      r.rebuild_all
      expect([ s1, s2, s3, s4 ].map { |s| s.reload.consecutive_short_rest_count }).to eq([ 0, 1, 2, 0 ])
      expect(r.rows.map(&:status).uniq).to eq([ :skipped_no_schedule ])
    end

    it "試運転(apply: false)は DB を書かず、作り直した前回値を次のカウントに使う（連鎖: 0 → 1 → 2）" do
      s1, s2, s3 = starts(%w[2026-06-01 2026-06-06 2026-06-11])
      dry = described_class.new(apply: false)
      dry.rebuild_all
      rows = dry.rows.index_by(&:state_id)
      expect([ rows[s1.id], rows[s2.id], rows[s3.id] ].map(&:new_consecutive_short_rest_count)).to eq([ 0, 1, 2 ])
      expect([ rows[s1.id], rows[s2.id], rows[s3.id] ].map(&:old_consecutive_short_rest_count)).to eq([ 0, 0, 0 ])
      expect([ s2, s3 ].map { |s| s.reload.consecutive_short_rest_count }).to eq([ 0, 0 ])
    end

    it "保存済みの誤った値（本番は全件 0 のほか、古い値が残る行）も規則どおりに直す" do
      s1, s2 = starts(%w[2026-06-01 2026-06-08]) # 中6日
      s2.update!(consecutive_short_rest_count: 3)
      rebuild.rebuild_all
      expect(s2.reload.consecutive_short_rest_count).to eq(0)
      expect(s1.reload.consecutive_short_rest_count).to eq(0)
    end

    it "出場停止を挟んだ中日数は控除しない（中5日 → 0）/ 負傷は控除する（中4日 → +1）" do
      membership = TeamMembership.find_by(team_id: team.id, player_id: pitcher.id)
      s1, s2, s3 = starts(%w[2026-06-01 2026-06-07 2026-06-17])
      create(:player_absence, team_membership: membership, season: season, absence_type: :suspension,
                              start_date: Date.new(2026, 6, 2), duration: 1, duration_unit: "days")
      create(:player_absence, team_membership: membership, season: season, absence_type: :injury,
                              start_date: Date.new(2026, 6, 8), duration: 5, duration_unit: "days")
      rebuild.rebuild_all
      # 6/1 → 6/7: 実日数中5日、出場停止 1 日は引かない → 0
      expect(s2.reload.consecutive_short_rest_count).to eq(0)
      # 6/7 → 6/17: 実日数中9日 - 負傷 5 日 = 中4日 → 前回 0 + 1
      expect(s3.reload.consecutive_short_rest_count).to eq(1)
      expect(s1.reload.consecutive_short_rest_count).to eq(0)
    end

    it "リリーフ登板は対象外のまま（先発のみ）" do
      relief = create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 1.0, role: "reliever", consecutive_short_rest_count: 2)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 6.0)
      rebuild.rebuild_all
      expect(relief.reload.consecutive_short_rest_count).to eq(2)
    end

    it "得点（区分の作り直し）とカウントは独立: 区分が unchanged でもカウントは書く" do
      create_schedule(season, "2026-06-01", score: 3, opponent_score: 1)
      create_schedule(season, "2026-06-06", score: 3, opponent_score: 1)
      starts(%w[2026-06-01 2026-06-06])
      r = rebuild
      r.rebuild_all
      second = r.rows.find { |row| row.schedule_date == "2026-06-06" }
      expect(second.new_consecutive_short_rest_count).to eq(1)
      expect(PitcherGameState.find(second.state_id).consecutive_short_rest_count).to eq(1)
    end
  end
end
