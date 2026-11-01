require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §4.5「契約・カードの変更（その日から）で保存値を作り直す。疲労P がカードで決まるため」。
# カードの変更だけが引き金（PitcherStarterFatigue はカードの先発疲労P だけを読む）。契約（selected_cost_type）だけの変更は引き金にしない。
RSpec.describe "チーム編成の保存と登板の保存値の作り直し（段3）", type: :request, pitcher_fatigue: true do
  include_context "authenticated commissioner"

  let(:cost) { create(:cost, end_date: nil) }
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher_and_membership) { create_card_pitcher(team: team, starter_stamina: 7) }
  let(:pitcher) { pitcher_and_membership[0] }
  let(:membership) { pitcher_and_membership[1] }
  let(:card_b) { create(:player_card, player: pitcher, card_type: "pitcher", starter_stamina: 5) }

  # 6/1 と 6/10（中8日。補正なしなのでカードの先発疲労P がそのまま入る）。保存値は 6/1 = 7（カード A）、6/10 = 7
  let!(:first_start) do
    create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
    create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 5.0, fatigue_p_used: 7)
  end
  let!(:second_start) do
    create_schedule(season, "2026-06-10", score: 0, opponent_score: 1)
    create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0, fatigue_p_used: 7)
  end

  before { create(:cost_player, cost: cost, player: pitcher, normal_cost: 4) }

  def post_players(overrides, date:)
    player = { player_id: pitcher.id, selected_cost_type: membership.selected_cost_type, excluded_from_team_total: false,
               display_name: nil, player_card_id: membership.reload.player_card_id }.merge(overrides)
    post "/api/v1/teams/#{team.id}/team_players", params: { players: [ player ], cost_list_id: cost.id, target_date: date, phase: "pre_game" }, as: :json
  end

  it "カードを変えると、変更の日以降の登板の疲労P がそのカードで作り直される（6/5 付け → 6/10 は P5。6/1 は触らない）" do
    post_players({ player_card_id: card_b.id }, date: "2026-06-05")
    expect(response).to have_http_status(:ok)
    expect(second_start.reload.fatigue_p_used).to eq(5)
    expect(first_start.reload.fatigue_p_used).to eq(7)
  end

  it "変更の日が登板日と同じなら、その日の登板も作り直す" do
    post_players({ player_card_id: card_b.id }, date: "2026-06-10")
    expect(second_start.reload.fatigue_p_used).to eq(5)
  end

  it "契約だけの変更（カード同じ）では作り直さない" do
    second_start.update_columns(fatigue_p_used: 99)
    post_players({ selected_cost_type: "pitcher_only_cost" }, date: "2026-06-05")
    expect(response).to have_http_status(:ok)
    expect(TeamMembershipChange.where(team_membership: membership, kind: "contract")).to exist
    expect(second_start.reload.fatigue_p_used).to eq(99)
  end

  it "値が何も変わらない保存では作り直さない" do
    second_start.update_columns(fatigue_p_used: 99)
    post_players({}, date: "2026-06-05")
    expect(response).to have_http_status(:ok)
    expect(second_start.reload.fatigue_p_used).to eq(99)
  end

  it "別の投手の登板は作り直さない" do
    other, = create_card_pitcher(team: team, starter_stamina: 7)
    theirs = create_start(team: team, pitcher: other, date: "2026-06-10", innings: 5.0, fatigue_p_used: 99, game: create(:game))
    post_players({ player_card_id: card_b.id }, date: "2026-06-05")
    expect(theirs.reload.fatigue_p_used).to eq(99)
  end

  it "作り直しが落ちても変更記録は保存され（200）、warnings に出る" do
    allow(PitcherHistoryRebuild).to receive(:from).and_raise(RuntimeError, "boom")
    expect { post_players({ player_card_id: card_b.id }, date: "2026-06-05") }.to change(TeamMembershipChange, :count).by_at_least(1)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["warnings"].grep(/作り直しに失敗/).size).to eq(1)
    expect(second_start.reload.fatigue_p_used).to eq(7)
  end
end
