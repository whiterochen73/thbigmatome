require "rails_helper"

# Test Basis: context/thbig-bench-rule-adjudications.md AMB-29（専任契約は専任の方で数える）、cmd_1808（画面の「投・野・二刀流」の内訳）。
# 内訳は Team.outside_world_breakdown。ダッシュボードの roster_status とロスター画面の API（GET /teams/:id/roster）の両方に同じ形で出る。
RSpec.describe "外の世界枠の内訳の API", type: :request do
  let(:team) { create(:team, is_active: true, team_type: :normal) }
  let!(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let(:breakdown_keys) { %w[pitcher_only fielder_only two_way balance_ok] }

  def add_members(pitchers: 0, fielders: 0, two_ways: [], target_team: team, target_season: season)
    pitchers.times { add_outside_world_member(target_team, :pitcher, season: target_season) }
    fielders.times { add_outside_world_member(target_team, :fielder, season: target_season) }
    two_ways.each { |cost_type| add_outside_world_member(target_team, :two_way, cost_type: cost_type, season: target_season) }
  end

  describe "GET /api/v1/commissioner/dashboard/roster_status" do
    include_context "authenticated commissioner"

    def summary(for_team = team)
      get "/api/v1/commissioner/dashboard/roster_status"
      response.parsed_body.find { |r| r["team_id"] == for_team.id }
    end

    it "投 2・野 1・二刀流 1 の内訳と balance_ok を返す。人数は outside_world_count と合う" do
      add_members(pitchers: 2, fielders: 1, two_ways: %w[two_way_cost])

      record = summary

      expect(record["outside_world_count"]).to eq(4)
      expect(record["outside_world_breakdown"]).to eq("pitcher_only" => 2, "fielder_only" => 1, "two_way" => 1, "balance_ok" => true)
    end

    it "4 人で全員投手なら balance_ok が false" do
      add_members(pitchers: 4)

      expect(summary["outside_world_breakdown"]).to eq("pitcher_only" => 4, "fielder_only" => 0, "two_way" => 0, "balance_ok" => false)
    end

    it "4 人で全員野手なら balance_ok が false" do
      add_members(fielders: 4)

      expect(summary["outside_world_breakdown"]).to include("fielder_only" => 4, "balance_ok" => false)
    end

    it "全員投手でも二刀流 1 人で補えば balance_ok が true" do
      add_members(pitchers: 3, two_ways: %w[two_way_cost])

      expect(summary["outside_world_breakdown"]).to include("pitcher_only" => 3, "two_way" => 1, "balance_ok" => true)
    end

    it "投手専任・救援専任の二刀流は投、野手専任の二刀流は野に入る" do
      add_members(two_ways: %w[pitcher_only_cost relief_only_cost fielder_only_cost])

      expect(summary["outside_world_breakdown"]).to include("pitcher_only" => 2, "fielder_only" => 1, "two_way" => 0, "balance_ok" => true)
    end

    it "3 人以下は内訳を問わず balance_ok が true" do
      add_members(pitchers: 3)

      expect(summary["outside_world_breakdown"]).to include("pitcher_only" => 3, "balance_ok" => true)
    end

    it "5 人で全員投手なら人数の超過と内訳の違反の両方が出る" do
      add_members(pitchers: 5)

      record = summary

      expect(record["outside_world_count"]).to eq(5)
      expect(record["outside_world_breakdown"]).to include("pitcher_only" => 5, "balance_ok" => false)
      expect(record["warnings"]).to include("外の世界枠が上限を超過しています")
    end

    it "外の世界がいなければ 0 と balance_ok true" do
      expect(summary["outside_world_breakdown"]).to eq("pitcher_only" => 0, "fielder_only" => 0, "two_way" => 0, "balance_ok" => true)
    end

    it "2軍の選手は数えない" do
      add_members(pitchers: 3)
      add_outside_world_member(team, :fielder, squad: "second")

      expect(summary["outside_world_breakdown"]).to include("pitcher_only" => 3, "fielder_only" => 0)
    end

    it "選手が増えても問い合わせの数が増えない（N+1 を作らない）" do
      add_members(pitchers: 1, two_ways: %w[two_way_cost])
      get "/api/v1/commissioner/dashboard/roster_status" # 初回の読み込みの揺れを除く
      few = count_queries { get "/api/v1/commissioner/dashboard/roster_status" }

      add_members(pitchers: 2, fielders: 2, two_ways: %w[two_way_cost relief_only_cost fielder_only_cost pitcher_only_cost])
      many = count_queries { get "/api/v1/commissioner/dashboard/roster_status" }

      expect(summary["outside_world_count"]).to eq(10)
      expect(many).to eq(few)
    end
  end

  describe "GET /api/v1/teams/:team_id/roster" do
    include_context "authenticated user"
    before do
      team.update!(user: user)
      create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
      pin_current_date(season, Date.new(2026, 5, 15))
    end

    def roster_json
      get "/api/v1/teams/#{team.id}/roster", as: :json
      expect(response).to have_http_status(:ok)
      response.parsed_body
    end

    it "outside_world_breakdown に 1軍の外の世界枠の内訳を返す" do
      add_members(pitchers: 2, fielders: 1, two_ways: %w[two_way_cost])

      json = roster_json

      expect(json["outside_world_breakdown"]).to eq("pitcher_only" => 2, "fielder_only" => 1, "two_way" => 1, "balance_ok" => true)
    end

    it "4 人で全員野手なら balance_ok が false" do
      add_members(fielders: 4)

      expect(roster_json["outside_world_breakdown"]).to include("fielder_only" => 4, "balance_ok" => false)
    end

    it "各行に区分（pitcher_fielder_kind）を付ける。画面が 1軍を入れ替えても数え直せる" do
      pitcher = add_outside_world_member(team, :pitcher, season: season)
      relief = add_outside_world_member(team, :two_way, cost_type: "relief_only_cost", season: season)
      two_way = add_outside_world_member(team, :two_way, season: season)
      fielder_only = add_outside_world_member(team, :two_way, cost_type: "fielder_only_cost", season: season)

      kinds = roster_json["roster"].to_h { |r| [ r["team_membership_id"], r["pitcher_fielder_kind"] ] }

      expect(kinds).to eq(
        pitcher.id => "pitcher_only", relief.id => "pitcher_only", two_way.id => "two_way", fielder_only.id => "fielder_only"
      )
    end

    it "主な位置が内野手の pitcher カードは行の区分が fielder_only でも、画面の is_pitcher は従来どおり投手として使うカードのまま" do
      membership = add_outside_world_member(team, :pitcher_card_infielder, season: season)

      row = roster_json["roster"].find { |r| r["team_membership_id"] == membership.id }

      expect(row).to include("pitcher_fielder_kind" => "fielder_only", "is_pitcher" => true, "position" => "pitcher")
    end

    it "2軍の外の世界の選手と、東方の選手は内訳に数えない" do
      add_members(pitchers: 1)
      add_outside_world_member(team, :fielder, squad: "second")
      native = create(:player, series: "touhou")
      native_membership = create(:team_membership, team: team, player: native, squad: "first", selected_cost_type: "normal_cost")
      create(:season_roster, season: season, team_membership: native_membership, squad: "first", registered_on: Date.new(2026, 5, 1))

      expect(roster_json["outside_world_breakdown"]).to include("pitcher_only" => 1, "fielder_only" => 0)
    end
  end

  # ブロックの間に走った SQL の数（スキーマ・トランザクションの管理用は除く）
  def count_queries(&block)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
