require "rails_helper"

# Test Basis: cmd_1896 Operator 裁定（2026-11-14）「日付が書いてある時限選手は、指定の期間のみ登録可能。期間外は起用不可」。
# 「登録」= 1軍登録（season_rosters の squad=first）。所属は期間外でもよい。境界: 「4/22~」は 4/21 違反・4/22 可、「~9/24」は 9/24 可・9/25 違反。
RSpec.describe "時限選手の 1軍登録", type: :request do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }
  let(:season) { create(:season, team: team) }

  before do
    %w[2026-04-01 2026-04-21 2026-04-22 2026-09-24 2026-09-25 2026-09-26].each do |date|
      create(:season_schedule, season: season, date: date, date_type: date == "2026-04-01" ? "game_day" : "reserve_day")
    end
    # 最低人数の検査は試合日にしか掛からない（上は予備日。シーズン初日は免除）
  end

  def member(traits, squad: "second", since: nil)
    player = create(:player)
    card = create(:player_card, player: player, unique_traits: traits)
    create(:cost_player, cost: cost, player: player, normal_cost: 1)
    create(:team_membership, team: team, player: player, player_card: card, squad: squad, selected_cost_type: "normal_cost", first_since: since)
  end

  def promote(membership, date, squad: "first")
    post "/api/v1/teams/#{team.id}/roster",
         params: { roster_updates: [ { team_membership_id: membership.id, squad: squad } ], target_date: date.to_s }, as: :json
  end

  context "一般ユーザー" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    it "「4/22~」: 4/21 に 1軍へ上げるのは止める（4/21 の違反）、4/22 は通る" do
      tm = member("4/22~")
      expect { promote(tm, "2026-04-21") }.not_to change(SeasonRoster, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["violations"]).to include(a_hash_including("kind" => "time_limited_player", "date" => "2026-04-21"))
      expect(response.parsed_body["error"]).to include("4/22 から")

      promote(tm, "2026-04-22")
      expect(response).to have_http_status(:ok)
    end

    it "時限でないカード・特徴が nil のカードは従来どおり上げられる" do
      promote(member(nil), "2026-04-21")
      expect(response).to have_http_status(:ok)
      promote(member("ホームラン"), "2026-04-21")
      expect(response).to have_http_status(:ok)
    end

    it "「~9/24」: 9/24 に上げるのは通る。9/25 に上げるのは止める" do
      promote(member("~9/24\n左手突き指"), "2026-09-24")
      expect(response).to have_http_status(:ok)

      promote(member("~9/24\n左手突き指"), "2026-09-25")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["violations"].first).to include("kind" => "time_limited_player", "date" => "2026-09-25")
    end

    it "期間内に上げ、終わりを過ぎても 1軍に残る分は止めず警告にし、終わりの翌日から違反として出す（9/25）" do
      tm = member("~9/24\n左手突き指")
      promote(tm, "2026-09-20")
      expect(response).to have_http_status(:ok)
      warning = response.parsed_body["warnings"].find { |w| w["kind"] == "time_limited_player" }
      expect(warning).to include("type" => "time_limited_deferred", "date" => "2026-09-25")
      expect(response.parsed_body["warnings"].count { |w| w["kind"] == "time_limited_player" }).to eq(1)
    end
  end

  context "コミッショナー" do
    include_context "authenticated commissioner"

    it "期間外でも警告つきで保存する" do
      tm = member("4/22~")
      expect { promote(tm, "2026-04-21") }.to change(SeasonRoster, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"]).to include(a_hash_including("kind" => "time_limited_player", "type" => "commissioner_override"))
    end
  end

  describe "RosterConstraintChecker（直接）" do
    it "期間の終わりを過ぎても 1軍にいる状態を、終わりの翌日の時点で拾う" do
      tm = member("~9/24", squad: "first", since: Date.new(2026, 9, 1))
      checker = RosterConstraintChecker.new(team: team, season: season, cost_list: cost)
      state = RosterState.new(team)
      kinds = ->(d) { checker.point_violations(state, Date.parse(d), "pre_game").map(&:kind) }
      expect(kinds.call("2026-09-24")).not_to include("time_limited_player")
      expect(kinds.call("2026-09-25")).to include("time_limited_player")
      expect(tm.player_id).to be_present
    end
  end
end
