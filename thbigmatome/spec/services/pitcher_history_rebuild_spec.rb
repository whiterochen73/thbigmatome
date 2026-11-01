require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §4.5（PitcherHistoryRebuild.from(team_id:, date:)）・§1.3 S8。
# 疲労P などの保存値の作り直しは、この入口の 1 本。日付・投手で範囲を絞る。範囲の外は触らない。
RSpec.describe PitcherHistoryRebuild, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let!(:other) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  # 6/1 → 6/7（中5日）の先発 2 件。保存値はわざと古い値（疲労P 0）にしてある
  # 正しい値: 6/1 は 7（前の登板なし）、6/7 は 6（前が normal・中5日で -1）
  def seed(for_pitcher, dates: %w[2026-06-01 2026-06-07])
    dates.map do |date|
      create_schedule(season, date, score: 0, opponent_score: 1) unless SeasonSchedule.of_team_on(team.id, date).exists?
      create_start(team: team, pitcher: for_pitcher, date: date, innings: 5.0, category: "normal", fatigue_p_used: 0)
    end
  end

  describe ".from" do
    it "日付も投手も渡さなければ全期間・全投手を作り直す" do
      mine = seed(pitcher)
      theirs = seed(other)
      described_class.from(team_id: team.id)
      expect((mine + theirs).map { |s| s.reload.fatigue_p_used }).to eq([ 7, 6, 7, 6 ])
    end

    it "date 以降の登板だけを作り直す（それより前は触らず、前登板として DB の値を読む）" do
      first, second = seed(pitcher)
      described_class.from(team_id: team.id, date: Date.new(2026, 6, 7))
      expect(first.reload.fatigue_p_used).to eq(0)
      expect(second.reload.fatigue_p_used).to eq(6)
    end

    it "date は含む（その日の登板も作り直す）" do
      first, second = seed(pitcher)
      described_class.from(team_id: team.id, date: "2026-06-01")
      expect([ first, second ].map { |s| s.reload.fatigue_p_used }).to eq([ 7, 6 ])
    end

    it "pitcher_ids で投手を絞る" do
      mine = seed(pitcher)
      theirs = seed(other)
      described_class.from(team_id: team.id, pitcher_ids: [ pitcher.id ])
      expect(mine.map { |s| s.reload.fatigue_p_used }).to eq([ 7, 6 ])
      expect(theirs.map { |s| s.reload.fatigue_p_used }).to eq([ 0, 0 ])
    end

    it "pitcher_ids が空配列なら誰も作り直さない（nil = 絞らない、とは別）" do
      mine = seed(pitcher)
      described_class.from(team_id: team.id, pitcher_ids: [])
      expect(mine.map { |s| s.reload.fatigue_p_used }).to eq([ 0, 0 ])
    end

    it "別のチームの登板は作り直さない" do
      other_team, other_season = create_team_with_season
      other_pitcher = create_card_pitcher(team: other_team, starter_stamina: 7)[0]
      create_schedule(other_season, "2026-06-01", score: 0, opponent_score: 1)
      foreign = create_start(team: other_team, pitcher: other_pitcher, date: "2026-06-01", innings: 5.0, fatigue_p_used: 0)
      seed(pitcher)
      described_class.from(team_id: team.id)
      expect(foreign.reload.fatigue_p_used).to eq(0)
    end

    it "リリーフの登板は作り直さない（保存値を使わない）" do
      create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
      relief = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 1.0, role: "reliever", fatigue_p_used: 0)
      described_class.from(team_id: team.id)
      expect(relief.reload.fatigue_p_used).to eq(0)
    end

    it "試運転(apply: false)は DB を書かず、作り直す行を返す" do
      first, = seed(pitcher)
      rebuilder = described_class.from(team_id: team.id, apply: false)
      expect(first.reload.fatigue_p_used).to eq(0)
      expect(rebuilder.rows.size).to eq(2)
      expect(rebuilder.rows.first.new_fatigue_p).to eq(7)
    end

    it "離脱が入っていれば、中日数から引いた疲労P になる（負傷 1 日で中4日 → -3 で P4）" do
      _first, second = seed(pitcher)
      create(:player_absence, team_membership: pitcher_membership, season: season, start_date: "2026-06-02", duration: 1, duration_unit: "days")
      described_class.from(team_id: team.id, pitcher_ids: [ pitcher.id ])
      expect(second.reload.fatigue_p_used).to eq(4)
    end

    it "得点が未入力の試合は変えない（unscored: :skip）。:not_loss なら負けではないとして作り直す" do
      create_schedule(season, "2026-06-01")
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 9.0, category: "long_loss", fatigue_p_used: 0)
      described_class.from(team_id: team.id)
      expect(state.reload.result_category).to eq("long_loss")
      described_class.from(team_id: team.id, unscored: :not_loss)
      expect(state.reload.result_category).to eq("normal")
    end
  end

  describe ".guarded" do
    it "成功したら error なし・rebuilder を返す" do
      seed(pitcher)
      outcome = described_class.guarded(team_id: team.id)
      expect(outcome).to be_ok
      expect(outcome.rebuilder.rows.size).to eq(2)
    end

    it "失敗しても例外を上げず error に持ち、ログに残す" do
      allow_any_instance_of(PitcherResultCategoryRebuilder).to receive(:rebuild_from).and_raise(RuntimeError, "boom")
      allow(Rails.logger).to receive(:error)
      outcome = described_class.guarded(team_id: team.id, date: Date.new(2026, 6, 1), pitcher_ids: [ pitcher.id ])
      expect(outcome).not_to be_ok
      expect(outcome.error).to be_a(RuntimeError)
      expect(outcome.rebuilder).to be_nil
      expect(Rails.logger).to have_received(:error).with(/PitcherHistoryRebuild.*team_id: #{team.id}.*#{pitcher.id}.*RuntimeError.*boom/m)
    end

    it "DB エラーで落ちても、親のトランザクションは生きていて、途中の書き込みだけが戻る" do
      first, = seed(pitcher)
      allow_any_instance_of(PitcherResultCategoryRebuilder).to receive(:rebuild_from) do
        first.update_columns(fatigue_p_used: 99)
        ActiveRecord::Base.connection.execute("SELECT * FROM table_that_does_not_exist")
      end
      ApplicationRecord.transaction do
        outcome = described_class.guarded(team_id: team.id)
        expect(outcome).not_to be_ok
        expect(Team.find(team.id)).to eq(team) # 中断状態なら、この問い合わせが落ちる
      end
      expect(first.reload.fatigue_p_used).to eq(0)
    end
  end

  describe ".failure_message" do
    it "例外クラスを含む警告文にする" do
      expect(described_class.failure_message(RuntimeError.new("x"))).to include("作り直しに失敗", "RuntimeError")
    end
  end

  def pitcher_membership
    TeamMembership.find_by!(team: team, player: pitcher)
  end
end
