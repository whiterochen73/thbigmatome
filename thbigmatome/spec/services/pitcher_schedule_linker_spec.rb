require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §5.2 段3「登板の season_schedule_id を（チーム, 試合日）から引いて埋める。対応する日程の行が無い登板は
# 作らず一覧に出す」。何度流しても同じ結果。境界: 日程の行が無い・同じ日に複数・日付が読めない・紐づけ先が違う・別チームの同じ日。
RSpec.describe PitcherScheduleLinker, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  # callback で紐づく前の状態（rake を流す前の本番の写し）を作る
  def unlinked_start(date, **opts)
    create_start(team: team, pitcher: pitcher, date: date, innings: 5.0, game: create(:game), **opts).tap { |s| s.update_columns(season_schedule_id: nil) }
  end

  def run(**opts) = described_class.new(**opts).call

  it "紐づけが空で日程の行が 1 件ある登板を、その行に紐づける" do
    schedule = create_schedule(season, "2026-06-10")
    state = unlinked_start("2026-06-10")
    result = run(apply: true)
    expect(state.reload.season_schedule_id).to eq(schedule.id)
    expect(result.summary).to eq(linked: 1)
  end

  it "試運転（既定）は DB を書かず、紐づける件数だけ数える" do
    create_schedule(season, "2026-06-10")
    state = unlinked_start("2026-06-10")
    result = run
    expect(state.reload.season_schedule_id).to be_nil
    expect(result.summary).to eq(linked: 1)
  end

  it "ノーゲームの日・移動日・プレーオフの日の登板も、その日の日程の行に紐づける" do
    ids = [ [ "2026-06-10", "no_game_day" ], [ "2026-06-11", "travel_day" ], [ "2026-06-12", "playoff_day" ] ].map do |date, type|
      create(:season_schedule, season: season, date: date, date_type: type).id
    end
    states = %w[2026-06-10 2026-06-11 2026-06-12].map { |d| unlinked_start(d) }
    run(apply: true)
    expect(states.map { |s| s.reload.season_schedule_id }).to eq(ids)
  end

  it "日程の行が無い登板は紐づけず、行も作らず、一覧（unlinkable）に出す" do
    create_schedule(season, "2026-06-10")
    state = unlinked_start("2026-06-20")
    result = nil
    expect { result = run(apply: true) }.not_to change(SeasonSchedule, :count)
    expect(state.reload.season_schedule_id).to be_nil
    expect(result.summary).to eq(no_schedule: 1)
    expect(result.unlinkable.map(&:state_id)).to eq([ state.id ])
  end

  it "同じ日に日程の行が複数あれば紐づけず ambiguous として一覧に出す（行の候補を持つ）" do
    ids = Array.new(2) { create_schedule(season, "2026-06-10").id }
    state = unlinked_start("2026-06-10")
    result = run(apply: true)
    expect(state.reload.season_schedule_id).to be_nil
    expect(result.unlinkable.first).to have_attributes(status: :ambiguous, schedule_ids: ids)
  end

  it "日付が読めない登板は bad_date として一覧に出す" do
    state = unlinked_start("2026-06-10")
    state.update_columns(schedule_date: "bad")
    result = run(apply: true)
    expect(result.unlinkable.first).to have_attributes(status: :bad_date, state_id: state.id)
  end

  it "すでに引いた行に紐づいている登板は already で、触らない" do
    schedule = create_schedule(season, "2026-06-10")
    state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0)
    updated_at = state.reload.updated_at
    result = run(apply: true)
    expect(result.summary).to eq(already: 1)
    expect(state.reload).to have_attributes(season_schedule_id: schedule.id, updated_at: updated_at)
  end

  it "紐づけ先が引いた行と違う登板は mismatch として一覧に出し、変えない" do
    create_schedule(season, "2026-06-10")
    other = create_schedule(season, "2026-06-11")
    state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0)
    state.update_columns(season_schedule_id: other.id)
    result = run(apply: true)
    expect(state.reload.season_schedule_id).to eq(other.id)
    expect(result.unlinkable.first).to have_attributes(status: :mismatch, current_schedule_id: other.id)
  end

  it "別のチームの同じ日の日程の行には紐づけない" do
    _other_team, other_season = create_team_with_season
    create_schedule(other_season, "2026-06-10")
    state = unlinked_start("2026-06-10")
    run(apply: true)
    expect(state.reload.season_schedule_id).to be_nil
  end

  it "紐づけで updated_at を動かさない（登板の内容の変更ではない）" do
    create_schedule(season, "2026-06-10")
    state = unlinked_start("2026-06-10")
    before = state.reload.updated_at
    run(apply: true)
    expect(state.reload.updated_at).to eq(before)
  end

  it "何度流しても同じ結果（2 回目は linked が 0、already になる）" do
    create_schedule(season, "2026-06-10")
    unlinked_start("2026-06-10")
    run(apply: true)
    expect(run(apply: true).summary).to eq(already: 1)
  end

  it "team_id で絞る" do
    other_team, other_season = create_team_with_season
    other_pitcher = create_card_pitcher(team: other_team, starter_stamina: 7)[0]
    create_schedule(season, "2026-06-10")
    create_schedule(other_season, "2026-06-10")
    mine = unlinked_start("2026-06-10")
    theirs = create_start(team: other_team, pitcher: other_pitcher, date: "2026-06-10", innings: 5.0)
    theirs.update_columns(season_schedule_id: nil)
    result = run(apply: true, team_id: team.id)
    expect(mine.reload.season_schedule_id).not_to be_nil
    expect(theirs.reload.season_schedule_id).to be_nil
    expect(result.rows.map(&:team_id).uniq).to eq([ team.id ])
    expect(result.summary).to eq(linked: 1)
  end
end
