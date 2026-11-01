require "rails_helper"

# Test Basis: cmd_1784 段4。設計書 §4.6 / §8（プレーオフ日を試合日に含めて決める）。1軍の最低人数の検査が掛かる「試合日」は
# SeasonSchedule::GAME_DATE_TYPES（通常・交流戦・プレーオフ）。ノーゲームの日（種別は試合日のまま真偽値）にも掛かる（台帳 D-11: 登録の計算は行う）。
# 境界は数値で固定する: 下限 25 人（24 = 違反 / 25 = 通る）。
RSpec.describe RosterConstraintChecker do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }
  let(:cost) { create(:cost, end_date: nil) }

  def d(day) = Date.new(2026, 5, day)

  def make_firsts(count)
    Array.new(count) do
      player = create(:player)
      create(:cost_player, cost: cost, player: player, normal_cost: 1)
      create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost", first_since: d(1))
    end
  end

  def min_violation_dates
    checker = described_class.new(team: team, season: season, cost_list: cost)
    state = RosterState.new(team)
    checker.violations_from(state, [ d(1), "pre_game" ]).select { |v| v.kind == "first_squad_min" }.map(&:date)
  end

  before do
    create(:season_schedule, season: season, date: d(1), date_type: "game_day") # シーズン初日は免除
  end

  {
    "game_day" => true, "interleague_game_day" => true, "playoff_day" => true,
    "reserve_day" => false, "interleague_reserve_day" => false, "travel_day" => false, "postponed" => false, "no_game_day" => false
  }.each do |type, checked|
    it "種別 #{type} の日は 1軍 24 人で最低人数の検査が#{checked ? '掛かる' : '掛からない'}" do
      make_firsts(24)
      create(:season_schedule, season: season, date: d(10), date_type: type)
      expect(min_violation_dates).to(checked ? eq([ d(10) ]) : be_empty)
    end
  end

  it "1軍 25 人なら、どの試合日でも通る（境界 24/25）" do
    make_firsts(25)
    %w[game_day interleague_game_day playoff_day].each_with_index { |type, i| create(:season_schedule, season: season, date: d(10 + i), date_type: type) }
    expect(min_violation_dates).to be_empty
  end

  it "ノーゲームの日（種別は試合日のまま真偽値 no_game）にも掛かる" do
    make_firsts(24)
    create(:season_schedule, season: season, date: d(10), date_type: "interleague_game_day", no_game: true)
    expect(min_violation_dates).to eq([ d(10) ])
  end

  it "予備日のままノーゲームになった日は、試合日の種別ではないので掛からない" do
    make_firsts(24)
    create(:season_schedule, season: season, date: d(10), date_type: "reserve_day", no_game: true)
    expect(min_violation_dates).to be_empty
  end
end
