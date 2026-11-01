require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §4.5「離脱の作成・変更・削除（開始日、変更前の開始日の早い方から）で保存値を作り直す」・§1.3 S8。
# 離脱を後から入れる・直す・消す、のどれでも後の登板の保存値（疲労P）が古いまま残らない。
RSpec.describe "PlayerAbsences の保存値の作り直し（段3）", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let(:membership) { TeamMembership.find_by!(team: team, player: pitcher) }

  # 6/1 → 6/7（中5日）。離脱が無ければ 6/7 の疲労P は 6（前が normal・中5日で -1）。保存値はわざと古い 99
  let!(:later) do
    create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
    create_schedule(season, "2026-06-07", score: 0, opponent_score: 1)
    create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 5.0)
    create_start(team: team, pitcher: pitcher, date: "2026-06-07", innings: 5.0, fatigue_p_used: 99)
  end

  def create_absence(start_date, type: "injury", phase: "pre_game", duration: 1)
    post "/api/v1/player_absences", params: { player_absence: {
      team_membership_id: membership.id, season_id: season.id, absence_type: type, start_date: start_date,
      duration: duration, duration_unit: "days", phase: phase
    } }, as: :json
  end

  describe "POST（作成）" do
    it "負傷を後から入れると、後の登板の疲労P が作り直される（負傷 1 日で中4日 → -3 で P4）" do
      create_absence("2026-06-02")
      expect(response).to have_http_status(:created)
      expect(later.reload.fatigue_p_used).to eq(4)
    end

    it "試合中の負傷（in_game）は翌日から数える。登板日 6/1 の in_game 1 日なら 6/2 が離脱で同じく P4" do
      create_absence("2026-06-01", phase: "in_game")
      expect(later.reload.fatigue_p_used).to eq(4)
    end

    it "離脱の開始日より前の登板は作り直さない（開始日以降だけ）" do
      earlier = PitcherGameState.find_by!(team: team, pitcher: pitcher, schedule_date: "2026-06-01")
      earlier.update_columns(fatigue_p_used: 55)
      create_absence("2026-06-02")
      expect(earlier.reload.fatigue_p_used).to eq(55)
    end

    it "出場停止は中日数から引かないので、作り直しても疲労P は離脱なしの値（6）になる" do
      create_absence("2026-06-02", type: "suspension")
      expect(response).to have_http_status(:created)
      expect(later.reload.fatigue_p_used).to eq(6)
    end

    it "別の選手の登板は作り直さない" do
      other = create_card_pitcher(team: team, starter_stamina: 7)[0]
      theirs = create_start(team: team, pitcher: other, date: "2026-06-07", innings: 5.0, fatigue_p_used: 99)
      create_absence("2026-06-02")
      expect(theirs.reload.fatigue_p_used).to eq(99)
    end

    it "登板の無い選手（野手）の離脱でも落ちない" do
      fielder = create(:team_membership, team: team, player: create(:player))
      post "/api/v1/player_absences", params: { player_absence: {
        team_membership_id: fielder.id, season_id: season.id, absence_type: "injury", start_date: "2026-06-02", duration: 1, duration_unit: "days"
      } }, as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).not_to have_key("warnings")
    end

    it "検証に失敗した作成（422）では作り直さない" do
      expect(PitcherHistoryRebuild).not_to receive(:guarded)
      create_absence("2026-06-02", duration: 0)
      expect(response).to have_http_status(:unprocessable_content)
      expect(later.reload.fatigue_p_used).to eq(99)
    end

    it "作り直しが落ちても離脱は保存され（201）、応答に warnings を足す" do
      allow(PitcherHistoryRebuild).to receive(:from).and_raise(RuntimeError, "boom")
      expect { create_absence("2026-06-02") }.to change(PlayerAbsence, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["warnings"].grep(/作り直しに失敗/).size).to eq(1)
      expect(response.parsed_body).to include("start_date" => "2026-06-02")
    end
  end

  describe "PATCH（変更）" do
    let!(:absence) { create(:player_absence, team_membership: membership, season: season, start_date: "2026-06-02", duration: 1) }

    it "開始日を登板より後へ動かすと、変更前の開始日（6/2）からの登板が作り直される（P4 → P6）" do
      later.update_columns(fatigue_p_used: 4)
      patch "/api/v1/player_absences/#{absence.id}", params: { player_absence: { start_date: "2026-06-09" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(later.reload.fatigue_p_used).to eq(6)
    end

    it "期間を伸ばすと疲労P が下がる方へ作り直される（2 日で中3日になり、normal の中3日は P0）" do
      patch "/api/v1/player_absences/#{absence.id}", params: { player_absence: { duration: 2 } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(later.reload.fatigue_p_used).to eq(0)
    end

    it "更新の応答は離脱そのもの（作り直しが成功した時は warnings を足さない）" do
      patch "/api/v1/player_absences/#{absence.id}", params: { player_absence: { reason: "x" } }, as: :json
      expect(response.parsed_body).to include("reason" => "x")
      expect(response.parsed_body).not_to have_key("warnings")
    end

    it "検証に失敗した変更（422）では作り直さない" do
      later.update_columns(fatigue_p_used: 99)
      patch "/api/v1/player_absences/#{absence.id}", params: { player_absence: { duration: 0 } }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(later.reload.fatigue_p_used).to eq(99)
    end
  end

  describe "DELETE（削除）" do
    it "離脱を消すと、後の登板の疲労P が離脱なしの値に作り直される" do
      absence = create(:player_absence, team_membership: membership, season: season, start_date: "2026-06-02", duration: 1)
      later.update_columns(fatigue_p_used: 4)
      delete "/api/v1/player_absences/#{absence.id}"
      expect(response).to have_http_status(:no_content)
      expect(later.reload.fatigue_p_used).to eq(6)
    end
  end
end
