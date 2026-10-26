require "rails_helper"

# Test Basis: 台帳 D-11（ノーゲームは疲労を計算し、成績は算入しない。成績算入 false は削除ではなく集計側での除外）/
#   D-11 再確認（2026-10-26 Operator）。試合の勝敗数・順位・打撃/投手成績の集計から外す試合の判定
RSpec.describe NoGameGames do
  let(:competition) { create(:competition) }
  let(:team) { create(:team) }
  let(:other) { create(:team) }
  let(:season) { create(:season, team: team) }

  def home_game(date, **attrs)
    create(:game, competition: competition, home_team: team, visitor_team: other, home_schedule_date: date, status: "confirmed", **attrs)
  end

  def schedule_on(date, no_game:, season: self.season)
    create(:season_schedule, season: season, date: Date.parse(date), no_game: no_game, score: 3, opponent_score: 1)
  end

  it "試合概要にノーゲームが立っている日の試合（ホーム側）を返す" do
    g = home_game("2026-03-20")
    schedule_on("2026-03-20", no_game: true)
    expect(described_class.ids).to include(g.id)
  end

  it "visitor 側の試合概要がノーゲームでも返す（相手チームの season でも同じ試合が無効）" do
    g = create(:game, competition: competition, home_team: other, visitor_team: team, visitor_schedule_date: "2026-03-21", status: "confirmed")
    schedule_on("2026-03-21", no_game: true)
    expect(described_class.ids).to include(g.id)
  end

  it "ノーゲームの印が無い日の試合は返さない" do
    g = home_game("2026-03-22")
    schedule_on("2026-03-22", no_game: false)
    expect(described_class.ids).not_to include(g.id)
  end

  it "別の日の試合は返さない" do
    g = home_game("2026-03-23")
    schedule_on("2026-03-20", no_game: true)
    expect(described_class.ids).not_to include(g.id)
  end

  it "同じ日に試合概要が複数あり一部だけがノーゲームなら、どの試合か決められないので返さない（PitcherGameResult の ambiguous と同じ）" do
    g = home_game("2026-03-24")
    schedule_on("2026-03-24", no_game: true)
    schedule_on("2026-03-24", no_game: false)
    expect(described_class.ids).not_to include(g.id)
  end

  it "試合の登板記録が no_game 区分なら、試合概要に印が無くても返す（画面の game_result=no_game で保存した記録）" do
    g = home_game("2026-03-25")
    create(:pitcher_game_state, game: g, team: team, competition: competition, schedule_date: "2026-03-25", result_category: "no_game")
    expect(described_class.ids).to include(g.id)
  end

  it "登板記録が normal だけで試合概要に印も無ければ返さない" do
    g = home_game("2026-03-26")
    create(:pitcher_game_state, game: g, team: team, competition: competition, schedule_date: "2026-03-26", result_category: "normal")
    expect(described_class.ids).not_to include(g.id)
  end

  it "日付が読めない試合（schedule_date が空・不正）でも落ちない" do
    home_game(nil)
    home_game("not-a-date")
    schedule_on("2026-03-20", no_game: true)
    expect { described_class.ids }.not_to raise_error
  end

  it "Game.excluding_no_game は no_game の試合だけを外す（削除はしない）" do
    a = home_game("2026-03-20")
    b = home_game("2026-03-27")
    schedule_on("2026-03-20", no_game: true)
    expect(Game.excluding_no_game).to contain_exactly(b)
    expect(Game.exists?(a.id)).to be true
  end

  it "ノーゲームの試合が 1 つも無ければ全試合を返す" do
    a = home_game("2026-03-20")
    expect(Game.excluding_no_game).to contain_exactly(a)
  end
end
