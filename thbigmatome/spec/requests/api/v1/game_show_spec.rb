require "rails_helper"

# Test Basis: cmd_1812 試合日ページ上の段（相手の短縮形・予告先発の選手名を GET /api/v1/game/:id で返す）
RSpec.describe "GET /api/v1/game/:id（上の段に出す名前）", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:team_and_season) { create_team_with_season }
  let(:season) { team_and_season[1] }

  def head_of(schedule)
    get "/api/v1/game/#{schedule.id}", as: :json
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  it "相手の短縮形と、予告先発の選手名（背番号なし）を返す。相手の正式名はこれまでどおり返す" do
    opponent = create(:team, name: "命懸ヶ丘高校", short_name: "命懸")
    pitcher, membership = create_card_pitcher(team: team_and_season[0], starter_stamina: 7)
    pitcher.update!(name: "古明地 さとり", number: "18")
    schedule = create(:season_schedule, season: season, date: "2026-05-07",
                                        opponent_team: opponent, announced_starter: membership)

    json = head_of(schedule)

    expect(json["opponent_team_short_name"]).to eq("命懸")
    expect(json["opponent_team"]).to eq("命懸ヶ丘高校")
    expect(json["announced_starter_name"]).to eq("古明地 さとり")
  end

  it "短縮形が空のチームは、正式名を返す（nil・空文字のどちらも）" do
    { nil => "2026-05-08", "" => "2026-05-09" }.each do |blank, date|
      opponent = create(:team, name: "短縮形なし学園", short_name: blank)
      schedule = create(:season_schedule, season: season, date: date, opponent_team: opponent)

      expect(head_of(schedule)["opponent_team_short_name"]).to eq("短縮形なし学園")
    end
  end

  it "相手も予告先発も決まっていない日は、どちらも nil（キーは返す）" do
    schedule = create(:season_schedule, season: season, date: "2026-05-12")

    json = head_of(schedule)

    expect(json).to include("opponent_team_short_name" => nil, "announced_starter_name" => nil)
  end

  it "相手だけ決まっている日は、予告先発だけ nil" do
    opponent = create(:team, short_name: "若尊")
    schedule = create(:season_schedule, season: season, date: "2026-05-08", opponent_team: opponent)

    expect(head_of(schedule)).to include("opponent_team_short_name" => "若尊", "announced_starter_name" => nil)
  end

  describe "PUT（保存した直後の画面が同じ名前を取り直さずに使えるよう、同じ 2 つを返す）" do
    it "相手と予告先発を保存した応答に、短縮形と選手名が入る" do
      opponent = create(:team, short_name: "足立")
      _pitcher, membership = create_card_pitcher(team: team_and_season[0], starter_stamina: 7)
      schedule = create(:season_schedule, season: season, date: "2026-05-10")

      put "/api/v1/game/#{schedule.id}",
          params: { opponent_team_id: opponent.id, announced_starter_id: membership.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "opponent_team_short_name" => "足立",
        "announced_starter_name" => membership.player.name
      )
    end

    it "相手を外して保存すると nil に戻る" do
      opponent = create(:team, short_name: "足立")
      schedule = create(:season_schedule, season: season, date: "2026-05-10", opponent_team: opponent)

      put "/api/v1/game/#{schedule.id}", params: { opponent_team_id: nil }, as: :json

      expect(response.parsed_body).to include("opponent_team_short_name" => nil)
    end
  end
end
