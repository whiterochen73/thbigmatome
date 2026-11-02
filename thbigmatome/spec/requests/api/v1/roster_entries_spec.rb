require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.4 の 4（昇降格の記録を消す API。消した後も検査を通す）・§1.3 S3（取り消し手段が無い）。
# 境界は数値で固定する: 1軍の下限 25 人（24/25）・上限 29 人（29/30）。
RSpec.describe "DELETE /api/v1/teams/:team_id/roster_entries/:id", type: :request do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let(:start_day) { Date.new(2026, 4, 1) }

  before do
    [ "2026-04-01", "2026-05-10", "2026-05-20" ].each do |date|
      create(:season_schedule, season: season, date: date, date_type: "game_day")
    end
  end

  def add_player(first_since: nil)
    player = create(:player)
    membership = create(:team_membership, team: team, player: player, squad: first_since ? "first" : "second",
                                           selected_cost_type: "normal_cost", first_since: first_since)
    create(:cost_player, cost: cost, player: player, normal_cost: 4)
    membership
  end

  def add_firsts(count)
    Array.new(count) { add_player(first_since: start_day) }
  end

  def record(membership, squad, on, phase: "pre_game")
    create(:season_roster, season: season, team_membership: membership, squad: squad, registered_on: on, phase: phase)
  end

  def delete_entry(entry, team_id: team.id)
    delete "/api/v1/teams/#{team_id}/roster_entries/#{entry.id}"
  end

  context "一般ユーザー" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    it "誤って入れた記録を消せる。写しは最新の記録に作り直す" do
      firsts = add_firsts(26)
      demotion = record(firsts.first, "second", Date.new(2026, 5, 5))
      firsts.first.update!(squad: "second")

      expect { delete_entry(demotion) }.to change(SeasonRoster, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"]).to eq([])
      expect(firsts.first.reload.squad).to eq("first")
    end

    it "消すと後の試合日が 24 人になる削除は止める（記録は残る）" do
      firsts = add_firsts(25)
      promotion = record(add_player, "first", Date.new(2026, 5, 1)) # 26 人
      record(firsts.first, "second", Date.new(2026, 5, 5))          # 25 人

      expect { delete_entry(promotion) }.not_to change(SeasonRoster, :count) # 消すと 5/10 が 24 人

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["violations"].first).to include("date" => "2026-05-10", "kind" => "first_squad_min")
      expect(response.parsed_body["error"]).to include("2026-05-10")
    end

    it "消しても後の試合日が 25 人以上に留まる削除は通る" do
      firsts = add_firsts(25)
      add_player.tap { |extra| record(extra, "first", Date.new(2026, 5, 1)) } # 26 人
      demotion = record(firsts.first, "second", Date.new(2026, 5, 5))         # 25 人

      expect { delete_entry(demotion) }.to change(SeasonRoster, :count).by(-1) # 26 人に戻る

      expect(response).to have_http_status(:ok)
    end

    it "消すと後の日付が 30 人になる削除は止め、29 人に留まる削除は通る" do
      firsts = add_firsts(29)
      demotion = record(firsts.first, "second", Date.new(2026, 5, 5))
      later = add_player
      record(later, "first", Date.new(2026, 5, 10)) # 5/10 から 29 人に戻る

      expect { delete_entry(demotion) }.not_to change(SeasonRoster, :count) # 5/10 が 30 人

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["violations"].first).to include("date" => "2026-05-10", "kind" => "first_squad_max")

      SeasonRoster.find_by!(team_membership: later).destroy! # 5/10 の昇格が無ければ、抹消を取り消しても 29 人
      delete_entry(demotion)
      expect(response).to have_http_status(:ok)
    end

    # 4/1 昇格 → 4/10 降格 → (重複の降格) → 4/22 昇格。重複を畳むので降格日は最初の降格
    def cooldown_scenario(duplicate_demotion_on)
      add_firsts(25)
      player = add_player(first_since: start_day)
      real = record(player, "second", Date.new(2026, 4, 10))
      record(player, "second", duplicate_demotion_on) # 状態が変わらない重複
      record(player, "first", Date.new(2026, 4, 22))  # 4/10 の降格から 12 日 → 有効
      real
    end

    it "実際の降格の記録を消すと、残った重複の降格(4/20)が降格日になり、4/22 の昇格がクールダウンに掛かるので止める" do
      real = cooldown_scenario(Date.new(2026, 4, 20))

      expect { delete_entry(real) }.not_to change(SeasonRoster, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["violations"].first).to include("date" => "2026-04-22", "kind" => "cooldown")
    end

    it "残った降格が 4/12 なら 4/22 の昇格はちょうど 10 日後なので削除は通る" do
      real = cooldown_scenario(Date.new(2026, 4, 12))

      expect { delete_entry(real) }.to change(SeasonRoster, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "他チームの記録は 404（消えない）" do
      add_firsts(26)
      other_team = create(:team, user: user)
      other_membership = create(:team_membership, team: other_team)
      other_season = create(:season, team: other_team)
      entry = create(:season_roster, season: other_season, team_membership: other_membership, squad: "first", registered_on: Date.new(2026, 5, 1))

      expect { delete_entry(entry) }.not_to change(SeasonRoster, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "存在しない記録は 404" do
      delete "/api/v1/teams/#{team.id}/roster_entries/0"
      expect(response).to have_http_status(:not_found)
    end

    it "アクセス権のないチームは 403（消えない）" do
      stranger_team = create(:team, user: create(:user))
      membership = create(:team_membership, team: stranger_team)
      entry = create(:season_roster, season: create(:season, team: stranger_team), team_membership: membership, squad: "first", registered_on: Date.new(2026, 5, 1))

      expect { delete_entry(entry, team_id: stranger_team.id) }.not_to change(SeasonRoster, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "同じ記録の二重削除は、2 回目が 404" do
      firsts = add_firsts(26)
      demotion = record(firsts.first, "second", Date.new(2026, 5, 5))
      delete_entry(demotion)
      delete_entry(demotion)
      expect(response).to have_http_status(:not_found)
    end
  end

  context "コミッショナー" do
    include_context "authenticated commissioner"

    it "後の試合日が 24 人になる削除は、警告つきで消す" do
      firsts = add_firsts(24)
      promotion = record(add_player, "first", Date.new(2026, 5, 1))
      record(firsts.first, "second", Date.new(2026, 5, 5))

      expect { delete_entry(promotion) }.to change(SeasonRoster, :count).by(-1)

      expect(response).to have_http_status(:ok)
      warning = response.parsed_body["warnings"].find { |w| w["kind"] == "first_squad_min" }
      expect(warning).to include("type" => "commissioner_override", "date" => "2026-05-10")
    end
  end

  context "未ログイン" do
    it "401（消えない）" do
      firsts = add_firsts(26)
      demotion = record(firsts.first, "second", Date.new(2026, 5, 5))
      expect { delete_entry(demotion) }.not_to change(SeasonRoster, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
