require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: cmd_1784 段4（rake season_records:normalize_no_game_dates。試運転が既定、APPLY=1 で書く、OUT= で変更前後の CSV、UNDO_FROM= で逆向き、
# 止める行があれば APPLY=1 でも何も書かない）。設計書 §4.6 / §5.4。
RSpec.describe "season_records:normalize_no_game_dates", :pitcher_fatigue do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("season_records:normalize_no_game_dates")
  end

  let(:task) { Rake::Task["season_records:normalize_no_game_dates"] }
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  def d(day) = Date.new(2026, 5, day)

  let!(:master) do
    Schedule.create!(name: "マスタ", start_date: d(1), end_date: d(2)).tap do |s|
      { 1 => "game_day", 2 => "reserve_day" }.each { |day, type| s.schedule_details.create!(date: d(day), date_type: type) }
    end
  end
  let!(:normal_day) { create(:season_schedule, season: season, date: d(1), date_type: "game_day") }
  let!(:ng_day) { legacy_no_game_schedule(season: season, date: d(2)) }
  let!(:start) { create_start(team: team, pitcher: pitcher, date: "2026-05-02", innings: 4.0) }

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

  let(:blank_env) { { "APPLY" => nil, "OUT" => nil, "TEAM_ID" => nil, "UNDO_FROM" => nil } }

  it "試運転（既定）は DB を書かず、件数と、試合日でない種別に戻る日を出す" do
    out = run_task(blank_env)
    expect(ng_day.reload).to have_attributes(date_type: "no_game", no_game: false)
    expect(out).to include("mode: DRY-RUN (DB unchanged)", "種別 no_game の日 1 日（登板 1 件）", "戻す: 1")
    expect(out).to include("reserve_day 1", "要確認(not_game_type)")
  end

  it "APPLY=1 で書く。出力に APPLY (DB updated) と書く" do
    out = run_task(blank_env.merge("APPLY" => "1"))
    expect(out).to include("mode: APPLY (DB updated)", "書いた: 1 日")
    expect(ng_day.reload).to have_attributes(date_type: "reserve_day", no_game: true)
    expect(start.reload.result_category).to eq("no_game")
  end

  it "OUT= を渡すと変更前後の値の CSV をファイルへ書く" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "before.csv")
      run_task(blank_env.merge("OUT" => path))
      rows = CSV.read(path, headers: true)
      expect(rows.headers).to eq(%w[schedule_id season_id team_id team date old_date_type old_no_game new_date_type new_no_game status master_types pitcher_count])
      expect(rows.first.to_h).to include("schedule_id" => ng_day.id.to_s, "old_date_type" => "no_game", "old_no_game" => "false",
                                         "new_date_type" => "reserve_day", "new_no_game" => "true", "status" => "restore", "pitcher_count" => "1")
    end
  end

  it "APPLY=1 で出した CSV を UNDO_FROM= に渡すと、種別・真偽値・登板の結果区分が元に戻る。試運転は読むだけ" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "before.csv")
      run_task(blank_env.merge("APPLY" => "1", "OUT" => path))

      dry = run_task(blank_env.merge("UNDO_FROM" => path))
      expect(dry).to include("UNDO DRY-RUN (DB unchanged)", "戻せる: 1 件")
      expect(ng_day.reload.no_game).to be true

      out = run_task(blank_env.merge("UNDO_FROM" => path, "APPLY" => "1"))
      expect(out).to include("戻した: 1 件")
      expect(ng_day.reload).to have_attributes(date_type: "no_game", no_game: false)
      expect(start.reload.result_category).to eq("normal")
    end
  end

  it "2 回流しても同じ結果（2 回目は対象 0 日）" do
    run_task(blank_env.merge("APPLY" => "1"))
    out = run_task(blank_env.merge("APPLY" => "1"))
    expect(out).to include("種別 no_game の日 0 日")
    expect(ng_day.reload).to have_attributes(date_type: "reserve_day", no_game: true)
  end

  it "元の種別を決められない日があれば、APPLY=1 でも何も書かずに止める" do
    other_team, other_season = create_team_with_season
    legacy_no_game_schedule(season: other_season, date: Date.new(2027, 1, 1)) # 対応するマスタが無い
    expect { run_task(blank_env.merge("APPLY" => "1")) }.to raise_error(SystemExit)
    expect(ng_day.reload).to have_attributes(date_type: "no_game", no_game: false)
    expect(other_team).to be_present
  end
end
