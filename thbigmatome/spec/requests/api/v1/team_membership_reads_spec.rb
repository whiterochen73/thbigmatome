require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.3（読む側は RosterState を呼ぶ。契約・カード・在籍はその時点以前で最新の
# team_membership_changes）・§1.3 S5（救援専任契約から先発契約への切り替えがいつ起きたか）。応答の形は変えない。
# 契約の変更は 5/10 の試合前: それより前の日付は旧契約、5/10 以降は新契約で読む。
RSpec.describe "チーム編成の変更記録を読む側（ロスター・疲労一覧・ダッシュボード・昇降格の検査）", type: :request do
  let(:team) { create(:team, is_active: true, team_type: :normal) }
  let(:cost) { create(:cost, end_date: nil) }
  let!(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let(:card_set) { create(:card_set) }
  let(:pitcher) { create(:player, :pitcher, series: "touhou") }
  let(:pitcher_card) { create(:player_card, player: pitcher, card_set: card_set, card_type: "pitcher", is_pitcher: true) }
  let!(:membership) { create(:team_membership, team: team, player: pitcher, player_card: pitcher_card, selected_cost_type: "relief_only_cost") }

  before do
    create(:cost_player, cost: cost, player: pitcher, normal_cost: 9, relief_only_cost: 3)
    create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
    create(:season_roster, season: season, team_membership: membership, squad: "first", registered_on: Date.new(2026, 4, 1))
    # 4/1 から救援専任契約(コスト 3)、5/10 の試合前から通常契約(コスト 9)に切り替え。5/20 の試合後に野手専念契約
    create(:team_membership_change, team_membership: membership, season: season, kind: "join", effective_on: Date.new(2026, 4, 1),
                                    selected_cost_type: "relief_only_cost", player_card: pitcher_card)
    create(:team_membership_change, team_membership: membership, season: season, kind: "contract", effective_on: Date.new(2026, 5, 10),
                                    selected_cost_type: "normal_cost", player_card: pitcher_card)
    create(:team_membership_change, team_membership: membership, season: season, kind: "contract", effective_on: Date.new(2026, 5, 20),
                                    phase: "post_game", selected_cost_type: "fielder_only_cost", player_card: pitcher_card)
    membership.update_columns(selected_cost_type: "fielder_only_cost")
  end

  context "チームの持ち主" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    describe "GET /teams/:id/roster" do
      def roster_row(date, phase: nil)
        get "/api/v1/teams/#{team.id}/roster", params: { target_date: date, phase: phase }.compact
        response.parsed_body["roster"].find { |r| r["team_membership_id"] == membership.id }
      end

      it "契約の種別・コスト・役割は、その時点の変更記録から導く（写しの今の値ではない）" do
        expect(roster_row("2026-05-09")).to include("selected_cost_type" => "relief_only_cost", "cost" => 3, "is_pitcher" => true, "is_relief_only" => false)
        expect(roster_row("2026-05-10")).to include("selected_cost_type" => "normal_cost", "cost" => 9)
        expect(roster_row("2026-05-20")).to include("selected_cost_type" => "normal_cost", "cost" => 9)
        expect(roster_row("2026-05-20", phase: "post_game")).to include("selected_cost_type" => "fielder_only_cost")
      end

      it "最初の登録(4/1)より前の日付には、まだチームにいない選手を出さない" do
        get "/api/v1/teams/#{team.id}/roster", params: { target_date: "2026-03-31" }
        expect(response.parsed_body["roster"]).to be_empty
      end
    end

    describe "GET /teams/:id/pitcher_game_states/fatigue_summary" do
      def ids(date, phase: nil)
        get "/api/v1/teams/#{team.id}/pitcher_game_states/fatigue_summary", params: { date: date, phase: phase }.compact
        response.parsed_body.map { |e| e["player_id"] }
      end

      def entry(date)
        get "/api/v1/teams/#{team.id}/pitcher_game_states/fatigue_summary", params: { date: date }
        response.parsed_body.find { |e| e["player_id"] == pitcher.id }
      end

      it "野手専念契約になった後の日付(5/20 試合後)では投手に数えず、それより前は数える" do
        expect(ids("2026-05-19")).to eq([ pitcher.id ])
        expect(ids("2026-05-20")).to eq([ pitcher.id ])
        expect(ids("2026-05-20", phase: "post_game")).to eq([])
        expect(ids("2026-05-21")).to eq([])
      end

      it "救援専任契約の間は「先発なら」を出さず、先発もできる契約に変わった日から出す（S5）" do
        expect(entry("2026-05-09")).to include("as_starter_omitted_reason" => "relief_only_contract", "as_starter" => nil)
        expect(entry("2026-05-10")["as_starter_omitted_reason"]).to be_nil
        expect(entry("2026-05-10")["as_starter"]).to be_present
      end
    end

    describe "GET /teams/:id/pitcher_game_states（player_ids なし）" do
      def ids(date)
        get "/api/v1/teams/#{team.id}/pitcher_game_states", params: { date: date }
        response.parsed_body.map { |e| e["player_id"] }
      end

      it "その日の契約が野手専念なら投手リストに入れない。まだ登録されていない日にも入れない" do
        expect(ids("2026-05-21")).to eq([])
        expect(ids("2026-05-10")).to eq([ pitcher.id ])
        expect(ids("2026-03-31")).to eq([])
      end
    end

    describe "昇降格の検査が時点の契約を使う" do
      # 対象の選手(membership)は 4/2 から 2軍。ほかに 28 人が 4/1 から 1軍（4 × 28 = 112。29 人の上限は 120）。
      # 対象の契約コストは 4/1〜5/9 が 3(救援専任)、5/10 から通常契約。5/5 に昇格すると 5/5 は 112 + 3 = 115、5/10 以降は 112 + 通常契約のコスト
      before do
        28.times do
          player = create(:player)
          create(:cost_player, cost: cost, player: player, normal_cost: 4)
          create(:team_membership, team: team, player: player, selected_cost_type: "normal_cost", first_since: Date.new(2026, 4, 1))
        end
        create(:season_roster, season: season, team_membership: membership, squad: "second", registered_on: Date.new(2026, 4, 2))
      end

      def promote_on(date)
        post "/api/v1/teams/#{team.id}/roster", params: { roster_updates: [ { team_membership_id: membership.id, squad: "first" } ], target_date: date }, as: :json
      end

      it "5/10 以降のコストが 8 なら合計 120 ちょうどで、旧契約の日(5/5)への昇格は通る" do
        CostPlayer.find_by!(player: pitcher).update!(normal_cost: 8)

        promote_on("2026-05-05")

        expect(response).to have_http_status(:ok)
      end

      it "5/10 以降のコストが 9 なら合計 121 で、旧契約の日(5/5)への昇格でも 5/10 の超過で止める" do
        promote_on("2026-05-05")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["violations"].first).to include("date" => "2026-05-10", "kind" => "first_squad_cost")
      end

      it "同じ昇格を契約が変わる 5/10 に入れると、書いた日そのもので止める（旧契約のコスト 3 ではなく 9 で数える）" do
        promote_on("2026-05-10")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to include("120")
      end
    end
  end

  context "コミッショナーのダッシュボード" do
    include_context "authenticated commissioner"

    it "costs: 基準日(5/15)の契約で数える。5/15 時点は通常契約のコスト 9（野手専念への切り替えは 5/20 試合後）" do
      get "/api/v1/commissioner/dashboard/costs"
      row = response.parsed_body.find { |r| r["team_id"] == team.id }
      expect(row).to include("total_cost" => 9, "first_squad_cost" => 9, "first_squad_count" => 1)
    end

    it "基準日を 5/9 に戻すと、旧契約(救援専任)のコスト 3 で数える" do
      season.update!(current_date: Date.new(2026, 5, 9))
      get "/api/v1/commissioner/dashboard/costs"
      row = response.parsed_body.find { |r| r["team_id"] == team.id }
      expect(row).to include("total_cost" => 3, "first_squad_cost" => 3)
    end

    it "放出された選手は、放出の日以降の基準日では数えない" do
      create(:team_membership_change, team_membership: membership, season: season, kind: "release", effective_on: Date.new(2026, 5, 12),
                                      selected_cost_type: "normal_cost", player_card: pitcher_card)
      membership.update_columns(on_team: false)

      get "/api/v1/commissioner/dashboard/costs"
      row = response.parsed_body.find { |r| r["team_id"] == team.id }
      expect(row).to include("total_cost" => 0, "first_squad_count" => 0)
    end
  end
end
