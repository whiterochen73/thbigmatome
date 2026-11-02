require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: cmd_1802 段3（rake season_records:fix_extra_game_day。試運転が既定、APPLY=1 で書く、OUT= で変更前の値の CSV、UNDO_FROM= で戻す、2 回目は 0 件。
# cmd_1784 の normalize_no_game_dates と同じ作法）。Operator 決定 2026-11-02: マスタの 2016-09-26 は予備日・既存シーズンも書き換え・前橋（結果あり）はそのまま。
RSpec.describe "season_records:fix_extra_game_day" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("season_records:fix_extra_game_day")
  end

  let(:task) { Rake::Task["season_records:fix_extra_game_day"] }
  let(:date) { Date.new(2016, 9, 26) }

  let!(:master) do
    Schedule.create!(name: "ペナント日程表", start_date: Date.new(2016, 9, 25), end_date: Date.new(2016, 9, 27)).tap do |s|
      %w[game_day game_day reserve_day].each_with_index { |type, i| s.schedule_details.create!(date: Date.new(2016, 9, 25) + i, date_type: type) }
    end
  end

  def new_season(team: create(:team))
    create(:season, team: team).tap do |season|
      master.schedule_details.order(:date).each { |d| create(:season_schedule, season: season, date: d.date, date_type: d.date_type) }
    end
  end

  def on_926(season) = SeasonSchedule.find_by!(season: season, date: date)

  let!(:season) { new_season }
  let!(:maebashi_team) { create(:team, name: "前橋") }
  let!(:maebashi) { new_season(team: maebashi_team).tap { |s| on_926(s).update!(score: 3, opponent_score: 1) } }

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

  it "試運転（既定）は DB を書かず、件数と keep（前橋）を出す" do
    out = run_task(blank_env)

    expect(out).to include("mode: DRY-RUN (DB unchanged)", "直す: マスタ 1 行 / シーズン 1 日 / 直さない（入力の痕跡あり）: シーズン 1 日")
    expect(out).to include("# keep: season #{maebashi.id} チーム #{maebashi_team.id}（前橋）", "score・opponent_score")
    expect(master.schedule_details.find_by!(date: date).date_type).to eq("game_day")
    expect(on_926(season).date_type).to eq("game_day")
  end

  it "APPLY=1 でマスタとシーズンを書く。前橋は game_day・結果のまま。出力に APPLY (DB updated) と書く" do
    out = run_task(blank_env.merge("APPLY" => "1"))

    expect(out).to include("mode: APPLY (DB updated)", "書いた: マスタ 1 行 / シーズン 1 日")
    expect(master.schedule_details.find_by!(date: date).date_type).to eq("reserve_day")
    expect(on_926(season).date_type).to eq("reserve_day")
    expect(on_926(maebashi)).to have_attributes(date_type: "game_day", score: 3, opponent_score: 1)
  end

  it "書いた後に日程マスタのレギュラーの試合日を検算して出す（143 でなければ WARN。AMB-11）" do
    out = run_task(blank_env.merge("APPLY" => "1"))

    expect(out).to match(/検算（AMB-11）日程表 #{master.id}「ペナント日程表」: レギュラーの試合日 1 日（規定 143） WARN/)
  end

  it "OUT= を渡すと変更前後の値の CSV をファイルへ書く（keep の行も含む）" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "before.csv")
      run_task(blank_env.merge("OUT" => path))
      rows = CSV.read(path, headers: true)

      expect(rows.headers).to eq(%w[kind record_id season_id team_id team date old_date_type new_date_type status pitcher_count reasons])
      expect(rows.map { |r| r["status"] }).to contain_exactly("fix", "fix", "keep")
      expect(rows.find { |r| r["kind"] == "master" }.to_h).to include("old_date_type" => "game_day", "new_date_type" => "reserve_day", "date" => "2016-09-26")
      expect(rows.find { |r| r["status"] == "keep" }.to_h).to include("team" => "前橋", "reasons" => "score opponent_score")
    end
  end

  it "APPLY=1 で出した CSV を UNDO_FROM= に渡すと元に戻る。試運転は読むだけ" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "before.csv")
      run_task(blank_env.merge("APPLY" => "1", "OUT" => path))

      dry = run_task(blank_env.merge("UNDO_FROM" => path))
      expect(dry).to include("UNDO DRY-RUN (DB unchanged)", "戻せる: 2 件")
      expect(on_926(season).date_type).to eq("reserve_day")

      out = run_task(blank_env.merge("UNDO_FROM" => path, "APPLY" => "1"))
      expect(out).to include("戻した: 2 件")
      expect(master.schedule_details.find_by!(date: date).date_type).to eq("game_day")
      expect(on_926(season).date_type).to eq("game_day")
      expect(on_926(maebashi)).to have_attributes(date_type: "game_day", score: 3)
    end
  end

  it "2 回流しても同じ結果（2 回目は直す対象 0 件。keep だけが一覧に残る）" do
    run_task(blank_env.merge("APPLY" => "1"))
    out = run_task(blank_env.merge("APPLY" => "1"))

    expect(out).to include("直す: マスタ 0 行 / シーズン 0 日 / 直さない（入力の痕跡あり）: シーズン 1 日")
    expect(on_926(season).date_type).to eq("reserve_day")
  end

  it "TEAM_ID= で絞るとマスタは触らず、そのチームのシーズンだけ直す" do
    out = run_task(blank_env.merge("APPLY" => "1", "TEAM_ID" => season.team_id.to_s))

    expect(out).to include("直す: マスタ 0 行 / シーズン 1 日")
    expect(master.schedule_details.find_by!(date: date).date_type).to eq("game_day")
    expect(on_926(season).date_type).to eq("reserve_day")
  end
end
