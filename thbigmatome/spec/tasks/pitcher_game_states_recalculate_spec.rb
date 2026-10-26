require "rails_helper"
require "rake"
require "csv"

# Test Basis: cmd_1775 過去分の作り直し（rake。既定は試運転、APPLY=1 で書く、日付順の連鎖）
RSpec.describe "pitcher_game_states:recalculate_result_category", :pitcher_fatigue do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("pitcher_game_states:recalculate_result_category")
  end

  let(:task) { Rake::Task["pitcher_game_states:recalculate_result_category"] }
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let!(:first_state) do
    create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
    create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
  end
  let!(:second_state) do
    create_schedule(season, "2026-06-06", score: 0, opponent_score: 1)
    create_start(team: team, pitcher: pitcher, date: "2026-06-06", innings: 4.1, category: "normal")
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

  it "既定は試運転: DB を変えず、変わる件数と一覧(CSV)を出す" do
    out = run_task("APPLY" => nil)
    expect(first_state.reload.result_category).to eq("long_loss")
    expect(first_state.fatigue_p_used).to eq(0)
    expect(out).to include("DRY-RUN")
    expect(out).to include("# changed(区分が変わる): 1")
    csv_lines = out.lines.reject { |l| l.start_with?("#") }.join
    rows = CSV.parse(csv_lines, headers: true)
    # 区分が変わる 6/1 の行 + 連続中4日カウントだけが変わる 6/6 の行（6/1 → 6/6 は中4日）
    expect(rows.size).to eq(2)
    expect(rows.find { |r| r["date"] == "2026-06-01" }.to_h)
      .to include("old_category" => "long_loss", "new_category" => "normal", "new_fatigue_p" => "7", "game_result" => "lose",
                  "old_consecutive_short_rest_count" => "0", "new_consecutive_short_rest_count" => "0")
  end

  # Test Basis: cmd_1775 第2段 E3（過去分を同じ規則で埋め直す。カウントの変化も CSV に出す）
  it "E3: 連続中4日カウントが変わる行を CSV に出す（区分は変わらない行も、old/new 列つき）。試運転では書かない" do
    out = run_task("APPLY" => nil)
    csv_lines = out.lines.reject { |l| l.start_with?("#") }.join
    rows = CSV.parse(csv_lines, headers: true)
    expect(rows.headers).to include("old_consecutive_short_rest_count", "new_consecutive_short_rest_count")
    count_row = rows.find { |r| r["date"] == "2026-06-06" }
    expect(count_row.to_h).to include("old_category" => "normal", "new_category" => "normal",
                                      "old_consecutive_short_rest_count" => "0", "new_consecutive_short_rest_count" => "1")
    expect(out).to include("# consecutive_short_rest_count が変わる: 1")
    expect(second_state.reload.consecutive_short_rest_count).to eq(0)
  end

  it "E3: APPLY=1 で連続中4日カウントを書く（6/6 は 6/1 から中4日 → 1）" do
    run_task("APPLY" => "1")
    expect(second_state.reload.consecutive_short_rest_count).to eq(1)
    expect(first_state.reload.consecutive_short_rest_count).to eq(0)
  end

  # Test Basis: AMB-23。rake の埋め直しも間にリリーフが入る連続を 0 にする
  it "AMB-23: 6/1 先発 → 6/3 リリーフ → 6/6 先発 は APPLY=1 で 0（6/1 から中4日でも切れる）" do
    create_start(team: team, pitcher: pitcher, date: "2026-06-03", innings: 1.0, role: "reliever")
    second_state.update!(consecutive_short_rest_count: 1)
    run_task("APPLY" => "1")
    expect(second_state.reload.consecutive_short_rest_count).to eq(0)
  end

  it "APPLY=1 の時だけ DB を書く。日付順の連鎖で、作り直した前登板の区分(normal)が次の補正(中4日 -3 → 4)に効く" do
    out = run_task("APPLY" => "1")
    expect(out).to include("APPLY (DB updated)")
    expect(first_state.reload).to have_attributes(result_category: "normal", fatigue_p_used: 7)
    expect(second_state.reload.fatigue_p_used).to eq(4) # 前が long_loss のままなら 3
  end

  it "APPLY が 1 以外（0 など）なら試運転のまま" do
    run_task("APPLY" => "0")
    expect(first_state.reload.result_category).to eq("long_loss")
  end

  it "カード未特定・得点未入力は変えず件数を出す" do
    nocard, = create_card_pitcher(team: team, starter_stamina: 7, with_card: false)
    create_start(team: team, pitcher: nocard, date: "2026-06-01", innings: 8.0, category: "long_loss")
    create_schedule(season, "2026-06-20")
    create_start(team: team, pitcher: pitcher, date: "2026-06-20", innings: 9.0, category: "long_loss")
    out = run_task("APPLY" => "1")
    expect(out).to include("# pending(判定保留): 1")
    expect(out).to include("card_not_identified")
    expect(out).to include("# skipped_unscored(得点未入力): 1")
  end

  it "AMB-20追補: 0.0回・no_out_exit・L・後続あり・負けの過去記録は ko のまま残る（ko → normal にならない）" do
    ko_team, ko_season = create_team_with_season
    starter, = create_card_pitcher(team: ko_team, starter_stamina: 6)
    reliever, = create_card_pitcher(team: ko_team, starter_stamina: nil, relief_stamina: 3)
    create_schedule(ko_season, "2026-06-19", score: 2, opponent_score: 9)
    game = create(:game)
    ko_state = create_start(team: ko_team, pitcher: starter, date: "2026-06-19", innings: 0.0, category: "ko",
                            decision: "L", no_out_exit: true, game: game, appearance_order: 0)
    create_start(team: ko_team, pitcher: reliever, date: "2026-06-19", innings: 9.0, category: "normal",
                 role: "reliever", game: game, appearance_order: 1)

    dry = run_task("APPLY" => nil)
    csv_lines = dry.lines.reject { |l| l.start_with?("#") }.join
    changed_for_ko = CSV.parse(csv_lines, headers: true).select { |r| r["pitcher_id"] == starter.id.to_s }
    expect(changed_for_ko).to be_empty

    run_task("APPLY" => "1")
    expect(ko_state.reload.result_category).to eq("ko")
  end
end
