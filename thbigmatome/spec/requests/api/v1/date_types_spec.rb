require "rails_helper"

# Test Basis: cmd_1784 段4。設計書 §4.6（試合日とみなす種別はサーバに 1 つ。API で画面へも返す。種別 no_game は新たに作れない）。
RSpec.describe "日付の種別（試合日の定義とノーゲーム）", type: :request do
  include_context "authenticated user"

  let(:team) { create(:team, user: user) }
  let(:season) { create(:season, team: team) }
  let!(:game_day) { create(:season_schedule, season: season, date: Date.new(2026, 5, 1), date_type: "game_day") }

  describe "GET /api/v1/teams/:team_id/season" do
    it "試合日とみなす種別をサーバの定義のまま返す（画面の isGameType がこれを使う）" do
      get "/api/v1/teams/#{team.id}/season"

      expect(response.parsed_body["game_date_types"]).to eq(SeasonSchedule::GAME_DATE_TYPES)
      expect(response.parsed_body["game_date_types"]).to eq(%w[game_day interleague_game_day playoff_day])
    end

    it "日程が無いシーズンでも返す" do
      empty = create(:team, user: user)
      create(:season, team: empty)

      get "/api/v1/teams/#{empty.id}/season"

      expect(response.parsed_body["game_date_types"]).to eq(SeasonSchedule::GAME_DATE_TYPES)
    end
  end

  describe "PATCH /api/v1/teams/:team_id/season/season_schedules/:id" do
    def patch_type(schedule, type)
      patch "/api/v1/teams/#{team.id}/season/season_schedules/#{schedule.id}", params: { season_schedule: { date_type: type } }, as: :json
    end

    it "種別 no_game は 422 で断り、種別も真偽値も変えない（ノーゲームは試合結果の真偽値で表す）" do
      patch_type(game_day, "no_game")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["date_type"].join).to include("no_game")
      expect(game_day.reload).to have_attributes(date_type: "game_day", no_game: false)
    end

    it "ほかの種別（予備日など）には変えられる" do
      patch_type(game_day, "reserve_day")

      expect(response).to have_http_status(:ok)
      expect(game_day.reload.date_type).to eq("reserve_day")
    end

    it "移行前に種別 no_game のまま残っている日は、試合日の種別に直せる" do
      legacy = legacy_no_game_schedule(season: season, date: Date.new(2026, 5, 2))

      patch_type(legacy, "game_day")

      expect(response).to have_http_status(:ok)
      expect(legacy.reload.date_type).to eq("game_day")
    end

    it "空の種別は変更せず、no_game の指定だけを断る（不正値の連打でも元の種別が残る）" do
      2.times { patch_type(game_day, "no_game") }

      expect(response).to have_http_status(:unprocessable_content)
      expect(game_day.reload.date_type).to eq("game_day")
    end
  end

  describe "POST /api/v1/schedules/:id/schedule_details/upsert_all（日程マスタ）" do
    let(:schedule) { Schedule.create!(name: "マスタ", start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 30)) }

    def upsert(types)
      details = types.each_with_index.map { |type, i| { date: (Date.new(2026, 4, 1) + i).to_s, date_type: type, schedule_id: schedule.id } }
      post "/api/v1/schedules/#{schedule.id}/schedule_details/upsert_all", params: { schedule_details: details }, as: :json
    end

    it "種別 no_game を含む保存は 422 で断り、1 件も保存しない" do
      upsert(%w[game_day no_game])

      expect(response).to have_http_status(:unprocessable_content)
      expect(schedule.schedule_details.count).to eq(0)
    end

    it "ほかの種別は保存できる" do
      upsert(%w[game_day reserve_day])

      expect(response).to have_http_status(:ok)
      expect(schedule.schedule_details.pluck(:date_type)).to match_array(%w[game_day reserve_day])
    end

    # AMB-11（Operator 裁定 2026-09-12）: 日程マスタのレギュラー（通常・交流戦）の試合日が 143 かを、upsert の後で検算する。cmd_1802
    it "レギュラーの試合日が 143 でなければ、保存したうえで応答に warnings を付ける（止めない）" do
      upsert(%w[game_day interleague_game_day reserve_day playoff_day])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].first).to include("レギュラー（通常・交流戦）の試合日が 2 日", "規定は 143 日")
      expect(schedule.schedule_details.count).to eq(4)
    end

    it "レギュラーの試合日がちょうど 143 なら warnings は付けない（本文なしの 200）。予備日・プレーオフ日は数えない" do
      upsert(Array.new(142, "game_day") + %w[interleague_game_day reserve_day playoff_day])

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_blank
    end

    it "142 日・144 日でも warnings を付ける（境界の前後）" do
      upsert(Array.new(142, "game_day"))
      expect(response.parsed_body["warnings"].first).to include("142 日")

      upsert(Array.new(144, "game_day"))
      expect(response.parsed_body["warnings"].first).to include("144 日")
    end
  end
end
