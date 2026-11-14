require "rails_helper"

# Test Basis: cmd_1896。期間外の日付の起用の記録（登板・先発メンバー）は止めず、警告にして保存する。
RSpec.describe "時限選手の起用の記録の警告", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let!(:schedule) { create_schedule(season, "2026-04-21") }

  before do
    team.update!(user: user)
    create_schedule(season, "2026-04-01")
    pitcher.player_cards.first.update!(unique_traits: "4/22~")
  end

  def put_lineup(date_schedule)
    put "/api/v1/game/#{date_schedule.id}", params: { starting_lineup: [ { player_id: pitcher.id, position: "P", order: 9 } ] }, as: :json
  end

  it "期間外の日の先発メンバーに入れると警告つきで保存する" do
    put_lineup(schedule)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["warnings"].first).to include(pitcher.name, "4/22 から", "2026-04-21")
    expect(schedule.reload.starting_lineup).to be_present
  end

  it "期間内の日（4/22）は警告なし" do
    ok_day = create_schedule(season, "2026-04-22")
    put_lineup(ok_day)
    expect(response.parsed_body["warnings"]).to eq([])
  end

  it "先発メンバーを更新しない保存では時限の警告を出さない" do
    put "/api/v1/game/#{schedule.id}", params: { stadium: "どこか" }, as: :json
    expect(response.parsed_body["warnings"]).to eq([])
  end

  it "期間外の日の登板は警告つきで保存する" do
    competition = create(:competition)
    post "/api/v1/pitcher_appearances", params: {
      pitcher_appearance: {
        pitcher_id: pitcher.id, team_id: team.id, competition_id: competition.id, role: "starter",
        innings_pitched: 6.0, earned_runs: 2, fatigue_p_used: 0, schedule_date: "2026-04-21", is_opener: false
      }
    }, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body["warnings"].join).to include("4/22 から")
  end
end
