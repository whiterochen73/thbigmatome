require "rails_helper"

# カレンダーの入力漏れの印（cmd_1783 段B）: GET /api/v1/teams/:team_id/season の各試合日に登板記録の件数を付ける
RSpec.describe "GET /api/v1/teams/:team_id/season の pitcher_appearance_count", type: :request do
  include_context "authenticated user"

  let(:team) { create(:team, user: user) }
  let(:competition) { create(:competition) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 7)) }
  let!(:game_day_with_pitchers) { create(:season_schedule, season: season, date: Date.new(2026, 5, 7), score: 4, opponent_score: 2) }
  let!(:game_day_without_pitchers) { create(:season_schedule, season: season, date: Date.new(2026, 5, 8), score: 1, opponent_score: 0) }
  let!(:off_day) { create(:season_schedule, :off_day, season: season, date: Date.new(2026, 5, 9)) }

  def create_appearance(team:, schedule_date:)
    game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
    create(:pitcher_game_state, team: team, competition: competition, game: game, schedule_date: schedule_date)
  end

  def schedule_json(json, schedule)
    json["season_schedules"].find { |s| s["id"] == schedule.id }
  end

  it "試合日ごとに自チームの登板記録の件数を返す（登板の無い日・試合の無い日は 0）" do
    2.times { create_appearance(team: team, schedule_date: "2026-05-07") }

    get "/api/v1/teams/#{team.id}/season"

    expect(response).to have_http_status(:ok)
    json = response.parsed_body
    expect(schedule_json(json, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(2)
    expect(schedule_json(json, game_day_without_pitchers)["pitcher_appearance_count"]).to eq(0)
    expect(schedule_json(json, off_day)["pitcher_appearance_count"]).to eq(0)
  end

  it "他チームの同じ日の登板記録は数えない" do
    other_team = create(:team)
    create_appearance(team: other_team, schedule_date: "2026-05-07")
    create_appearance(team: team, schedule_date: "2026-05-07")

    get "/api/v1/teams/#{team.id}/season"

    expect(schedule_json(response.parsed_body, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(1)
  end

  it "別の日の登板記録は数えない" do
    create_appearance(team: team, schedule_date: "2026-05-06")

    get "/api/v1/teams/#{team.id}/season"

    expect(schedule_json(response.parsed_body, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(0)
  end

  it "試合日が多くても、件数は日付ごとの 1 回の集計でまとめて求める（試合日ごとに問い合わせない）" do
    5.times { |i| create(:season_schedule, season: season, date: Date.new(2026, 6, 1) + i.days) }
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] if payload[:sql].include?("pitcher_game_states") }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get "/api/v1/teams/#{team.id}/season"
    end

    expect(response).to have_http_status(:ok)
    expect(queries.size).to eq(1)
  end

  # cmd_1784 段3: 日程の行に紐づく登板（season_schedule_id）はその行に、まだ紐づけていない登板は schedule_date の日に数える
  describe "日程の行への紐づけ（season_schedule_id）" do
    it "紐づく登板はその日程の行に数える" do
      2.times { create_appearance(team: team, schedule_date: "2026-05-07") }
      expect(PitcherGameState.pluck(:season_schedule_id).uniq).to eq([ game_day_with_pitchers.id ])

      get "/api/v1/teams/#{team.id}/season"

      expect(schedule_json(response.parsed_body, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(2)
      expect(schedule_json(response.parsed_body, game_day_without_pitchers)["pitcher_appearance_count"]).to eq(0)
    end

    it "紐づけをまだ入れていない登板（rake の前）は schedule_date の日に数える" do
      create_appearance(team: team, schedule_date: "2026-05-07")
      PitcherGameState.update_all(season_schedule_id: nil)

      get "/api/v1/teams/#{team.id}/season"

      expect(schedule_json(response.parsed_body, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(1)
    end

    it "別の日程の行に紐づく登板は、schedule_date が同じでも紐づけ先に数える（紐づけが正）" do
      create_appearance(team: team, schedule_date: "2026-05-07")
      PitcherGameState.update_all(season_schedule_id: game_day_without_pitchers.id)

      get "/api/v1/teams/#{team.id}/season"

      expect(schedule_json(response.parsed_body, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(0)
      expect(schedule_json(response.parsed_body, game_day_without_pitchers)["pitcher_appearance_count"]).to eq(1)
    end

    it "同じ日に日程の行が複数ある日は決められないので、その日の登板を日付で数えて両方に出す" do
      twin = create(:season_schedule, season: season, date: Date.new(2026, 5, 7), score: 1, opponent_score: 0)
      create_appearance(team: team, schedule_date: "2026-05-07")
      expect(PitcherGameState.first.season_schedule_id).to be_nil

      get "/api/v1/teams/#{team.id}/season"

      json = response.parsed_body
      expect(schedule_json(json, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(1)
      expect(schedule_json(json, twin)["pitcher_appearance_count"]).to eq(1)
    end

    it "同じ日に日程の行が複数ある日は、片方に紐づいた登板も日付で数えて両方に出す" do
      twin = create(:season_schedule, season: season, date: Date.new(2026, 5, 7), score: 1, opponent_score: 0)
      create_appearance(team: team, schedule_date: "2026-05-07")
      PitcherGameState.update_all(season_schedule_id: twin.id)

      get "/api/v1/teams/#{team.id}/season"

      json = response.parsed_body
      expect(schedule_json(json, game_day_with_pitchers)["pitcher_appearance_count"]).to eq(1)
      expect(schedule_json(json, twin)["pitcher_appearance_count"]).to eq(1)
    end

    it "日程の外の日付の登板はどの日にも数えず、他チームの紐づきも数えない" do
      create_appearance(team: team, schedule_date: "2026-08-01")
      other_team = create(:team)
      other_season = create(:season, team: other_team)
      other_day = create(:season_schedule, season: other_season, date: Date.new(2026, 5, 7))
      create_appearance(team: other_team, schedule_date: "2026-05-07")
      expect(PitcherGameState.find_by(team: other_team).season_schedule_id).to eq(other_day.id)

      get "/api/v1/teams/#{team.id}/season"

      counts = response.parsed_body["season_schedules"].map { |s| s["pitcher_appearance_count"] }
      expect(counts.sum).to eq(0)
    end
  end
end
