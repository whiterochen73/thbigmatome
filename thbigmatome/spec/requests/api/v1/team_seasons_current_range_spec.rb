require "rails_helper"

# 現在日は日程の結果から自動で決まる（cmd_1784 段2b）。ポータル・試合日ページ・コミッショナー画面が読む値の確認
RSpec.describe "現在日の自動化", type: :request do
  include_context "authenticated user"

  let(:team) { create(:team, user: user) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 1, 1)) }

  def d(day) = Date.new(2026, 5, day)

  before do
    # 5/1 試合 5/2 試合 5/3 移動 5/4 試合
    create(:season_schedule, season: season, date: d(1), score: 2, opponent_score: 1)
    create(:season_schedule, season: season, date: d(2), score: 0, opponent_score: 4)
    create(:season_schedule, :off_day, season: season, date: d(3), date_type: "travel_day")
    create(:season_schedule, season: season, date: d(4))
  end

  describe "GET /api/v1/teams/:team_id/season" do
    it "シーズンの題（name）は返さない（画面はチーム名をタイトルにする）" do
      get "/api/v1/teams/#{team.id}/season"

      expect(response.parsed_body).not_to have_key("name")
    end

    it "current_date は次の試合日、current_range は結果の翌日〜次の試合日" do
      get "/api/v1/teams/#{team.id}/season"

      json = response.parsed_body
      expect(json["current_date"]).to eq("2026-05-04")
      expect(json["current_range"]).to eq("start_date" => "2026-05-03", "end_date" => "2026-05-04")
    end

    it "最終試合日の後は current_range が nil で、current_date は最後に結果が入った日" do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(score: 5, opponent_score: 5)

      get "/api/v1/teams/#{team.id}/season"

      json = response.parsed_body
      expect(json["current_range"]).to be_nil
      expect(json["current_date"]).to eq("2026-05-04")
    end

    it "日程の無いシーズンは current_range が nil で、current_date は列の値" do
      empty_team = create(:team, user: user)
      create(:season, team: empty_team, current_date: Date.new(2026, 3, 3))

      get "/api/v1/teams/#{empty_team.id}/season"

      expect(response.parsed_body["current_range"]).to be_nil
      expect(response.parsed_body["current_date"]).to eq("2026-03-03")
    end
  end

  describe "PATCH /api/v1/teams/:team_id/season（現在日カーソルを動かす API）" do
    it "廃止した。ルートが無く、現在日は変わらない" do
      expect {
        Rails.application.routes.recognize_path("/api/v1/teams/#{team.id}/season", method: :patch)
      }.to raise_error(ActionController::RoutingError)
      expect(Rails.application.routes.recognize_path("/api/v1/teams/#{team.id}/season", method: :get))
        .to include(controller: "api/v1/team_seasons", action: "show")

      patch "/api/v1/teams/#{team.id}/season", params: { season: { current_date: "2026-05-01" } }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(season.reload.current_date).to eq(d(4))
    end
  end

  describe "GET /api/v1/teams（一覧の season_current_date）" do
    it "日程から導いた現在日を返し、列の値は使わない" do
      season # 作成
      get "/api/v1/teams"

      row = response.parsed_body.find { |t| t["id"] == team.id }
      expect(row["season_current_date"]).to eq("2026-05-04")
    end
  end

  describe "GET /api/v1/teams/:team_id/roster の key_player_selectable" do
    it "結果が入った後は false（キープレイヤーを設定できるのは、結果が 1 件も入っていない間だけ）" do
      get "/api/v1/teams/#{team.id}/roster"

      expect(response.parsed_body).to include("key_player_selectable" => false)
    end

    it "結果が 1 件も無い間は true（現在日が初日でなくても）" do
      SeasonSchedule.where(season: season).update_all(score: nil, opponent_score: nil)

      get "/api/v1/teams/#{team.id}/roster"

      expect(response.parsed_body).to include("key_player_selectable" => true)
    end
  end

  describe "POST /api/v1/teams/:team_id/key_player" do
    let(:membership) { create(:team_membership, team: team) }

    it "まだ結果が 1 件も入っていない間は設定できる（現在日が初日でなくても、範囲が日程の最初の日から始まっていればよい）" do
      SeasonSchedule.where(season: season).update_all(score: nil, opponent_score: nil)
      SeasonSchedule.find_by!(season: season, date: d(1)).update!(date_type: "travel_day")

      post "/api/v1/teams/#{team.id}/key_player", params: { key_player_id: membership.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(season.reload.key_player_id).to eq(membership.id)
    end

    it "結果が入った後は設定できない" do
      post "/api/v1/teams/#{team.id}/key_player", params: { key_player_id: membership.id }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end
end
