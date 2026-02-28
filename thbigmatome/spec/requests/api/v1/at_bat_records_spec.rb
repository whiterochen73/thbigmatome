require "rails_helper"

RSpec.describe "Api::V1::AtBatRecordsController", type: :request do
  describe "PATCH /api/v1/at_bat_records/:id" do
    include_context "authenticated user"

    let(:game_record) { create(:game_record) }
    let(:at_bat_record) { create(:at_bat_record, game_record: game_record, result_code: "K", runs_scored: 0) }

    it "打席記録を修正し is_modified=true になる" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { result_code: "H", runs_scored: 1 },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["result_code"]).to eq("H")
      expect(json["runs_scored"]).to eq(1)
      expect(json["is_modified"]).to be true
    end

    it "modified_fieldsに変更履歴が記録される" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { result_code: "H" },
            as: :json
      json = response.parsed_body
      expect(json["modified_fields"]).to be_present
      expect(json["modified_fields"]["result_code"]).to include("from" => "K", "to" => "H")
    end

    it "累積修正で modified_fields が保持される" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { result_code: "H" },
            as: :json
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { runs_scored: 2 },
            as: :json
      json = response.parsed_body
      expect(json["modified_fields"].keys).to include("result_code", "runs_scored")
    end

    it "不正なstrategyはエラー" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { strategy: "invalid" },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "存在しないidは404を返す" do
      patch "/api/v1/at_bat_records/9999999",
            params: { result_code: "H" },
            as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "未認証は401を返す" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { result_code: "H" },
            as: :json
      # at_bat_recordを先に作成してからログアウト状態でテスト
      # cookieリセットのため新しいセッションで試行
    end
  end

  describe "PATCH /api/v1/at_bat_records/:id (unauthenticated)" do
    it "未認証は401を返す" do
      game_record = create(:game_record)
      ab = create(:at_bat_record, game_record: game_record)
      patch "/api/v1/at_bat_records/#{ab.id}",
            params: { result_code: "H" },
            as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
