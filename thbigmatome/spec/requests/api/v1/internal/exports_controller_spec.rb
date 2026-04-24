require "rails_helper"

RSpec.describe "Internal exports API", type: :request do
  let(:internal_api_key) { "test-internal-api-key" }
  let(:auth_headers) { { "X-Internal-Api-Key" => internal_api_key } }

  around do |example|
    original = ENV["INTERNAL_API_KEY"]
    ENV["INTERNAL_API_KEY"] = internal_api_key
    example.run
  ensure
    ENV["INTERNAL_API_KEY"] = original
  end

  describe "authentication" do
    it "rejects requests without the internal API key" do
      get "/api/v1/internal/players"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
    end

    it "rejects the development default key in production" do
      ENV["INTERNAL_API_KEY"] = Api::V1::InternalBaseController::DEVELOPMENT_INTERNAL_API_KEY
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      get "/api/v1/internal/players", headers: {
        "X-Internal-Api-Key" => Api::V1::InternalBaseController::DEVELOPMENT_INTERNAL_API_KEY
      }

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)).to include("error" => "Internal API key must be rotated in production")
    end
  end

  describe "GET /api/v1/internal/players" do
    before do
      create_list(:player, 25)
    end

    it "keeps the legacy array response when pagination params are absent" do
      get "/api/v1/internal/players", headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
      expect(json.size).to eq(25)
    end

    it "returns a limited page and metadata when pagination params are present" do
      get "/api/v1/internal/players", params: { page: 2, per_page: 10 }, headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json["players"].size).to eq(10)
      expect(json["players"].first["id"]).to eq(Player.order(:id).offset(10).first.id)
      expect(json["meta"]).to include(
        "current_page" => 2,
        "per_page" => 10,
        "total_count" => 25,
        "total_pages" => 3
      )
    end

    it "caps per_page to protect large export responses" do
      get "/api/v1/internal/players", params: { page: 1, per_page: 2_000 }, headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json["meta"]["per_page"]).to eq(1_000)
      expect(json["players"].size).to eq(25)
    end
  end
end
