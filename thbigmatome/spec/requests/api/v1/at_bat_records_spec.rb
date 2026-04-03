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
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "存在しないidは404を返す" do
      patch "/api/v1/at_bat_records/9999999",
            params: { result_code: "H" },
            as: :json
      expect(response).to have_http_status(:not_found)
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

  describe "PATCH /api/v1/at_bat_records/:id (is_reviewed / review_notes)" do
    include_context "authenticated user"

    let(:game_record) { create(:game_record) }
    let(:at_bat_record) { create(:at_bat_record, game_record: game_record) }

    it "is_reviewed を true にできる" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { is_reviewed: true },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["is_reviewed"]).to be true
    end

    it "review_notes を保存できる" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { review_notes: "確認済。エンドラン補正漏れ疑い。" },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["review_notes"]).to eq("確認済。エンドラン補正漏れ疑い。")
    end

    it "discrepancyがあるフィールドを更新するとresolutionがmanualになる" do
      ab_with_disc = create(:at_bat_record, game_record: game_record,
        discrepancies: [
          { "field" => "runners_after", "text_value" => [ 1 ], "gsm_value" => [ 2, 3 ], "cause" => "unknown", "resolution" => nil }
        ])

      patch "/api/v1/at_bat_records/#{ab_with_disc.id}",
            params: { runners_after: [ 2, 3 ] },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      disc = json["discrepancies"].first
      expect(disc["resolution"]).to eq("manual")
    end

    it "runners_before/runners_after を配列で更新できる" do
      patch "/api/v1/at_bat_records/#{at_bat_record.id}",
            params: { runners_before: [ 1 ], runners_after: [ 2, 3 ] },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["runners_before"]).to include(1)
      expect(json["runners_after"]).to include(2, 3)
    end

    # C1回帰テスト: || バグ修正確認
    it "runs_scored=0 を送ると adopted_value.runs_scored=0 になること（C1回帰テスト）" do
      ab = create(:at_bat_record, game_record: game_record, result_code: "K", runs_scored: 1)

      patch "/api/v1/at_bat_records/#{ab.id}",
            params: { runs_scored: 0 },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["adopted_value"]).to be_present
      expect(json["adopted_value"]["runs_scored"]).to eq(0)
    end

    it "outs_before=0 を送ると adopted_value.outs_before=0 になること（C1回帰テスト）" do
      ab = create(:at_bat_record, game_record: game_record, outs_before: 1)

      patch "/api/v1/at_bat_records/#{ab.id}",
            params: { outs_before: 0 },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["adopted_value"]).to be_present
      expect(json["adopted_value"]["outs_before"]).to eq(0)
    end

    it "PATCH後に adopted_value が正しく保存される" do
      ab = create(:at_bat_record, game_record: game_record, result_code: "K")

      patch "/api/v1/at_bat_records/#{ab.id}",
            params: { result_code: "H", runs_scored: 1, outs_before: 0, outs_after: 1 },
            as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["adopted_value"]).to include(
        "result_code" => "H",
        "runs_scored" => 1,
        "outs_before" => 0,
        "outs_after" => 1
      )
    end
  end
end
