require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §1.2（読む側 3 か所が別々に 1軍を決めている）・§4.3（読む側は RosterState に一本化）・§4.7（現在日カーソルはダッシュボードの基準日）。
# ダッシュボードは写し(team_memberships.squad)でなく、現在日カーソル時点・pre_game の変更記録で 1軍を決める。応答の形は変えない。
RSpec.describe "コミッショナーのダッシュボードの 1軍判定", type: :request do
  include_context "authenticated commissioner"

  let(:cost) { create(:cost, end_date: nil) }
  let(:team) { create(:team, is_active: true, team_type: :normal) }
  let!(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }

  def add_player(squad_cache:, cost_value: 4, series: "touhou")
    player = create(:player, series: series)
    create(:cost_player, cost: cost, player: player, normal_cost: cost_value)
    create(:team_membership, team: team, player: player, squad: squad_cache, selected_cost_type: "normal_cost")
  end

  def record(membership, squad, on, phase: "pre_game")
    create(:season_roster, season: season, team_membership: membership, squad: squad, registered_on: on, phase: phase)
  end

  def summary
    get "/api/v1/commissioner/dashboard/roster_status"
    response.parsed_body.find { |r| r["team_id"] == team.id }
  end

  it "写しが first でも記録が無ければ 2軍、写しが second でも記録が first なら 1軍と数える" do
    add_player(squad_cache: "first")                                              # 記録なし → 2軍
    promoted = add_player(squad_cache: "second", cost_value: 7)
    record(promoted, "first", Date.new(2026, 5, 1))                                # 記録は 1軍

    record = summary

    expect(record).to include("first_count" => 1, "second_count" => 1, "first_cost" => 7, "game_date" => "2026-05-15")
    expect(record.keys).to match_array(%w[team_id team_name team_type game_date first_count second_count first_cost first_cost_limit
                                          outside_world_count outside_world_limit warnings])
  end

  it "基準日は現在日カーソル(5/15)。5/15 の試合前の記録は含み、同日の試合後と翌日の記録は含まない" do
    on_day = add_player(squad_cache: "second")
    post_game = add_player(squad_cache: "second")
    next_day = add_player(squad_cache: "second")
    record(on_day, "first", Date.new(2026, 5, 15), phase: "pre_game")
    record(post_game, "first", Date.new(2026, 5, 15), phase: "post_game")
    record(next_day, "first", Date.new(2026, 5, 16))

    expect(summary).to include("first_count" => 1, "second_count" => 2)
  end

  it "costs: 1軍コスト・人数は記録から数える" do
    add_player(squad_cache: "first", cost_value: 9) # 記録なし → 2軍
    record(add_player(squad_cache: "second", cost_value: 5), "first", Date.new(2026, 5, 1))

    get "/api/v1/commissioner/dashboard/costs"
    entry = response.parsed_body.find { |r| r["team_id"] == team.id }

    expect(entry).to include("first_squad_count" => 1, "first_squad_cost" => 5, "total_cost" => 14)
  end

  it "外の世界枠の数も記録から数える" do
    record(add_player(squad_cache: "second", series: "hachinai"), "first", Date.new(2026, 5, 1))
    add_player(squad_cache: "first", series: "hachinai") # 記録なし → 2軍なので数えない

    expect(summary).to include("outside_world_count" => 1, "first_count" => 1)
  end

  it "cooldowns: 記録の上で 2軍にいる選手の降格から 10 日未満だけを返す（9 日目に出て、10 日目に消える）" do
    player = add_player(squad_cache: "first")
    record(player, "first", Date.new(2026, 4, 1))
    record(player, "second", Date.new(2026, 5, 6)) # 5/15 で 9 日目 → 5/16 まで

    get "/api/v1/commissioner/dashboard/cooldowns"
    entry = response.parsed_body.find { |r| r["player_id"] == player.player_id }
    expect(entry).to include("demotion_date" => "2026-05-06", "cooldown_until" => "2026-05-16", "remaining_days" => 1, "same_day_exempt" => false)

    season.update!(current_date: Date.new(2026, 5, 16))
    get "/api/v1/commissioner/dashboard/cooldowns"
    expect(response.parsed_body.map { |r| r["player_id"] }).not_to include(player.player_id)
  end

  it "CSV の「軍」列と並びも記録から決める" do
    stale = add_player(squad_cache: "first")
    record(add_player(squad_cache: "second"), "first", Date.new(2026, 5, 1))

    get "/api/v1/commissioner/dashboard/roster_status.csv", params: { team_id: team.id }
    rows = CSV.parse(response.body.delete_prefix("﻿"), headers: true)

    expect(rows.map { |r| r["軍"] }).to eq(%w[1軍 2軍])
    expect(rows[1]["選手名"]).to eq(stale.player.short_name.presence || stale.player.name)
  end
end
