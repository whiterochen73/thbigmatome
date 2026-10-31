require "rails_helper"

# 段2a の QC（subtask_1784i）で生き残った変異の穴埋め。
#   - GET team_players?target_date: その時点でまだいない・放出済みの選手を出さない（on_team の絞り込み）
#   - 表示名・契約は、その時点の変更記録の値（view() が表示名も見る）
#   - 監督の変更: 他チームの放出済みの選手は重複に数えない（DirectorSiblingCheck の .active）
# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.3・§4.4 の 5、
#             queue/reviews/subtask_1784i.yaml の findings（M24 / M21 / M14）
RSpec.describe "チーム編成を時点で読む・監督の変更と放出済みの選手", type: :request do
  include_context "authenticated user"

  let(:team) { create(:team, user: user) }
  let(:cost) { create(:cost, end_date: nil) }
  let!(:season) { create(:season, team: team) }

  def change(membership, kind, on, phase: "pre_game", cost_type: "normal_cost", display_name: nil)
    create(:team_membership_change, team_membership: membership, season: season, kind: kind, effective_on: on, phase: phase,
                                    selected_cost_type: cost_type, display_name: display_name)
  end

  def add_member(**attrs)
    player = create(:player)
    create(:cost_player, cost: cost, player: player, normal_cost: 4)
    create(:team_membership, team: team, player: player, **attrs)
  end

  describe "GET /teams/:id/team_players?target_date=" do
    def player_ids(date, phase: nil)
      get "/api/v1/teams/#{team.id}/team_players", params: { target_date: date, phase: phase, cost_list_id: cost.id }.compact
      expect(response).to have_http_status(:ok)
      response.parsed_body.map { |p| p["id"] }
    end

    it "まだ登録されていない選手・放出済みの選手は出さず、在籍中の選手だけを返す" do
      joined_later = add_member
      released = add_member
      steady = add_member
      change(steady, "join", Date.new(2026, 4, 1))
      change(joined_later, "join", Date.new(2026, 5, 10))
      change(released, "join", Date.new(2026, 4, 1))
      change(released, "release", Date.new(2026, 5, 1))
      released.update_columns(on_team: false)

      # 4/15: steady と released（5/1 の放出前）がいる。joined_later は 5/10 まで未登録
      expect(player_ids("2026-04-15")).to contain_exactly(steady.player_id, released.player_id)
      # 5/1 の試合前から released は放出済み
      expect(player_ids("2026-05-01")).to contain_exactly(steady.player_id)
      # 放出の日の前日の試合後までは在籍中、5/10 の試合前から joined_later が入る
      expect(player_ids("2026-04-30", phase: "post_game")).to contain_exactly(steady.player_id, released.player_id)
      expect(player_ids("2026-05-10")).to contain_exactly(steady.player_id, joined_later.player_id)
    end

    it "日付を付けない読み出しは、今の在籍中の写し（放出済みを出さない）" do
      active = add_member
      gone = add_member
      gone.update_columns(on_team: false)

      get "/api/v1/teams/#{team.id}/team_players", params: { cost_list_id: cost.id }

      expect(response.parsed_body.map { |p| p["id"] }).to contain_exactly(active.player_id)
    end

    it "表示名・契約は、その時点の変更記録の値で返す（行の今の値ではない）" do
      member = add_member(display_name: "今の名", selected_cost_type: "fielder_only_cost")
      change(member, "join", Date.new(2026, 4, 1), cost_type: "normal_cost", display_name: "旧名")
      change(member, "contract", Date.new(2026, 5, 10), cost_type: "fielder_only_cost", display_name: "今の名")

      get "/api/v1/teams/#{team.id}/team_players", params: { target_date: "2026-05-09", phase: "post_game", cost_list_id: cost.id }
      row = response.parsed_body.find { |p| p["id"] == member.player_id }
      expect(row).to include("display_name" => "旧名", "selected_cost_type" => "normal_cost")

      get "/api/v1/teams/#{team.id}/team_players", params: { target_date: "2026-05-10", cost_list_id: cost.id }
      row = response.parsed_body.find { |p| p["id"] == member.player_id }
      expect(row).to include("display_name" => "今の名", "selected_cost_type" => "fielder_only_cost")
    end

    it "表示名だけが違う時点でも、その時点の表示名を返す（契約・カード・除外は同じ）" do
      member = add_member(display_name: "新", selected_cost_type: "normal_cost")
      change(member, "join", Date.new(2026, 4, 1), display_name: "旧")
      change(member, "contract", Date.new(2026, 5, 10), display_name: "新")

      get "/api/v1/teams/#{team.id}/team_players", params: { target_date: "2026-05-01", cost_list_id: cost.id }

      expect(response.parsed_body.find { |p| p["id"] == member.player_id }["display_name"]).to eq("旧")
    end
  end

  describe "PATCH /teams/:id の監督の変更（他チームの選手との重複）" do
    let(:manager) { create(:manager, role: :director) }
    let(:sibling_team) { create(:team) }
    let(:shared_player) { create(:player) }

    before do
      create(:team_manager, team: sibling_team, manager: manager, role: :director)
      create(:team_membership, team: team, player: shared_player)
    end

    def assign_director
      patch "/api/v1/teams/#{team.id}", params: { team: { director_id: manager.id } }, as: :json
    end

    it "監督が持つ他チームに同じ選手が在籍中なら 422" do
      create(:team_membership, team: sibling_team, player: shared_player)

      assign_director

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("重複")
    end

    it "他チームでは放出済みの選手は重複に数えない" do
      create(:team_membership, team: sibling_team, player: shared_player, on_team: false)

      assign_director

      expect(response).to have_http_status(:ok)
      expect(team.reload.director).to eq(manager)
    end
  end
end
