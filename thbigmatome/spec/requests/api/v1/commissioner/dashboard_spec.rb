require "rails_helper"

RSpec.describe "Api::V1::Commissioner::Dashboard", type: :request do
  let(:password) { "password123" }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }

  def login_as(user)
    post "/api/v1/auth/login", params: { name: user.name, password: password }, as: :json
  end

  describe "GET /api/v1/commissioner/dashboard/absences" do
    context "コミッショナーユーザーの場合" do
      before { login_as(commissioner_user) }

      it "200を返す" do
        get "/api/v1/commissioner/dashboard/absences"
        expect(response).to have_http_status(:ok)
      end

      it "全チームの横断離脱者一覧を返す" do
        team = create(:team, is_active: true)
        season = create(:season, team: team, current_date: Date.current)
        player = create(:player)
        tm = create(:team_membership, team: team, player: player)
        create(:player_absence, team_membership: tm, season: season,
               absence_type: :injury, start_date: Date.current - 2, duration: 10, duration_unit: "days")

        get "/api/v1/commissioner/dashboard/absences"
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.size).to be >= 1

        absence = json.find { |a| a["team_id"] == team.id }
        expect(absence).not_to be_nil
        expect(absence["team_name"]).to eq(team.name)
        expect(absence["player_name"]).to eq(player.name)
        expect(absence["absence_type"]).to eq("injury")
        expect(absence).to have_key("remaining_days")
        expect(absence).to have_key("season_current_date")
      end

      it "終了済みの離脱は含まない" do
        team = create(:team, is_active: true)
        season = create(:season, team: team, current_date: Date.current)
        player = create(:player)
        tm = create(:team_membership, team: team, player: player)
        # 3日前開始・2日間 → end_date = 1日前 → 終了済み
        create(:player_absence, team_membership: tm, season: season,
               absence_type: :injury, start_date: Date.current - 3, duration: 2, duration_unit: "days")

        get "/api/v1/commissioner/dashboard/absences"
        json = JSON.parse(response.body)
        ended = json.find { |a| a["team_id"] == team.id }
        expect(ended).to be_nil
      end

      it "inactive チームは含まない" do
        team = create(:team, is_active: false)
        season = create(:season, team: team, current_date: Date.current)
        player = create(:player)
        tm = create(:team_membership, team: team, player: player)
        create(:player_absence, team_membership: tm, season: season,
               absence_type: :injury, start_date: Date.current, duration: 5, duration_unit: "days")

        get "/api/v1/commissioner/dashboard/absences"
        json = JSON.parse(response.body)
        inactive_absence = json.find { |a| a["team_id"] == team.id }
        expect(inactive_absence).to be_nil
      end
    end

    context "一般ユーザーの場合" do
      before { login_as(player_user) }

      it "403を返す" do
        get "/api/v1/commissioner/dashboard/absences"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        get "/api/v1/commissioner/dashboard/absences"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/commissioner/dashboard/costs" do
    context "コミッショナーユーザーの場合" do
      before { login_as(commissioner_user) }

      it "200を返す" do
        get "/api/v1/commissioner/dashboard/costs"
        expect(response).to have_http_status(:ok)
      end

      it "全チームのコスト使用状況を返す" do
        cost = create(:cost, end_date: nil)
        team = create(:team, is_active: true, team_type: :normal)
        player = create(:player)
        create(:cost_player, cost: cost, player: player, normal_cost: 10)
        create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost")

        get "/api/v1/commissioner/dashboard/costs"
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.size).to be >= 1

        record = json.find { |r| r["team_id"] == team.id }
        expect(record).not_to be_nil
        expect(record["team_name"]).to eq(team.name)
        expect(record["team_type"]).to eq("normal")
        expect(record["total_cost"]).to eq(10)
        expect(record["total_cost_limit"]).to eq(200)
        expect(record["first_squad_cost"]).to eq(10)
        expect(record["first_squad_count"]).to eq(1)
        expect(record["exempt_count"]).to eq(0)
        expect(record["cost_usage_ratio"]).to eq(10 / 200.0)
      end

      it "inactive チームは含まない" do
        cost = create(:cost, end_date: nil)
        team = create(:team, is_active: false, team_type: :normal)
        player = create(:player)
        create(:cost_player, cost: cost, player: player, normal_cost: 5)
        create(:team_membership, team: team, player: player, squad: "first", selected_cost_type: "normal_cost")

        get "/api/v1/commissioner/dashboard/costs"
        json = JSON.parse(response.body)
        record = json.find { |r| r["team_id"] == team.id }
        expect(record).to be_nil
      end
    end

    context "一般ユーザーの場合" do
      before { login_as(player_user) }

      it "403を返す" do
        get "/api/v1/commissioner/dashboard/costs"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        get "/api/v1/commissioner/dashboard/costs"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
