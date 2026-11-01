require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §4.2（pitcher_game_states.season_schedule_id）・§5.2 段3・§1.3 S12。
# 登板を日程の行に直接紐づけ、読みも書きもその列にそろえる。境界: 日程の行が無い日・同じ日に複数・別チームの同じ日・日付が読めない。
RSpec.describe PitcherGameState, "日程の行への紐づけ", :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  def save_start(date, **opts)
    create_start(team: team, pitcher: pitcher, date: date, innings: 5.0, **opts)
  end

  describe "保存時の紐づけ" do
    it "（チーム, 試合日）の日程の行が 1 件なら、その行の id を入れる" do
      schedule = create_schedule(season, "2026-06-10")
      expect(save_start("2026-06-10").season_schedule_id).to eq(schedule.id)
    end

    it "日程の行が無い日付は紐づけず nil のまま保存する（行は作らない）" do
      create_schedule(season, "2026-06-10")
      state = nil
      expect { state = save_start("2026-06-20") }.not_to change(SeasonSchedule, :count)
      expect(state.season_schedule_id).to be_nil
      expect(state).to be_persisted
    end

    it "同じ日に日程の行が複数あれば決められないので nil（ダブルヘッダ等）" do
      create_schedule(season, "2026-06-10")
      create_schedule(season, "2026-06-10")
      expect(save_start("2026-06-10").season_schedule_id).to be_nil
    end

    it "別のチームの同じ日の日程の行には紐づかない" do
      _other_team, other_season = create_team_with_season
      create_schedule(other_season, "2026-06-10")
      expect(save_start("2026-06-10").season_schedule_id).to be_nil
    end

    it "試合日の日付が読めなければ nil（保存は止めない）" do
      create_schedule(season, "2026-06-10")
      state = create(:pitcher_game_state, team: team, pitcher: pitcher, schedule_date: "not-a-date", role: "starter")
      expect(state.season_schedule_id).to be_nil
    end

    it "試合日（schedule_date）を変えて保存すると、紐づけも引き直す" do
      first = create_schedule(season, "2026-06-10")
      second = create_schedule(season, "2026-06-11")
      state = save_start("2026-06-10")
      expect(state.season_schedule_id).to eq(first.id)
      state.update!(schedule_date: "2026-06-11")
      expect(state.season_schedule_id).to eq(second.id)
      state.update!(schedule_date: "2026-07-30")
      expect(state.season_schedule_id).to be_nil
    end

    it "試合日を変えない保存では紐づけを引き直さない（rake が埋めた値・手で直した値を保つ）" do
      schedule = create_schedule(season, "2026-06-10")
      state = save_start("2026-06-10")
      other = create_schedule(season, "2026-06-12")
      state.update_columns(season_schedule_id: other.id)
      state.update!(earned_runs: 3)
      expect(state.reload.season_schedule_id).to eq(other.id)
      expect(schedule.id).not_to eq(other.id)
    end

    it "season_schedule_id を明示した保存はその値を使う" do
      create_schedule(season, "2026-06-10")
      other = create_schedule(season, "2026-06-12")
      state = create(:pitcher_game_state, team: team, pitcher: pitcher, schedule_date: "2026-06-10", season_schedule_id: other.id)
      expect(state.season_schedule_id).to eq(other.id)
    end
  end

  describe ".schedule_id_for" do
    it "ノーゲームの日・移動日・プレーオフの日でも日程の行が 1 件なら返す（種別は問わない）" do
      no_game = create(:season_schedule, season: season, date: "2026-06-10", date_type: "no_game_day", no_game: true)
      travel = create(:season_schedule, season: season, date: "2026-06-11", date_type: "travel_day")
      playoff = create(:season_schedule, season: season, date: "2026-06-12", date_type: "playoff_day")
      expect(described_class.schedule_id_for(team_id: team.id, date: "2026-06-10")).to eq(no_game.id)
      expect(described_class.schedule_id_for(team_id: team.id, date: Date.new(2026, 6, 11))).to eq(travel.id)
      expect(described_class.schedule_id_for(team_id: team.id, date: "2026-06-12")).to eq(playoff.id)
    end

    it "nil・空文字は nil" do
      expect(described_class.schedule_id_for(team_id: team.id, date: nil)).to be_nil
      expect(described_class.schedule_id_for(team_id: team.id, date: "")).to be_nil
    end
  end

  describe ".on_day" do
    it "紐づいている登板を引く（その日の登板だけ）" do
      create_schedule(season, "2026-06-10")
      create_schedule(season, "2026-06-11")
      mine = save_start("2026-06-10")
      save_start("2026-06-11")
      expect(described_class.on_day(team_id: team.id, date: "2026-06-10")).to contain_exactly(mine)
    end

    it "紐づけをまだ入れていない登板（rake の前）は schedule_date で拾う" do
      create_schedule(season, "2026-06-10")
      state = save_start("2026-06-10")
      state.update_columns(season_schedule_id: nil)
      expect(described_class.on_day(team_id: team.id, date: "2026-06-10")).to contain_exactly(state)
    end

    it "別の日程の行に紐づく登板は、schedule_date が同じでも拾わない（紐づけが正）" do
      create_schedule(season, "2026-06-10")
      other = create_schedule(season, "2026-06-11")
      state = save_start("2026-06-10")
      state.update_columns(season_schedule_id: other.id)
      expect(described_class.on_day(team_id: team.id, date: "2026-06-10")).to be_empty
      expect(described_class.on_day(team_id: team.id, date: "2026-06-11")).to contain_exactly(state)
    end

    it "日程の行が無い日・複数ある日は schedule_date だけで引く" do
      lone = save_start("2026-06-20")
      expect(described_class.on_day(team_id: team.id, date: "2026-06-20")).to contain_exactly(lone)
      create_schedule(season, "2026-06-21")
      create_schedule(season, "2026-06-21")
      twin = save_start("2026-06-21")
      expect(described_class.on_day(team_id: team.id, date: "2026-06-21")).to contain_exactly(twin)
    end

    it "紐づけが空の登板でも、別の日付のものは拾わない" do
      create_schedule(season, "2026-06-10")
      create_schedule(season, "2026-06-11")
      elsewhere = save_start("2026-06-11")
      elsewhere.update_columns(season_schedule_id: nil)
      expect(described_class.on_day(team_id: team.id, date: "2026-06-10")).to be_empty
    end

    it "同じ日に日程の行が複数ある日は、どちらの行に紐づいた登板も拾う（日付で引く）" do
      create_schedule(season, "2026-06-21")
      second = create_schedule(season, "2026-06-21")
      state = save_start("2026-06-21")
      state.update_columns(season_schedule_id: second.id)
      expect(described_class.on_day(team_id: team.id, date: "2026-06-21")).to contain_exactly(state)
    end

    it "別のチームの登板は含めない" do
      other_team, other_season = create_team_with_season
      create_schedule(other_season, "2026-06-10")
      create_schedule(season, "2026-06-10")
      other_pitcher = create_card_pitcher(team: other_team, starter_stamina: 7)[0]
      create_start(team: other_team, pitcher: other_pitcher, date: "2026-06-10", innings: 5.0)
      mine = save_start("2026-06-10")
      expect(described_class.on_day(team_id: team.id, date: "2026-06-10")).to contain_exactly(mine)
    end

    it "日付が読めない引数は schedule_date の一致だけで引く（例外にしない）" do
      expect(described_class.on_day(team_id: team.id, date: "x")).to be_empty
    end
  end

  describe "日程の行の削除（シーズンの削除）" do
    it "登板は消さず、紐づけだけを外す" do
      create_schedule(season, "2026-06-10")
      state = save_start("2026-06-10")
      expect(state.season_schedule_id).not_to be_nil
      season.destroy!
      expect(state.reload.season_schedule_id).to be_nil
    end
  end
end
