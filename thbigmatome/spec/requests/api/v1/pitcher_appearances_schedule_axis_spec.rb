require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §1.3 S7・S8・S12、§4.4 の 6、§4.5、§7 判断 5（1軍でない投手の登板は警告して保存し、要確認の帯に出す）。
# 登板を日程の行（season_schedule_id）に紐づけ、1軍でない投手の登板は止めずに警告にし、保存・削除のたびにそれ以降の保存値を作り直す。
# 境界: 日程の行が無い日・同じ日に複数・ノーゲームの日・移動日に登録した投手・プレーオフ・放出→再登録の投手。
RSpec.describe "PitcherAppearances（試合日を軸に・段3）", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:competition) { create(:competition) }
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let(:membership) { TeamMembership.find_by!(team: team, player: pitcher) }

  def first_since(date, phase: "pre_game")
    create(:season_roster, season: season, team_membership: membership, squad: "first", registered_on: date, phase: phase)
  end

  def bulk(date, pitchers_and_innings, game_id: nil)
    appearances = pitchers_and_innings.map do |p, innings|
      { pitcher_id: p.id, role: "starter", innings_pitched: innings, earned_runs: 0, fatigue_p_used: 0, is_opener: false,
        consecutive_short_rest_count: 0, pre_injury_days_excluded: 0 }
    end
    body = { team_id: team.id, competition_id: competition.id, schedule_date: date, appearances: appearances }
    body[:game_id] = game_id if game_id
    post "/api/v1/pitcher_appearances/bulk_save", params: { pitcher_appearances_bulk: body }, as: :json
  end

  describe "GET /api/v1/pitcher_appearances" do
    it "season_schedule_id と roster_status（1軍/2軍）を返す" do
      schedule = create_schedule(season, "2026-06-10")
      first_since(Date.new(2026, 6, 1))
      create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0)
      second_pitcher = create_card_pitcher(team: team, starter_stamina: 5)[0]
      create_start(team: team, pitcher: second_pitcher, date: "2026-06-10", innings: 1.0, role: "reliever", appearance_order: 1)

      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" }
      expect(response).to have_http_status(:ok)
      rows = response.parsed_body.index_by { |r| r["pitcher_id"] }
      expect(rows[pitcher.id]).to include("season_schedule_id" => schedule.id, "roster_status" => "first", "pitcher_name" => pitcher.name)
      expect(rows[second_pitcher.id]).to include("season_schedule_id" => schedule.id, "roster_status" => "second")
    end

    it "別の日程の行に紐づく登板は、同じ日付でも出さない（紐づけを正として読む）" do
      create_schedule(season, "2026-06-10")
      other = create_schedule(season, "2026-06-11")
      state = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0)
      state.update_columns(season_schedule_id: other.id)
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" }
      expect(response.parsed_body).to be_empty
    end

    it "日程の行が無い日の登板も読め、season_schedule_id は null" do
      first_since(Date.new(2026, 6, 1))
      create_start(team: team, pitcher: pitcher, date: "2026-06-20", innings: 5.0)
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-20" }
      expect(response.parsed_body.first).to include("season_schedule_id" => nil, "roster_status" => "first")
    end

    it "登板がなければ空配列で、チームが引けなくても落ちない" do
      get "/api/v1/pitcher_appearances", params: { team_id: 0, schedule_date: "2026-06-20" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "日付が読めない引数でも 500 にしない（roster_status は null）" do
      create(:pitcher_game_state, team: team, pitcher: pitcher, schedule_date: "bad", role: "starter")
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "bad" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["roster_status"]).to be_nil
    end

    it "放出済みの投手は not_on_team、2軍へ降格した投手は second" do
      first_since(Date.new(2026, 6, 1))
      create(:team_membership_change, team_membership: membership, season: season, kind: "join", effective_on: Date.new(2026, 6, 1))
      create(:season_roster, season: season, team_membership: membership, squad: "second", registered_on: Date.new(2026, 6, 12))
      create(:team_membership_change, team_membership: membership, season: season, kind: "release", effective_on: Date.new(2026, 6, 12))
      create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0)
      create_start(team: team, pitcher: pitcher, date: "2026-06-13", innings: 5.0, game: create(:game))
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" }
      expect(response.parsed_body.first["roster_status"]).to eq("first")
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-13" }
      expect(response.parsed_body.first["roster_status"]).to eq("not_on_team")
    end
  end

  describe "POST /api/v1/pitcher_appearances/bulk_save（紐づけ）" do
    it "日程の行に紐づけて保存する" do
      schedule = create_schedule(season, "2026-06-10")
      first_since(Date.new(2026, 6, 1))
      bulk("2026-06-10", [ [ pitcher, 6.0 ] ])
      expect(response).to have_http_status(:ok)
      expect(PitcherGameState.find_by!(team: team, pitcher: pitcher).season_schedule_id).to eq(schedule.id)
    end

    it "日程の行が無い日付でも保存でき（行は作らない）、紐づけは null" do
      first_since(Date.new(2026, 6, 1))
      expect { bulk("2026-06-20", [ [ pitcher, 6.0 ] ]) }.not_to change(SeasonSchedule, :count)
      expect(response).to have_http_status(:ok)
      expect(PitcherGameState.find_by!(team: team, pitcher: pitcher).season_schedule_id).to be_nil
    end

    it "ノーゲームの日・プレーオフの日の登板も、その日の日程の行に紐づく" do
      first_since(Date.new(2026, 6, 1))
      no_game = create(:season_schedule, season: season, date: "2026-06-10", date_type: "game_day", no_game: true)
      playoff = create(:season_schedule, season: season, date: "2026-06-11", date_type: "playoff_day")
      bulk("2026-06-10", [ [ pitcher, 2.0 ] ])
      bulk("2026-06-11", [ [ pitcher, 6.0 ] ])
      expect(PitcherGameState.where(team: team).order(:schedule_date).pluck(:season_schedule_id)).to eq([ no_game.id, playoff.id ])
    end

    it "同じ日に日程の行が複数あれば紐づけない（保存はできる）" do
      first_since(Date.new(2026, 6, 1))
      create_schedule(season, "2026-06-10")
      create_schedule(season, "2026-06-10")
      bulk("2026-06-10", [ [ pitcher, 6.0 ] ])
      expect(response).to have_http_status(:ok)
      expect(PitcherGameState.find_by!(team: team, pitcher: pitcher).season_schedule_id).to be_nil
    end
  end

  describe "POST /api/v1/pitcher_appearances/bulk_save（1軍でない投手の登板）" do
    before { create_schedule(season, "2026-06-10") }

    it "2軍の投手の登板は止めずに保存し、警告を返す（判断 5）" do
      expect { bulk("2026-06-10", [ [ pitcher, 6.0 ] ]) }.to change(PitcherGameState, :count).by(1)
      expect(response).to have_http_status(:ok)
      warnings = response.parsed_body["warnings"]
      expect(warnings.grep(/1軍にいません（2軍）/).size).to eq(1)
      expect(warnings.grep(/#{pitcher.name}/).size).to eq(1)
    end

    it "1軍の投手には警告を出さない" do
      first_since(Date.new(2026, 6, 10))
      bulk("2026-06-10", [ [ pitcher, 6.0 ] ])
      expect(response.parsed_body["warnings"].grep(/1軍にいません/)).to be_empty
    end

    it "移動日に登録した投手が翌日の試合に登板しても警告しない" do
      create(:season_schedule, season: season, date: "2026-06-09", date_type: "travel_day")
      first_since(Date.new(2026, 6, 9))
      bulk("2026-06-10", [ [ pitcher, 6.0 ] ])
      expect(response.parsed_body["warnings"].grep(/1軍にいません/)).to be_empty
    end

    it "試合後に抹消した投手の登板は警告しない（同じ日の post_game）" do
      first_since(Date.new(2026, 6, 1))
      create(:season_roster, season: season, team_membership: membership, squad: "second", registered_on: Date.new(2026, 6, 10), phase: "post_game")
      bulk("2026-06-10", [ [ pitcher, 6.0 ] ])
      expect(response.parsed_body["warnings"].grep(/1軍にいません/)).to be_empty
    end

    it "放出後の投手の登板は、在籍なしとして警告する（保存はする）" do
      first_since(Date.new(2026, 6, 1))
      create(:team_membership_change, team_membership: membership, season: season, kind: "join", effective_on: Date.new(2026, 6, 1))
      create(:team_membership_change, team_membership: membership, season: season, kind: "release", effective_on: Date.new(2026, 6, 5))
      expect { bulk("2026-06-10", [ [ pitcher, 6.0 ] ]) }.to change(PitcherGameState, :count).by(1)
      expect(response.parsed_body["warnings"].grep(/チームに在籍していない/).size).to eq(1)
    end

    it "チームの登録が無い投手の登板も保存し、警告する" do
      stranger = create(:player, :pitcher)
      expect { bulk("2026-06-10", [ [ stranger, 6.0 ] ]) }.to change(PitcherGameState, :count).by(1)
      expect(response.parsed_body["warnings"].grep(/チームの登録が無い/).size).to eq(1)
    end

    it "何も保存しない（登板を全部消す）リクエストでは警告を出さない" do
      first = create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 5.0)
      bulk("2026-06-10", [], game_id: first.game_id)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].grep(/1軍にいません/)).to be_empty
    end
  end

  describe "POST /api/v1/pitcher_appearances（単発）" do
    it "2軍の投手でも作成でき（201）、警告を返す" do
      create_schedule(season, "2026-06-10")
      game = create(:game, competition: competition)
      post "/api/v1/pitcher_appearances", params: {
        pitcher_appearance: { pitcher_id: pitcher.id, team_id: team.id, competition_id: competition.id, game_id: game.id, role: "starter",
                              innings_pitched: 6.0, earned_runs: 0, schedule_date: "2026-06-10", is_opener: false }
      }, as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["warnings"].grep(/1軍にいません（2軍）/).size).to eq(1)
      expect(PitcherGameState.find_by!(team: team, pitcher: pitcher).season_schedule_id).to eq(SeasonSchedule.find_by!(date: "2026-06-10").id)
    end
  end

  describe "保存値の作り直し（PitcherHistoryRebuild）" do
    before do
      create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
      create_schedule(season, "2026-06-07", score: 0, opponent_score: 1)
      first_since(Date.new(2026, 5, 1))
    end

    # 6/7 の先発の保存値は、6/1 の登板の有無で変わる（前登板なし → 7、前が normal・中5日 → 6）
    let!(:later) { create_start(team: team, pitcher: pitcher, date: "2026-06-07", innings: 5.0, fatigue_p_used: 7) }

    it "前の日付の登板を後から入れると、それ以降の登板の保存値が作り直される" do
      bulk("2026-06-01", [ [ pitcher, 5.0 ] ])
      expect(later.reload.fatigue_p_used).to eq(6)
    end

    it "登板を消すと、それ以降の登板の保存値が作り直される" do
      bulk("2026-06-01", [ [ pitcher, 5.0 ] ])
      expect(later.reload.fatigue_p_used).to eq(6)
      earlier = PitcherGameState.find_by!(team: team, pitcher: pitcher, schedule_date: "2026-06-01")
      bulk("2026-06-01", [], game_id: earlier.game_id)
      expect(PitcherGameState.where(id: earlier.id)).to be_empty
      expect(later.reload.fatigue_p_used).to eq(7)
    end

    it "試合日を送らずに（game_id だけで）登板を全部消しても、消した登板の日付から作り直す" do
      bulk("2026-06-01", [ [ pitcher, 5.0 ] ])
      expect(later.reload.fatigue_p_used).to eq(6)
      earlier = PitcherGameState.find_by!(team: team, pitcher: pitcher, schedule_date: "2026-06-01")
      post "/api/v1/pitcher_appearances/bulk_save",
           params: { pitcher_appearances_bulk: { team_id: team.id, game_id: earlier.game_id, appearances: [] } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(PitcherGameState.where(id: earlier.id)).to be_empty
      expect(later.reload.fatigue_p_used).to eq(7)
    end

    it "別の投手の保存値は作り直さない" do
      other = create_card_pitcher(team: team, starter_stamina: 7)[0]
      theirs = create_start(team: team, pitcher: other, date: "2026-06-07", innings: 5.0, fatigue_p_used: 99)
      bulk("2026-06-01", [ [ pitcher, 5.0 ] ])
      expect(theirs.reload.fatigue_p_used).to eq(99)
    end

    it "保存した日そのものの値は、作り直しで上書きしない（画面が明示した result_category を残す）" do
      post "/api/v1/pitcher_appearances/bulk_save", params: {
        pitcher_appearances_bulk: { team_id: team.id, competition_id: competition.id, schedule_date: "2026-06-01",
                                    appearances: [ { pitcher_id: pitcher.id, role: "starter", innings_pitched: 5.0, earned_runs: 0, result_category: "ko",
                                                     is_opener: false, pre_injury_days_excluded: 0 } ] }
      }, as: :json
      expect(PitcherGameState.find_by!(team: team, pitcher: pitcher, schedule_date: "2026-06-01").result_category).to eq("ko")
    end

    it "作り直しが落ちても登板の保存は取り消さず、警告に出す（200）" do
      allow(PitcherHistoryRebuild).to receive(:from).and_raise(RuntimeError, "boom")
      expect { bulk("2026-06-01", [ [ pitcher, 5.0 ] ]) }.to change(PitcherGameState, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].grep(/作り直しに失敗/).size).to eq(1)
      expect(later.reload.fatigue_p_used).to eq(7)
    end

    it "単発の作成でも、それ以降の保存値が作り直される" do
      game = create(:game, competition: competition)
      post "/api/v1/pitcher_appearances", params: {
        pitcher_appearance: { pitcher_id: pitcher.id, team_id: team.id, competition_id: competition.id, game_id: game.id, role: "starter",
                              innings_pitched: 5.0, earned_runs: 0, schedule_date: "2026-06-01", is_opener: false }
      }, as: :json
      expect(response).to have_http_status(:created)
      expect(later.reload.fatigue_p_used).to eq(6)
    end

    it "検証で保存に失敗したら（422）作り直しは動かない" do
      expect(PitcherHistoryRebuild).not_to receive(:guarded)
      post "/api/v1/pitcher_appearances/bulk_save", params: {
        pitcher_appearances_bulk: { team_id: team.id, competition_id: competition.id, schedule_date: "2026-06-01",
                                    appearances: [ { pitcher_id: pitcher.id, role: "bogus", innings_pitched: 5.0, earned_runs: 0 } ] }
      }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
