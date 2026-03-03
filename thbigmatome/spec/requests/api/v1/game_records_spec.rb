require "rails_helper"

RSpec.describe "Api::V1::GameRecordsController", type: :request do
  describe "GET /api/v1/game_records" do
    include_context "authenticated user"

    it "空リストを返す" do
      get "/api/v1/game_records", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["game_records"]).to eq([])
      expect(json["pagination"]["total"]).to eq(0)
    end

    it "game_recordsを降順で返す" do
      records = create_list(:game_record, 3)
      get "/api/v1/game_records", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["game_records"].size).to eq(3)
      expect(json["game_records"].map { |r| r["id"] }).to eq(records.map(&:id).sort.reverse)
    end

    it "team_idでフィルタできる" do
      team1 = create(:team)
      team2 = create(:team)
      gr1 = create(:game_record, team: team1)
      create(:game_record, team: team2)

      get "/api/v1/game_records?team_id=#{team1.id}", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["game_records"].size).to eq(1)
      expect(json["game_records"].first["id"]).to eq(gr1.id)
    end

    it "statusでフィルタできる" do
      create(:game_record, status: "draft")
      confirmed = create(:game_record, :confirmed)

      get "/api/v1/game_records?status=confirmed", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["game_records"].size).to eq(1)
      expect(json["game_records"].first["id"]).to eq(confirmed.id)
    end

    it "paginationが正しく動作する" do
      create_list(:game_record, 5)
      get "/api/v1/game_records?page=1&per_page=2", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["game_records"].size).to eq(2)
      expect(json["pagination"]["total"]).to eq(5)
      expect(json["pagination"]["total_pages"]).to eq(3)
    end
  end

  describe "GET /api/v1/game_records (unauthenticated)" do
    it "未認証は401を返す" do
      get "/api/v1/game_records", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/game_records/:id" do
    include_context "authenticated user"

    it "at_bat_records含む詳細を返す" do
      game_record = create(:game_record)
      ab = create(:at_bat_record, game_record: game_record, ab_num: 1)

      get "/api/v1/game_records/#{game_record.id}", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["id"]).to eq(game_record.id)
      expect(json["at_bat_records"].size).to eq(1)
      expect(json["at_bat_records"].first["id"]).to eq(ab.id)
    end

    it "存在しないidは404を返す" do
      get "/api/v1/game_records/9999999", as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/game_records" do
    include_context "authenticated user"

    let(:team) { create(:team) }

    let(:valid_params) do
      {
        team_id: team.id,
        opponent_team_name: "対戦チーム",
        game_date: "2026-01-15",
        stadium: "甲子園",
        score_home: 5,
        score_away: 3,
        result: "win",
        parser_version: "1.0.0",
        parsed_at: Time.current.iso8601
      }
    end

    it "game_recordを作成しdraftステータスで返す" do
      post "/api/v1/game_records", params: valid_params, as: :json
      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["status"]).to eq("draft")
      expect(json["team_id"]).to eq(team.id)
      expect(json["opponent_team_name"]).to eq("対戦チーム")
    end

    it "at_bat_recordsを一括保存できる" do
      params_with_ab = valid_params.merge(
        at_bat_records: [
          {
            inning: 1, half: "top", ab_num: 1,
            pitcher_name: "投手A", batter_name: "打者B",
            result_code: "H", strategy: "hitting",
            outs_before: 0, outs_after: 1, runs_scored: 0,
            runners_before: {}, runners_after: {}, extra_data: {}
          },
          {
            inning: 1, half: "top", ab_num: 2,
            pitcher_name: "投手A", batter_name: "打者C",
            result_code: "K", strategy: "hitting",
            outs_before: 1, outs_after: 2, runs_scored: 0,
            runners_before: {}, runners_after: {}, extra_data: {}
          }
        ]
      )

      post "/api/v1/game_records", params: params_with_ab, as: :json
      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["at_bat_records"].size).to eq(2)
    end

    it "不正なresultはエラー" do
      post "/api/v1/game_records", params: valid_params.merge(result: "invalid"), as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/game_records/:id/confirm" do
    include_context "authenticated user"

    it "draftからconfirmedに変更する" do
      game_record = create(:game_record, status: "draft")
      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["status"]).to eq("confirmed")
      expect(json["confirmed_at"]).not_to be_nil
    end

    it "confirm時に全打席のis_reviewedがtrueになる" do
      game_record = create(:game_record, status: "draft")
      ab1 = create(:at_bat_record, game_record: game_record, ab_num: 1, is_reviewed: false)
      ab2 = create(:at_bat_record, game_record: game_record, ab_num: 2, is_reviewed: false)

      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)
      expect(ab1.reload.is_reviewed).to be true
      expect(ab2.reload.is_reviewed).to be true
    end

    it "既にconfirmedのときはエラー" do
      game_record = create(:game_record, :confirmed)
      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "存在しないidは404を返す" do
      post "/api/v1/game_records/9999999/confirm", as: :json
      expect(response).to have_http_status(:not_found)
    end

    # C3確認テスト: stats永続化
    it "POST confirm後に game_record.batting_stats が保存される" do
      game_record = create(:game_record, status: "draft")
      batter = create(:player)
      pitcher = create(:player)
      create(:at_bat_record, game_record: game_record, ab_num: 1,
             batter_id: batter.id, batter_name: batter.name,
             pitcher_id: pitcher.id, pitcher_name: pitcher.name,
             result_code: "H", runs_scored: 1, adopted_value: nil)

      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)

      game_record.reload
      json = response.parsed_body
      expect(json["batting_stats"]).to be_present
      expect(json["batting_stats"]).to be_a(Hash)
    end

    it "POST confirm後に game_record.pitching_stats が保存される" do
      game_record = create(:game_record, status: "draft")
      batter = create(:player)
      pitcher = create(:player)
      create(:at_bat_record, game_record: game_record, ab_num: 1,
             batter_id: batter.id, batter_name: batter.name,
             pitcher_id: pitcher.id, pitcher_name: pitcher.name,
             result_code: "K", runs_scored: 0, adopted_value: nil)

      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)

      game_record.reload
      json = response.parsed_body
      expect(json["pitching_stats"]).to be_present
      expect(json["pitching_stats"]).to be_a(Hash)
    end

    it "HR コードが home_runs にカウントされる" do
      game_record = create(:game_record, status: "draft")
      batter = create(:player)
      pitcher = create(:player)
      create(:at_bat_record, game_record: game_record, ab_num: 1,
             batter_id: batter.id, batter_name: batter.name,
             pitcher_id: pitcher.id, pitcher_name: pitcher.name,
             result_code: "HR7", runs_scored: 1, adopted_value: nil)

      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      batter_stats = json["batting_stats"][batter.id.to_s]
      expect(batter_stats["home_runs"]).to eq(1)
    end

    it "HR コードが hits にカウントされる" do
      game_record = create(:game_record, status: "draft")
      batter = create(:player)
      pitcher = create(:player)
      create(:at_bat_record, game_record: game_record, ab_num: 1,
             batter_id: batter.id, batter_name: batter.name,
             pitcher_id: pitcher.id, pitcher_name: pitcher.name,
             result_code: "HR7", runs_scored: 1, adopted_value: nil)

      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      batter_stats = json["batting_stats"][batter.id.to_s]
      expect(batter_stats["hits"]).to eq(1)
    end

    it "HR コードが hits のみ（単打扱いにならない）" do
      game_record = create(:game_record, status: "draft")
      batter = create(:player)
      pitcher = create(:player)
      create(:at_bat_record, game_record: game_record, ab_num: 1,
             batter_id: batter.id, batter_name: batter.name,
             pitcher_id: pitcher.id, pitcher_name: pitcher.name,
             result_code: "HR7", runs_scored: 1, adopted_value: nil)

      post "/api/v1/game_records/#{game_record.id}/confirm", as: :json
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      batter_stats = json["batting_stats"][batter.id.to_s]
      # HR は home_runs としてカウントされ、hits は1のみ（単打として重複しない）
      expect(batter_stats["home_runs"]).to eq(1)
      expect(batter_stats["hits"]).to eq(1)
      expect(batter_stats["at_bats"]).to eq(1)
    end
  end
end
