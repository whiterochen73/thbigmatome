require "rails_helper"

RSpec.describe "Api::V1::Stats", type: :request do
  include_context "authenticated user"

  let(:competition) { create(:competition) }
  let(:home_team)   { create(:team) }
  let(:visitor_team) { create(:team) }
  let(:stadium)     { create(:stadium) }

  let(:confirmed_game) do
    create(:game,
      competition:  competition,
      home_team:    home_team,
      visitor_team: visitor_team,
      stadium:      stadium,
      status:       "confirmed",
      home_score:   3,
      visitor_score: 1
    )
  end

  describe "GET /api/v1/stats/batting" do
    context "大会が存在する場合" do
      it "200を返しbatting_statsキーを含むJSONを返す" do
        get "/api/v1/stats/batting?competition_id=#{competition.id}", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key("batting_stats")
        expect(json["batting_stats"]).to be_an(Array)
      end

      it "confirmed at_batsのみ集計される（draftは除外）" do
        batter  = create(:player)
        pitcher = create(:player, :pitcher)

        confirmed_ab = create(:at_bat,
          game:        confirmed_game,
          batter:      batter,
          pitcher:     pitcher,
          result_code: "H",
          status:      :confirmed,
          seq:         1
        )
        draft_game = create(:game,
          competition:  competition,
          home_team:    home_team,
          visitor_team: visitor_team,
          stadium:      stadium,
          status:       "draft"
        )
        create(:at_bat,
          game:        draft_game,
          batter:      batter,
          pitcher:     pitcher,
          result_code: "H",
          status:      :draft,
          seq:         1
        )

        get "/api/v1/stats/batting?competition_id=#{competition.id}", as: :json

        expect(response).to have_http_status(:ok)
        json         = response.parsed_body
        batting_stats = json["batting_stats"]
        expect(batting_stats).not_to be_empty
        # draftゲームのat_batは含まれないので1打席のみ
        batter_stat = batting_stats.find { |s| s["player_id"] == batter.id }
        expect(batter_stat["at_bat_count"]).to eq(1)
      end
    end

    context "competition_id不正の場合" do
      it "404を返す" do
        get "/api/v1/stats/batting?competition_id=999999", as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/stats/pitching" do
    context "大会が存在する場合" do
      it "200を返しpitching_statsキーを含むJSONを返す" do
        get "/api/v1/stats/pitching?competition_id=#{competition.id}", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key("pitching_stats")
        expect(json["pitching_stats"]).to be_an(Array)
      end
    end

    context "competition_id不正の場合" do
      it "404を返す" do
        get "/api/v1/stats/pitching?competition_id=999999", as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/stats/team" do
    context "大会が存在する場合" do
      it "200を返しteam_statsキーを含むJSONを返す" do
        get "/api/v1/stats/team?competition_id=#{competition.id}", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key("team_stats")
        expect(json["team_stats"]).to be_an(Array)
      end

      it "confirmedゲームのW/Lが正しく集計される" do
        confirmed_game  # 3-1でホーム勝利

        get "/api/v1/stats/team?competition_id=#{competition.id}", as: :json

        expect(response).to have_http_status(:ok)
        stats = response.parsed_body["team_stats"]
        home_stat    = stats.find { |s| s["team_id"] == home_team.id }
        visitor_stat = stats.find { |s| s["team_id"] == visitor_team.id }

        expect(home_stat["wins"]).to eq(1)
        expect(home_stat["losses"]).to eq(0)
        expect(visitor_stat["wins"]).to eq(0)
        expect(visitor_stat["losses"]).to eq(1)
      end
    end

    context "competition_id不正の場合" do
      it "404を返す" do
        get "/api/v1/stats/team?competition_id=999999", as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
