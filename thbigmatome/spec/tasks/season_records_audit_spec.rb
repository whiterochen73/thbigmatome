require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: cmd_1784 段0 の仕様（rake season_records:audit。標準出力に件数の要約と定義、OUT= で明細 CSV、TEAM_ID= で絞る、実行時間を出す）
RSpec.describe "season_records:audit", :pitcher_fatigue do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("season_records:audit")
  end

  let(:task) { Rake::Task["season_records:audit"] }
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }

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

  before do
    create(:season_schedule, season: season, date: "2026-06-05", date_type: "no_game")
    create(:season_schedule, season: season, date: "2026-06-02", date_type: "no_game")
  end

  it "項目ごとの件数・定義・実行時間を標準出力に出す" do
    out = run_task("OUT" => nil, "TEAM_ID" => nil, "SKIP_RECOMPUTE" => nil)
    SeasonRecordAudit::ITEMS.each_key { |code| expect(out).to match(/^#{code} .*: \d+ 件/) }
    expect(out).to include("S10 ノーゲームの表し方の食い違い: 2 件（チーム 1 / 選手 0）")
    expect(out).to include("type_no_game_flag_false: 2")
    expect(out).to include("定義:")
    expect(out).to match(/# elapsed: \d+\.\d 秒/)
    expect(out).to include("DB は書かない")
  end

  it "OUT= で明細 CSV を出す。列と並び（項目・チーム・日付）が決まっている" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "audit.csv")
      out = run_task("OUT" => path, "TEAM_ID" => nil, "SKIP_RECOMPUTE" => nil)
      expect(out).to include("# CSV written: #{path}（2 行）")
      rows = CSV.read(path, headers: true)
      expect(rows.headers).to eq(%w[item category team_id team player_id player date ref evidence])
      expect(rows.map { |r| r["date"] }).to eq(%w[2026-06-02 2026-06-05])
      expect(rows.first.to_h).to include("item" => "S10", "team_id" => team.id.to_s, "team" => team.name)
    end
  end

  it "TEAM_ID= で絞る" do
    other_team, other_season = create_team_with_season
    create(:season_schedule, season: other_season, date: "2026-06-01", date_type: "no_game")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "audit.csv")
      run_task("OUT" => path, "TEAM_ID" => other_team.id.to_s, "SKIP_RECOMPUTE" => nil)
      expect(CSV.read(path, headers: true).map { |r| r["team_id"] }.uniq).to eq([ other_team.id.to_s ])
    end
  end

  it "SKIP_RECOMPUTE=1 で S8c を省く（見出しにも出さない）" do
    out = run_task("OUT" => nil, "TEAM_ID" => nil, "SKIP_RECOMPUTE" => "1")
    expect(out).not_to match(/^S8c /)
    expect(out).to include("S8c 再計算: 省略")
  end

  it "同じデータで回した CSV は何度でも同じ内容になる（移行前後の diff 用）" do
    Dir.mktmpdir do |dir|
      a = File.join(dir, "a.csv")
      b = File.join(dir, "b.csv")
      run_task("OUT" => a, "TEAM_ID" => nil, "SKIP_RECOMPUTE" => nil)
      run_task("OUT" => b, "TEAM_ID" => nil, "SKIP_RECOMPUTE" => nil)
      expect(File.read(a)).to eq(File.read(b))
    end
  end
end
