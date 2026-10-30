require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: cmd_1784 段1 の仕様（rake season_records:rebuild_squad_cache。写しを RosterState の最新から作り直す。
# 試運転が既定、APPLY=1 で書く、OUT= で差分 CSV、TEAM_ID= で絞る）。設計書 §5.2 段1（写し 5 件は変更記録に合わせて作り直す。変更前の値は CSV に残す）
RSpec.describe "season_records:rebuild_squad_cache" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("season_records:rebuild_squad_cache")
  end

  let(:task) { Rake::Task["season_records:rebuild_squad_cache"] }
  let(:team) { create(:team) }
  let!(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }

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

  # 写しと記録が合わない 3 パターン: 最新の記録が first なのに写しが second(S1)・最新の記録が second なのに写しが first・記録が無いのに写しが first
  let!(:behind) { create(:team_membership, team: team, squad: "second") }
  let!(:ahead) { create(:team_membership, team: team, squad: "first") }
  let!(:no_record) { create(:team_membership, team: team, squad: "first") }
  let!(:in_sync) { create(:team_membership, team: team, squad: "first") }

  before do
    record(behind, "second", Date.new(2026, 3, 25))
    record(behind, "first", Date.new(2026, 5, 1))
    record(ahead, "first", Date.new(2026, 4, 1))
    record(ahead, "second", Date.new(2026, 5, 20)) # 現在日カーソル(5/15)より後の記録も「最新」
    record(in_sync, "first", Date.new(2026, 4, 1))
  end

  it "試運転(既定)は DB を書かず、差分を件数で出す" do
    out = run_task("APPLY" => nil, "OUT" => nil, "TEAM_ID" => nil)

    expect(out).to include("DRY-RUN (DB unchanged)")
    expect(out).to include("写しが変わる: 3 件")
    expect(out).to include("first→second: 2 / second→first: 1")
    expect(out).to include("記録が無いのに写しが first（second へ変わる）: 1")
    expect(behind.reload.squad).to eq("second")
    expect(ahead.reload.squad).to eq("first")
    expect(no_record.reload.squad).to eq("first")
  end

  it "APPLY=1 で写しを最新の記録に作り直す。合っている行は触らない" do
    before_updated_at = in_sync.reload.updated_at

    out = run_task("APPLY" => "1", "OUT" => nil, "TEAM_ID" => nil)

    expect(out).to include("APPLY (DB updated)")
    expect(behind.reload.squad).to eq("first")
    expect(ahead.reload.squad).to eq("second")
    expect(no_record.reload.squad).to eq("second")
    expect(in_sync.reload.updated_at).to eq(before_updated_at)
  end

  it "OUT= で差分 CSV を出す。変更前の値(old_squad)を残す" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "diff.csv")
      out = run_task("OUT" => path, "APPLY" => nil, "TEAM_ID" => nil)
      expect(out).to include("# CSV written: #{path}（3 行）")

      rows = CSV.read(path, headers: true)
      expect(rows.headers).to eq(%w[team_id team team_membership_id player_id player old_squad new_squad last_record_id last_record_date last_record_phase records])
      by_id = rows.index_by { |r| r["team_membership_id"].to_i }
      expect(by_id[behind.id].to_h).to include("old_squad" => "second", "new_squad" => "first", "last_record_date" => "2026-05-01", "last_record_phase" => "pre_game", "records" => "2")
      expect(by_id[ahead.id].to_h).to include("old_squad" => "first", "new_squad" => "second", "last_record_date" => "2026-05-20")
      expect(by_id[no_record.id].to_h).to include("old_squad" => "first", "new_squad" => "second", "last_record_id" => nil, "records" => "0")
      expect(by_id).not_to have_key(in_sync.id)
    end
  end

  it "TEAM_ID= で絞る（他チームは触らない）" do
    other_team = create(:team)
    other_stale = create(:team_membership, team: other_team, squad: "first")

    out = run_task("APPLY" => "1", "TEAM_ID" => other_team.id.to_s, "OUT" => nil)

    expect(out).to include("写しが変わる: 1 件")
    expect(other_stale.reload.squad).to eq("second")
    expect(behind.reload.squad).to eq("second")
  end

  it "べき等: 2 回目の APPLY は差分 0 件" do
    run_task("APPLY" => "1", "OUT" => nil, "TEAM_ID" => nil)
    out = run_task("APPLY" => "1", "OUT" => nil, "TEAM_ID" => nil)
    expect(out).to include("写しが変わる: 0 件")
  end
end
