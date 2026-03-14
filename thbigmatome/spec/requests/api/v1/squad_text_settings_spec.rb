require "rails_helper"

RSpec.describe "Api::V1::SquadTextSettings", type: :request do
  let(:team) { create(:team) }

  def squad_text_settings_url
    "/api/v1/teams/#{team.id}/squad_text_settings"
  end

  describe "認証なしアクセス" do
    it "GET /squad_text_settings → 401" do
      get squad_text_settings_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "PUT /squad_text_settings → 401" do
      put squad_text_settings_url, params: { squad_text_setting: { position_format: "japanese" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/teams/:team_id/squad_text_settings" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    context "設定が存在する場合" do
      let!(:setting) { create(:squad_text_setting, team: team, position_format: "japanese") }

      it "200を返す" do
        get squad_text_settings_url
        expect(response).to have_http_status(:ok)
      end

      it "既存の設定を返す" do
        get squad_text_settings_url
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(setting.id)
        expect(json["position_format"]).to eq("japanese")
        expect(json["team_id"]).to eq(team.id)
        expect(json).to have_key("batting_stats_config")
        expect(json).to have_key("pitching_stats_config")
        expect(json).to have_key("updated_at")
      end
    end

    context "設定が存在しない場合（初回アクセス）" do
      it "200を返す（404しない）" do
        get squad_text_settings_url
        expect(response).to have_http_status(:ok)
      end

      it "デフォルト値で新規作成してレスポンスを返す" do
        expect {
          get squad_text_settings_url
        }.to change(SquadTextSetting, :count).by(1)

        json = JSON.parse(response.body)
        expect(json["position_format"]).to eq("english")
        expect(json["handedness_format"]).to eq("alphabet")
        expect(json["date_format"]).to eq("absolute")
        expect(json["section_header_format"]).to eq("bracket")
        expect(json["show_number_prefix"]).to eq(true)
      end

      it "batting_stats_configにデフォルト値が含まれる" do
        get squad_text_settings_url
        json = JSON.parse(response.body)
        config = json["batting_stats_config"]
        expect(config["avg"]).to eq(true)
        expect(config["hr"]).to eq(true)
        expect(config["rbi"]).to eq(true)
      end

      it "pitching_stats_configにデフォルト値が含まれる" do
        get squad_text_settings_url
        json = JSON.parse(response.body)
        config = json["pitching_stats_config"]
        expect(config["era"]).to eq(true)
        expect(config["so"]).to eq(true)
      end
    end
  end

  describe "PUT /api/v1/teams/:team_id/squad_text_settings" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    context "設定が存在する場合（update）" do
      let!(:setting) { create(:squad_text_setting, team: team) }

      it "200を返す" do
        put squad_text_settings_url,
            params: { squad_text_setting: { position_format: "japanese" } },
            as: :json
        expect(response).to have_http_status(:ok)
      end

      it "レコード数が増えない" do
        expect {
          put squad_text_settings_url,
              params: { squad_text_setting: { position_format: "japanese" } },
              as: :json
        }.not_to change(SquadTextSetting, :count)
      end

      it "設定が更新される" do
        put squad_text_settings_url,
            params: { squad_text_setting: { position_format: "japanese", handedness_format: "kanji" } },
            as: :json
        json = JSON.parse(response.body)
        expect(json["position_format"]).to eq("japanese")
        expect(json["handedness_format"]).to eq("kanji")
      end
    end

    context "設定が存在しない場合（create）" do
      it "200を返す" do
        put squad_text_settings_url,
            params: { squad_text_setting: { position_format: "japanese" } },
            as: :json
        expect(response).to have_http_status(:ok)
      end

      it "新規レコードを作成する" do
        expect {
          put squad_text_settings_url,
              params: { squad_text_setting: { position_format: "japanese" } },
              as: :json
        }.to change(SquadTextSetting, :count).by(1)
      end

      it "指定した設定値で作成される" do
        put squad_text_settings_url,
            params: { squad_text_setting: { position_format: "japanese" } },
            as: :json
        json = JSON.parse(response.body)
        expect(json["position_format"]).to eq("japanese")
      end
    end

    context "batting_stats_config / pitching_stats_config の更新" do
      let!(:setting) { create(:squad_text_setting, team: team) }

      it "batting_stats_configを更新できる" do
        put squad_text_settings_url,
            params: {
              squad_text_setting: {
                batting_stats_config: { "avg" => true, "hr" => true, "rbi" => true, "sb" => true, "obp" => false, "ops" => true, "ab_h" => false }
              }
            },
            as: :json
        json = JSON.parse(response.body)
        expect(json["batting_stats_config"]["sb"]).to eq(true)
        expect(json["batting_stats_config"]["ops"]).to eq(true)
      end

      it "pitching_stats_configを更新できる" do
        put squad_text_settings_url,
            params: {
              squad_text_setting: {
                pitching_stats_config: { "w_l" => true, "games" => true, "era" => true, "so" => true, "ip" => true, "hold" => true, "save" => true }
              }
            },
            as: :json
        json = JSON.parse(response.body)
        expect(json["pitching_stats_config"]["hold"]).to eq(true)
        expect(json["pitching_stats_config"]["save"]).to eq(true)
      end
    end

    context "show_number_prefixの更新" do
      let!(:setting) { create(:squad_text_setting, team: team, show_number_prefix: true) }

      it "falseに更新できる" do
        put squad_text_settings_url,
            params: { squad_text_setting: { show_number_prefix: false } },
            as: :json
        json = JSON.parse(response.body)
        expect(json["show_number_prefix"]).to eq(false)
      end
    end
  end
end
