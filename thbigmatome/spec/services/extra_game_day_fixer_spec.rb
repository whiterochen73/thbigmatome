require "rails_helper"

# Test Basis: cmd_1802 段3（subtask_1802b）。Operator 決定 2026-11-02:
#   (1) 日程マスタの 2016-09-26（schedule_details id 186）は予備日（reserve_day）にする
#   (2) 日程マスタと、9/26 が試合日（game_day）の既存シーズンも書き換える。前橋（9/26 に結果・登板がある）はそのまま
# 調査: context/thbig-dugout-schedule-extra-game-day.md（余分な 1 日は 9/26。波及は前橋 1 件のみ）。
RSpec.describe ExtraGameDayFixer, :pitcher_fatigue do
  let(:date) { described_class::DATE }

  # 日程マスタ: 9/25 試合日・9/26 試合日（余分な日）・9/27 予備日。ほかの試合日 3 日（9/22〜24）
  let!(:master) do
    Schedule.create!(name: "マスタ", start_date: Date.new(2016, 9, 22), end_date: Date.new(2016, 9, 27)).tap do |s|
      %w[game_day game_day game_day game_day game_day reserve_day].each_with_index { |type, i| s.schedule_details.create!(date: Date.new(2016, 9, 22) + i, date_type: type) }
    end
  end

  def new_season(team: create(:team))
    create(:season, team: team).tap do |season|
      master.schedule_details.order(:date).each { |d| create(:season_schedule, season: season, date: d.date, date_type: d.date_type) }
    end
  end

  def on_926(season) = SeasonSchedule.find_by!(season: season, date: date)

  let!(:season) { new_season }
  let!(:other_season) { new_season }

  def fix = described_class.new.call

  it "マスタは 2016-09-26 の試合日。ほかの日は触らない" do
    expect(date).to eq(Date.new(2016, 9, 26))
    rows = fix.rows.select { |r| r.kind == "master" }

    expect(rows.size).to eq(1)
    expect(rows.first).to have_attributes(date: date, old_date_type: "game_day", new_date_type: "reserve_day", status: :fix)
  end

  it "9/26 が試合日の空のシーズンは全部直す対象にする" do
    fixer = fix

    expect(fixer.rows.select { |r| r.kind == "season" && r.status == :fix }.map(&:season_id)).to contain_exactly(season.id, other_season.id)
    expect(fixer.summary).to eq(master_fix: 1, season_fix: 2, season_keep: 0)
  end

  describe "試運転" do
    it "call は DB を書かない" do
      fix

      expect(on_926(season).date_type).to eq("game_day")
      expect(master.schedule_details.find_by!(date: date).date_type).to eq("game_day")
    end
  end

  describe "apply!" do
    it "マスタと既存シーズンの 9/26 を予備日にする。ほかの日の種別・シーズンの updated_at は動かさない" do
      before_other = SeasonSchedule.where.not(date: date).order(:id).pluck(:id, :date_type, :updated_at)
      before_updated = on_926(season).updated_at

      fix.apply!

      expect(master.schedule_details.find_by!(date: date).date_type).to eq("reserve_day")
      expect(on_926(season).date_type).to eq("reserve_day")
      expect(on_926(other_season).date_type).to eq("reserve_day")
      expect(on_926(season).updated_at).to eq(before_updated)
      expect(SeasonSchedule.where.not(date: date).order(:id).pluck(:id, :date_type, :updated_at)).to eq(before_other)
    end

    it "9/26 を外した後、レギュラーの総数は 1 減る（マスタの試合日 5 → 4）" do
      expect { fix.apply! }.to change { SeasonGameProgress.by_team_id.fetch(season.team_id).regular_total }.from(5).to(4)
    end

    it "2 回目は対象 0 件（連打しても同じ結果）" do
      fix.apply!
      again = fix

      expect(again.rows).to be_empty
      expect { again.apply! }.not_to(change { SeasonSchedule.pluck(:id, :date_type) })
    end
  end

  describe "実物と同じ形（レギュラーの試合日 144 日・9/26 が最後の通常試合日）" do
    it "9/26 を直すと、マスタのレギュラーの試合日もシーズンの総数も 144 → 143 になる" do
      big = Schedule.create!(name: "実物形", start_date: date - 143, end_date: date)
      (0..143).each { |i| big.schedule_details.create!(date: date - 143 + i, date_type: "game_day") }
      big_season = create(:season, team: create(:team))
      big.schedule_details.order(:date).each { |d| create(:season_schedule, season: big_season, date: d.date, date_type: d.date_type) }
      expect(ScheduleMasterCheck.regular_game_days(big)).to eq(144)
      expect(SeasonGameProgress.by_team_id.fetch(big_season.team_id).regular_total).to eq(144)

      fix.apply!

      expect(ScheduleMasterCheck.regular_game_days(big)).to eq(143)
      expect(ScheduleMasterCheck.warnings(big)).to eq([])
      expect(SeasonGameProgress.by_team_id.fetch(big_season.team_id).regular_total).to eq(143)
    end
  end

  describe "結果・登板のある行は除外して一覧に出す（前橋）" do
    let!(:maebashi_team) { create(:team, name: "前橋") }
    let!(:maebashi) { new_season(team: maebashi_team) }

    it "得点が入った行は直さず、keep として理由つきで出す" do
      on_926(maebashi).update!(score: 3, opponent_score: 1)
      fixer = fix

      keep = fixer.rows.find { |r| r.season_id == maebashi.id }
      expect(keep).to have_attributes(status: :keep, team_id: maebashi_team.id)
      expect(keep.reasons).to include(:score, :opponent_score)
      expect(fixer.summary).to eq(master_fix: 1, season_fix: 2, season_keep: 1)

      fixer.apply!
      expect(on_926(maebashi)).to have_attributes(date_type: "game_day", score: 3)
    end

    it "登板記録（pitcher_game_states）だけがある行も直さない" do
      pitcher = create_card_pitcher(team: maebashi_team, starter_stamina: 7)[0]
      create_start(team: maebashi_team, pitcher: pitcher, date: date, innings: 5.0)

      keep = fix.rows.find { |r| r.season_id == maebashi.id }
      expect(keep).to have_attributes(status: :keep, pitcher_count: 1)
      expect(keep.reasons).to include(:pitcher_game_states)
    end

    it "日程の行に紐づいた登板（season_schedule_id）は、schedule_date が別の日付でも痕跡に数える" do
      pitcher = create_card_pitcher(team: maebashi_team, starter_stamina: 7)[0]
      state = create_start(team: maebashi_team, pitcher: pitcher, date: Date.new(2016, 9, 1), innings: 5.0)
      state.update!(season_schedule_id: on_926(maebashi).id)

      expect(fix.rows.find { |r| r.season_id == maebashi.id }).to have_attributes(status: :keep, pitcher_count: 1)
    end

    %i[opponent_team_id announced_starter_id game_log real_date venue].each do |column|
      it "#{column} だけが入っている行も直さない（入力の痕跡を消さない）" do
        value = case column
        when :opponent_team_id then create(:team).id
        when :announced_starter_id then create(:team_membership, team: maebashi_team, player: create(:player)).id
        when :game_log then "ログ"
        when :real_date then date
        when :venue then "ch1"
        end
        on_926(maebashi).update!(column => value)

        expect(fix.rows.find { |r| r.season_id == maebashi.id }).to have_attributes(status: :keep)
      end
    end

    it "ノーゲームが立っている行も直さない" do
      on_926(maebashi).update!(no_game: true)

      expect(fix.rows.find { |r| r.season_id == maebashi.id }.reasons).to include(:no_game)
    end

    it "前橋が残っていても、2 回目に直す対象は 0 件（keep だけが一覧に残る）" do
      on_926(maebashi).update!(score: 3, opponent_score: 1)
      fix.apply!

      again = fix
      expect(again.summary).to eq(master_fix: 0, season_fix: 0, season_keep: 1)
      expect(again.rows.map(&:status).uniq).to eq([ :keep ])
    end
  end

  describe "対象外の行" do
    it "9/26 が試合日以外の種別のシーズン（移動日・予備日など）は触らない" do
      other_season2 = new_season
      on_926(other_season2).update!(date_type: "travel_day")

      fixer = fix
      expect(fixer.rows.map(&:season_id).compact).not_to include(other_season2.id)
      fixer.apply!
      expect(on_926(other_season2).date_type).to eq("travel_day")
    end

    it "別の日付の試合日は触らない（9/25・9/27 以外の日の game_day を残す）" do
      fix.apply!

      expect(SeasonSchedule.where(date: Date.new(2016, 9, 25)).pluck(:date_type).uniq).to eq([ "game_day" ])
    end
  end

  describe "チームを絞る" do
    it "TEAM_ID で絞るとそのチームのシーズンだけを対象にし、マスタは対象にしない" do
      fixer = described_class.new(team_id: season.team_id).call

      expect(fixer.rows.map(&:kind).uniq).to eq([ "season" ])
      expect(fixer.rows.map(&:season_id)).to eq([ season.id ])
    end
  end

  describe "revert!（変更前の値の CSV から戻す）" do
    def csv_rows(fixer)
      fixer.rows.map { |r| r.to_csv_h.stringify_keys }
    end

    it "今の値が new_date_type と一致する行だけ old_date_type に戻す。食い違う行は戻さず返す" do
      fixer = fix
      rows = csv_rows(fixer)
      fixer.apply!
      on_926(other_season).update!(date_type: "game_day") # 画面で試合日に戻した（new と食い違う）

      result = described_class.revert!(rows.select { |r| r["status"] == "fix" })

      expect(result[:reverted]).to eq(2) # マスタ 1 + season 1
      expect(result[:skipped]).to eq([ [ "season", on_926(other_season).id ] ])
      expect(master.schedule_details.find_by!(date: date).date_type).to eq("game_day")
      expect(on_926(season).date_type).to eq("game_day")
    end

    it "往復すると、マスタ・シーズンの全列（updated_at を含む）が元の値に完全に戻る" do
      snapshot = -> { [ ScheduleDetail.order(:id).map(&:attributes), SeasonSchedule.order(:id).map(&:attributes) ] }
      before = snapshot.call
      fixer = fix
      rows = csv_rows(fixer)
      fixer.apply!
      expect(snapshot.call).not_to eq(before)

      described_class.revert!(rows.select { |r| r["status"] == "fix" })

      expect(snapshot.call).to eq(before)
    end

    it "戻した後にもう一度流すと、また同じ対象になる（往復できる）" do
      fixer = fix
      rows = csv_rows(fixer)
      fixer.apply!
      described_class.revert!(rows.select { |r| r["status"] == "fix" })

      expect(fix.summary).to eq(master_fix: 1, season_fix: 2, season_keep: 0)
    end
  end
end
