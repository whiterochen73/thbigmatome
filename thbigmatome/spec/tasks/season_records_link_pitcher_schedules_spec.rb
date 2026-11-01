require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: cmd_1784 段3（rake season_records:link_pitcher_schedules。試運転が既定、APPLY=1 で書く、OUT= で紐づけられない登板の CSV、TEAM_ID= で絞る）。
# 設計書 §5.2 段3: 対応する日程の行が無い登板は作らず一覧に出す。
RSpec.describe "season_records:link_pitcher_schedules", :pitcher_fatigue do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("season_records:link_pitcher_schedules")
  end

  let(:task) { Rake::Task["season_records:link_pitcher_schedules"] }
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

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

  let!(:linkable) do
    create_schedule(season, "2026-06-10")
    create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0).tap { |s| s.update_columns(season_schedule_id: nil) }
  end
  let!(:orphan) do
    create_start(team: team, pitcher: pitcher, date: "2026-06-30", innings: 5.0, game: create(:game)).tap { |s| s.update_columns(season_schedule_id: nil) }
  end

  it "試運転（既定）は DB を書かず、件数と、紐づけられない登板の一覧を出す" do
    output = run_task("APPLY" => nil, "OUT" => nil)
    expect(linkable.reload.season_schedule_id).to be_nil
    expect(output).to include("mode: DRY-RUN (DB unchanged)", "紐づける: 1", "対応する日程の行が無い 1")
    expect(output).to include("#{team.id},#{team.name},#{pitcher.id},#{pitcher.name},2026-06-30,#{orphan.id},no_schedule")
  end

  it "APPLY=1 で書く。日程の行が無い登板は紐づけず、行も作らない" do
    expect { run_task("APPLY" => "1", "OUT" => nil) }.not_to change(SeasonSchedule, :count)
    expect(linkable.reload.season_schedule_id).not_to be_nil
    expect(orphan.reload.season_schedule_id).to be_nil
  end

  it "APPLY=1 の出力に APPLY (DB updated) と書く" do
    expect(run_task("APPLY" => "1", "OUT" => nil)).to include("mode: APPLY (DB updated)")
  end

  it "OUT= を渡すと、紐づけられない登板の CSV をファイルへ書く（見出し + 1 行）" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "unlinkable.csv")
      output = run_task("OUT" => path)
      rows = CSV.read(path, headers: true)
      expect(rows.size).to eq(1)
      expect(rows.first.to_h).to include("state_id" => orphan.id.to_s, "status" => "no_schedule", "schedule_date" => "2026-06-30")
      expect(output).to include("CSV written: #{path}（1 行）")
    end
  end

  it "TEAM_ID= で絞る" do
    other_team, other_season = create_team_with_season
    other_pitcher = create_card_pitcher(team: other_team, starter_stamina: 7)[0]
    create_schedule(other_season, "2026-06-10")
    theirs = create_start(team: other_team, pitcher: other_pitcher, date: "2026-06-10", innings: 5.0)
    theirs.update_columns(season_schedule_id: nil)
    run_task("APPLY" => "1", "TEAM_ID" => team.id.to_s)
    expect(linkable.reload.season_schedule_id).not_to be_nil
    expect(theirs.reload.season_schedule_id).to be_nil
  end
end
