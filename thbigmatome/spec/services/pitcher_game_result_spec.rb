require "rails_helper"

# Test Basis: cmd_1775 Operator 裁定 2026-10-25 #4（試合の勝敗は試合概要の得点から。未入力・同点は負けではない）
RSpec.describe PitcherGameResult, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }

  def outcome(date = "2026-06-10") = described_class.for(team_id: team.id, schedule_date: date)

  it "自チームの得点が少なければ lose" do
    create_schedule(season, "2026-06-10", score: 2, opponent_score: 3)
    expect(outcome).to have_attributes(found: true, scored: true, result: "lose")
  end

  it "自チームの得点が多ければ win" do
    create_schedule(season, "2026-06-10", score: 4, opponent_score: 3)
    expect(outcome.result).to eq("win")
  end

  it "同点は draw（負けではない）" do
    create_schedule(season, "2026-06-10", score: 3, opponent_score: 3)
    expect(outcome).to have_attributes(scored: true, result: "draw")
  end

  it "得点が未入力（片方 nil）は scored: false で draw 扱い（負けではない）" do
    create_schedule(season, "2026-06-10", score: nil, opponent_score: nil)
    expect(outcome).to have_attributes(found: true, scored: false, result: "draw")
    create_schedule(season, "2026-06-11", score: 3, opponent_score: nil)
    expect(outcome("2026-06-11")).to have_attributes(scored: false, result: "draw")
  end

  it "0 対 0 は入力済みの同点" do
    create_schedule(season, "2026-06-10", score: 0, opponent_score: 0)
    expect(outcome).to have_attributes(scored: true, result: "draw")
  end

  it "試合概要が無ければ found: false（not_found）" do
    expect(outcome).to have_attributes(found: false, note: :not_found, result: nil)
  end

  it "同じ日付の試合概要が複数あれば found: false（ambiguous）。推測しない" do
    create_schedule(season, "2026-06-10", score: 2, opponent_score: 3)
    create_schedule(season, "2026-06-10", score: 5, opponent_score: 1)
    expect(outcome).to have_attributes(found: false, note: :ambiguous)
  end

  it "別チームの試合概要は見ない" do
    other_season = create(:season, team: create(:team))
    create_schedule(other_season, "2026-06-10", score: 0, opponent_score: 9)
    expect(outcome.found).to be(false)
  end
end
