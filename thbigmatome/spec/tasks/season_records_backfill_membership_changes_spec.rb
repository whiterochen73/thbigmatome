require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §5.2 段2（選手ごとに join を 1 件。日付は最初の昇降格の日、無ければシーズン開始日。
# 値は移行時点の契約・カード。移行前の契約変更・放出は復元できない）。作法は段1 の rebuild_squad_cache と同じ（試運転が既定、APPLY=1 で書く、OUT= で CSV、TEAM_ID= で絞る）。
RSpec.describe "season_records:backfill_membership_changes" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("season_records:backfill_membership_changes")
  end

  let(:task) { Rake::Task["season_records:backfill_membership_changes"] }
  let(:team) { create(:team) }
  let!(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }

  before do
    create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
    create(:season_schedule, season: season, date: "2026-04-02", date_type: "game_day")
  end

  def run_task(env = {})
    task.reenable
    old = env.keys.to_h { |k| [ k, ENV[k] ] }
    env.each { |k, v| ENV[k] = v }
    output = StringIO.new
    original = $stdout
    $stdout = output
    begin
      task.invoke
    ensure
      $stdout = original
      old.each { |k, v| ENV[k] = v }
    end
    output.string
  end

  def record(membership, squad, on)
    create(:season_roster, season: season, team_membership: membership, squad: squad, registered_on: on)
  end

  let(:card) { create(:player_card) }
  # 昇降格の記録なし / 開始日より後の最初の昇降格 / 開始日より前の最初の昇降格
  let!(:no_record) { create(:team_membership, team: team, selected_cost_type: "relief_only_cost", display_name: "表示", excluded_from_team_total: true) }
  let!(:later_first) { create(:team_membership, team: team, player_card: card).tap { |tm| record(tm, "first", Date.new(2026, 4, 20)) } }
  let!(:earlier_first) { create(:team_membership, team: team).tap { |tm| record(tm, "first", Date.new(2026, 3, 20)) } }

  it "試運転(既定)は DB を書かず、作る件数と日付の出どころを出す" do
    output = nil
    expect { output = run_task }.not_to change(TeamMembershipChange, :count)

    expect(output).to include("DRY-RUN (DB unchanged)")
    expect(output).to include("初期記録を作る: 3 件（チーム 1 / 選手 3）")
    expect(output).to include("最初の昇降格が開始日より前 1 / シーズン開始日 2 / 現在日カーソル 0")
    expect(output).to include("最初の昇降格がシーズン開始日より後の選手: 1 件")
  end

  it "APPLY=1 で選手ごとに join を 1 件、移行時点の値で書く。日付は最初の昇降格の日とシーズン開始日(4/1)の早い方、区分は pre_game" do
    run_task("APPLY" => "1")

    expect(TeamMembershipChange.count).to eq(3)
    by_tm = TeamMembershipChange.all.index_by(&:team_membership_id)
    expect(by_tm.fetch(no_record.id)).to have_attributes(kind: "join", effective_on: Date.new(2026, 4, 1), phase: "pre_game",
                                                         selected_cost_type: "relief_only_cost", display_name: "表示",
                                                         excluded_from_team_total: true, recorded_by_user_id: nil, season_id: season.id)
    expect(by_tm.fetch(later_first.id)).to have_attributes(effective_on: Date.new(2026, 4, 1), player_card_id: card.id)
    expect(by_tm.fetch(earlier_first.id).effective_on).to eq(Date.new(2026, 3, 20))
  end

  it "書いたあとの状態は、書く前(記録なし=行の今の値)と全時点で同じ（日付が開始日以降の範囲）" do
    dates = [ "2026-04-01", "2026-04-15", "2026-05-15" ].map { |d| Date.parse(d) }
    before_state = RosterState.new(team)
    snapshot = lambda do |state|
      dates.to_h { |d| [ d, state.at(d).transform_values { |e| e.to_h.slice(:on_team, :squad, :selected_cost_type, :player_card_id, :excluded_from_team_total, :display_name) } ] }
    end
    expected = snapshot.call(before_state)

    run_task("APPLY" => "1")

    expect(snapshot.call(RosterState.new(team))).to eq(expected)
  end

  it "何度流しても同じ（記録がある行は作らない）" do
    run_task("APPLY" => "1")
    output = nil
    expect { output = run_task("APPLY" => "1") }.not_to change(TeamMembershipChange, :count)
    expect(output).to include("初期記録を作る: 0 件").and include("記録あり 3 件")
  end

  it "昇降格の記録もシーズンの日程も無い選手は、現在日カーソルの日付に置く" do
    SeasonSchedule.where(season: season).delete_all

    run_task("APPLY" => "1")

    expect(TeamMembershipChange.find_by!(team_membership: no_record).effective_on).to eq(Date.new(2026, 5, 15))
  end

  it "シーズンの無いチームの行は作らず、件数だけ出す" do
    other = create(:team)
    create(:team_membership, team: other)

    output = run_task("APPLY" => "1")

    expect(TeamMembershipChange.joins(:team_membership).where(team_memberships: { team_id: other.id })).to be_empty
    expect(output).to include("シーズンの無いチームの行 1 件")
  end

  it "TEAM_ID で絞る" do
    other = create(:team)
    other_season = create(:season, team: other)
    other_tm = create(:team_membership, team: other)

    run_task("APPLY" => "1", "TEAM_ID" => other.id.to_s)

    expect(TeamMembershipChange.pluck(:team_membership_id)).to eq([ other_tm.id ])
    expect(other_season).to be_present
  end

  it "OUT= で作る記録の CSV を書く" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "backfill.csv")
      output = run_task("OUT" => path)

      rows = CSV.read(path, headers: true)
      expect(output).to include("CSV written: #{path}（3 行）")
      expect(rows.size).to eq(3)
      expect(rows.headers).to eq(%w[team_id team team_membership_id player_id player effective_on phase date_source first_roster_date season_start
                                    selected_cost_type player_card_id excluded_from_team_total display_name])
      expect(rows.map { |r| r["date_source"] }.sort).to eq(%w[first_roster season_start season_start])
    end
  end
end
