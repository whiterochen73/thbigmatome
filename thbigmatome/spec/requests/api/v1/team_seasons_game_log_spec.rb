require "rails_helper"

# cmd_1783 subtask_1783j 要望 2: 試合ログ（最大 1MB）は試合日ごとの画面でだけ読む。
# シーズンの試合日一覧（GET /api/v1/teams/:team_id/season）が全試合日分のログを読み込み・返却しないこと
RSpec.describe "GET /api/v1/teams/:team_id/season と game_log", type: :request do
  include_context "authenticated user"

  let(:team) { create(:team, user: user) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 7)) }
  let!(:schedule) { create(:season_schedule, season: season, date: Date.new(2026, 5, 7), score: 4, opponent_score: 2, game_log: "ログ本文") }

  it "試合日の一覧はログを読み込まず、返さない（他の項目は従来どおり返る）" do
    sqls = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| sqls << payload[:sql] }
    begin
      get "/api/v1/teams/#{team.id}/season"
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    expect(response).to have_http_status(:ok)
    loads = sqls.select { |q| q.start_with?("SELECT") && q.include?('FROM "season_schedules"') && !q.match?(/MIN\(|MAX\(|COUNT\(/) }
    expect(loads).not_to be_empty
    expect(loads.grep(/game_log|"season_schedules"\.\*/)).to be_empty

    json = response.parsed_body
    expect(json.to_s).not_to include("game_log")
    row = json["season_schedules"].find { |s| s["id"] == schedule.id }
    expect(row["game_result"]).to include("score" => "4 - 2", "result" => "win")
  end
end
