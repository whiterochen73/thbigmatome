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

    # Test Basis: cmd_1836（Operator 2026-11-05「最終試合日にも選手登録、昇降格、離脱の登録ができるように」）
    it "最終試合日に結果が入った後は、current_range が最終試合日の 1 日で、current_date も最終試合日" do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(score: 5, opponent_score: 5)

      get "/api/v1/teams/#{team.id}/season"

      json = response.parsed_body
      expect(json["current_range"]).to eq("start_date" => "2026-05-04", "end_date" => "2026-05-04")
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

    it "最終試合日に結果が入った後も false（今の範囲が最終試合日になっても、キープレイヤーは設定できない）" do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(score: 5, opponent_score: 5)

      get "/api/v1/teams/#{team.id}/roster"

      expect(response.parsed_body).to include("key_player_selectable" => false)
    end

    it "結果が 1 件も無い間は true（現在日が初日でなくても）" do
      SeasonSchedule.where(season: season).update_all(score: nil, opponent_score: nil)

      get "/api/v1/teams/#{team.id}/roster"

      expect(response.parsed_body).to include("key_player_selectable" => true)
    end
  end

  # cmd_1975: プレーオフの日が空の間は範囲なし。範囲なしでも初日の試合日ページから相手を保存でき、保存すると範囲が初日まで伸びる
  # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 設計書 §5.3 の 2026-11-25 追記
  describe "プレーオフの日が空のシーズン" do
    include PitcherFatigueScenario

    let(:opponent) { create(:team) }

    before do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(date_type: "playoff_day")
      create(:season_schedule, season: season, date: d(5), date_type: "playoff_day")
      SeasonSchedule.find_by!(season: season, date: d(2)).update!(score: 0, opponent_score: 4)
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "レギュラー最終戦の結果の後は、プレーオフの日を数えず、範囲は最後に結果が入った日だけ" do
      get "/api/v1/teams/#{team.id}/season"

      json = response.parsed_body
      expect(json["current_date"]).to eq("2026-05-02")
      expect(json["current_range"]).to eq("start_date" => "2026-05-02", "end_date" => "2026-05-02")
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "範囲の外のプレーオフ初日へ、相手を保存できる。保存すると範囲がプレーオフ初日まで伸びる" do
      first_playoff = SeasonSchedule.find_by!(season: season, date: d(4))

      put "/api/v1/game/#{first_playoff.id}", params: { opponent_team_id: opponent.id }, as: :json
      expect(response).to have_http_status(:ok)

      get "/api/v1/teams/#{team.id}/season"
      expect(response.parsed_body["current_range"]).to eq("start_date" => "2026-05-03", "end_date" => "2026-05-04")
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "オーダーも範囲に関係なく保存できる" do
      first_playoff = SeasonSchedule.find_by!(season: season, date: d(4))
      lineup = [ { player_id: create(:player).id, position: "CF", order: 1 } ]

      put "/api/v1/game/#{first_playoff.id}", params: { starting_lineup: lineup }, as: :json

      expect(response).to have_http_status(:ok)
      expect(first_playoff.reload.starting_lineup).to be_present
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "予告先発も範囲に関係なく保存できる" do
      first_playoff = SeasonSchedule.find_by!(season: season, date: d(4))
      _pitcher, membership = create_card_pitcher(team: team, starter_stamina: 7)

      put "/api/v1/game/#{first_playoff.id}", params: { announced_starter_id: membership.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(first_playoff.reload.announced_starter_id).to eq(membership.id)
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "画面が送る全項目の PUT で、球場・ホーム／ビジター・DH だけを変えても印にならない（範囲は変わらない）" do
      first_playoff = SeasonSchedule.find_by!(season: season, date: d(4))
      # 画面は GET /game/:id の応答をそのまま PUT する。応答に home_away などを足して送り返す
      get "/api/v1/game/#{first_playoff.id}"
      payload = response.parsed_body.slice(*%w[announced_starter_id stadium real_date real_start_time venue game_log home_away
                                               designated_hitter_enabled opponent_team_id score opponent_score no_game
                                               scoreboard starting_lineup opponent_starting_lineup])
                        .merge("stadium" => "x", "venue" => "ch1", "home_away" => "home", "designated_hitter_enabled" => true)

      put "/api/v1/game/#{first_playoff.id}", params: payload, as: :json
      expect(response).to have_http_status(:ok)

      get "/api/v1/teams/#{team.id}/season"
      expect(response.parsed_body["current_range"]).to eq("start_date" => "2026-05-02", "end_date" => "2026-05-02")
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "相手を保存した後に空へ戻すと、範囲は元に戻る" do
      first_playoff = SeasonSchedule.find_by!(season: season, date: d(4))
      put "/api/v1/game/#{first_playoff.id}", params: { opponent_team_id: opponent.id }, as: :json
      put "/api/v1/game/#{first_playoff.id}", params: { opponent_team_id: nil }, as: :json
      expect(response).to have_http_status(:ok)

      get "/api/v1/teams/#{team.id}/season"
      expect(response.parsed_body["current_range"]).to eq("start_date" => "2026-05-02", "end_date" => "2026-05-02")
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "プレーオフ初日に結果が入った後は、範囲が次のプレーオフの日まで" do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(score: 1, opponent_score: 0)

      get "/api/v1/teams/#{team.id}/season"
      expect(response.parsed_body["current_range"]).to eq("start_date" => "2026-05-05", "end_date" => "2026-05-05")
    end

    # Test Basis: cmd_1975 仕様 5（鶏と卵の確認）/ 仕様 1・3
    it "プレーオフ最終日に結果が入った後は、その 1 日だけ" do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(opponent_team_id: opponent.id)
      SeasonSchedule.find_by!(season: season, date: d(5)).update!(score: 1, opponent_score: 0)

      get "/api/v1/teams/#{team.id}/season"
      expect(response.parsed_body["current_range"]).to eq("start_date" => "2026-05-05", "end_date" => "2026-05-05")
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

    it "最終試合日に結果が入った後（今の範囲が最終試合日）も設定できない" do
      SeasonSchedule.find_by!(season: season, date: d(4)).update!(score: 5, opponent_score: 5)

      post "/api/v1/teams/#{team.id}/key_player", params: { key_player_id: membership.id }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end
end
