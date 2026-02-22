require "rails_helper"

RSpec.describe PitchingStatsCalculator do
  let(:competition)  { create(:competition) }
  let(:home_team)    { create(:team) }
  let(:visitor_team) { create(:team) }
  let(:stadium)      { create(:stadium) }
  let(:pitcher_w)    { create(:player, :pitcher) }
  let(:pitcher_l)    { create(:player, :pitcher) }
  let(:batter)       { create(:player) }

  let(:confirmed_game) do
    create(:game,
      competition:   competition,
      home_team:     home_team,
      visitor_team:  visitor_team,
      stadium:       stadium,
      status:        "confirmed",
      home_score:    5,
      visitor_score: 2
    )
  end

  describe "#calculate" do
    context "decision=W の投手のみ wins+1 されること" do
      it "decision=W で勝利がカウントされ、decision=nil は wins=0 のまま" do
        create(:pitcher_game_state,
          game: confirmed_game, pitcher: pitcher_w, competition: competition,
          team: home_team, innings_pitched: 9.0, decision: "W", earned_runs: 0
        )
        create(:pitcher_game_state,
          game: confirmed_game, pitcher: pitcher_l, competition: competition,
          team: visitor_team, innings_pitched: 9.0, decision: nil, earned_runs: 0
        )

        stats = described_class.new(competition).calculate
        w_stat = stats.find { |s| s[:player_id] == pitcher_w.id }
        l_stat = stats.find { |s| s[:player_id] == pitcher_l.id }

        expect(w_stat[:wins]).to eq(1)
        expect(w_stat[:losses]).to eq(0)
        expect(l_stat[:wins]).to eq(0)
        expect(l_stat[:losses]).to eq(0)
      end
    end

    context "decision=L の投手のみ losses+1 されること" do
      it "decision=L で敗戦がカウントされ、decision=W の投手には losses が付かない" do
        create(:pitcher_game_state,
          game: confirmed_game, pitcher: pitcher_w, competition: competition,
          team: home_team, innings_pitched: 9.0, decision: "W", earned_runs: 0
        )
        create(:pitcher_game_state,
          game: confirmed_game, pitcher: pitcher_l, competition: competition,
          team: visitor_team, innings_pitched: 9.0, decision: "L", earned_runs: 0
        )

        stats = described_class.new(competition).calculate
        w_stat = stats.find { |s| s[:player_id] == pitcher_w.id }
        l_stat = stats.find { |s| s[:player_id] == pitcher_l.id }

        expect(w_stat[:wins]).to eq(1)
        expect(w_stat[:losses]).to eq(0)
        expect(l_stat[:wins]).to eq(0)
        expect(l_stat[:losses]).to eq(1)
      end
    end

    context "earned_runs から ERA が計算されること（RBI は使わない）" do
      it "pgs.earned_runs=3, innings_pitched=9.0 → ERA=3.0" do
        create(:pitcher_game_state,
          game: confirmed_game, pitcher: pitcher_w, competition: competition,
          team: home_team, innings_pitched: 9.0, decision: "W", earned_runs: 3
        )
        # RBIが高くても earned_runs が優先されることを確認するため at_bat を作成
        create(:at_bat,
          game: confirmed_game, batter: batter, pitcher: pitcher_w,
          result_code: "HR", status: :confirmed, seq: 1, rbi: 10, half: "top"
        )

        stats = described_class.new(competition).calculate
        w_stat = stats.find { |s| s[:player_id] == pitcher_w.id }

        expect(w_stat[:era]).to eq(3.0)
      end
    end

    context "confirms状態のゲームのみ集計されること" do
      it "draft ゲームの pitcher_game_state は無視される" do
        draft_game = create(:game,
          competition:   competition,
          home_team:     home_team,
          visitor_team:  visitor_team,
          stadium:       stadium,
          status:        "draft"
        )
        create(:pitcher_game_state,
          game: draft_game, pitcher: pitcher_w, competition: competition,
          team: home_team, innings_pitched: 9.0, decision: "W", earned_runs: 2
        )

        stats = described_class.new(competition).calculate
        expect(stats).to eq([])
      end
    end
  end
end
