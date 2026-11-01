require "rails_helper"

# Test Basis: cmd_1794 段3（サーバ側）/ cmd_1802 段3。Operator 決定 2026-11-02「進み具合に試合数（消化数／総数）を出す。雨天中止があっても 143 試合消化するので
# 総数は 143（日程マスタ）で固定し、未振替数を別に出す」。数え方の境界は spec/services/season_game_progress_spec.rb。ここは API の形・権限・全チーム分が揃うこと。
RSpec.describe "GET /api/v1/commissioner/dashboard/game_progress", type: :request do
  let(:path) { "/api/v1/commissioner/dashboard/game_progress" }
  let(:day) { Date.new(2026, 5, 1) }

  # マスタ: 試合日 5 + 予備日 1 + プレーオフ 1
  let!(:master) do
    Schedule.create!(name: "マスタ", start_date: day, end_date: day + 6).tap do |s|
      %w[game_day game_day game_day game_day game_day reserve_day playoff_day].each_with_index { |type, i| s.schedule_details.create!(date: day + i, date_type: type) }
    end
  end

  # マスタと同じ日程のシーズン。results = 先頭から結果を入れる試合日数、playoff_played = 結果を入れるプレーオフ日
  def season_with(team, results: 0, playoff_played: 0)
    create(:season, team: team).tap do |season|
      master.schedule_details.order(:date).each_with_index do |detail, i|
        attrs = { season: season, date: detail.date, date_type: detail.date_type }
        attrs.merge!(score: 2, opponent_score: 1) if (i < results && detail.date_type == "game_day") || (playoff_played.positive? && detail.date_type == "playoff_day")
        create(:season_schedule, **attrs)
      end
    end
  end

  context "コミッショナー" do
    include_context "authenticated commissioner"

    it "チームごとに team_id・regular_played・regular_total・regular_unrescheduled・playoff_played を数値で返す" do
      team = create(:team, is_active: true)
      season_with(team, results: 3, playoff_played: 1)

      get path

      expect(response).to have_http_status(:ok)
      row = response.parsed_body.find { |r| r["team_id"] == team.id }
      expect(row).to eq("team_id" => team.id, "regular_played" => 3, "regular_total" => 5, "regular_unrescheduled" => 0, "playoff_played" => 1)
    end

    it "稼働中も休止中も 1 チーム 1 行で返し、シーズンの無いチームは返さない" do
      active = create(:team, is_active: true)
      inactive = create(:team, is_active: false)
      no_season = create(:team)
      season_with(active, results: 1)
      season_with(inactive, results: 2)

      get path

      ids = response.parsed_body.map { |r| r["team_id"] }
      expect(ids).to contain_exactly(active.id, inactive.id)
      expect(ids).not_to include(no_season.id)
    end

    it "日程の無いシーズンは 0 で返す" do
      team = create(:team)
      create(:season, team: team)

      get path

      expect(response.parsed_body).to eq([ { "team_id" => team.id, "regular_played" => 0, "regular_total" => 0, "regular_unrescheduled" => 0, "playoff_played" => 0 } ])
    end

    it "雨天中止があっても総数は動かず、未振替に出る。予備日を試合日にして振り替えると未振替が減る" do
      team = create(:team)
      season = season_with(team, results: 1)
      SeasonSchedule.find_by!(season: season, date: day + 1).update!(date_type: "postponed")

      get path
      expect(response.parsed_body.first).to include("regular_played" => 1, "regular_total" => 5, "regular_unrescheduled" => 1)

      SeasonSchedule.find_by!(season: season, date: day + 5).update!(date_type: "game_day", score: 4, opponent_score: 3)

      get path
      expect(response.parsed_body.first).to include("regular_played" => 2, "regular_total" => 5, "regular_unrescheduled" => 0)
    end
  end

  context "一般ユーザー" do
    include_context "authenticated user"

    it "403 を返す" do
      get path
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "未認証" do
    it "401 を返す" do
      get path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
