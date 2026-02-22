require "rails_helper"

RSpec.describe BattingStatsCalculator do
  let(:competition) { create(:competition) }
  let(:home_team)   { create(:team) }
  let(:visitor_team) { create(:team) }
  let(:stadium)     { create(:stadium) }
  let(:batter)      { create(:player) }
  let(:pitcher)     { create(:player, :pitcher) }

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

  describe "#calculate" do
    context "confirmed at_batsのみ集計" do
      it "draft at_batsは除外する" do
        create(:at_bat,
          game: confirmed_game, batter: batter, pitcher: pitcher,
          result_code: "H", status: :confirmed, seq: 1
        )
        draft_game = create(:game,
          competition: competition, home_team: home_team,
          visitor_team: visitor_team, stadium: stadium, status: "draft"
        )
        create(:at_bat,
          game: draft_game, batter: batter, pitcher: pitcher,
          result_code: "H", status: :draft, seq: 1
        )

        stats = described_class.new(competition).calculate
        batter_stat = stats.find { |s| s[:player_id] == batter.id }
        expect(batter_stat[:at_bat_count]).to eq(1)
      end
    end

    context "打率計算" do
      it "3打数2安打→打率0.667" do
        [
          { code: "H",  seq: 1 },
          { code: "1B", seq: 2 },
          { code: "K",  seq: 3 }
        ].each do |d|
          create(:at_bat,
            game: confirmed_game, batter: batter, pitcher: pitcher,
            result_code: d[:code], status: :confirmed, seq: d[:seq]
          )
        end

        stats = described_class.new(competition).calculate
        s = stats.find { |x| x[:player_id] == batter.id }
        expect(s[:hits]).to eq(2)
        expect(s[:at_bat_count]).to eq(3)
        expect(s[:batting_average]).to eq(0.667)
      end
    end

    context "OPS計算" do
      it "出塁率+長打率を正しく計算する" do
        # 4打数: HR, BB, K, 1B
        # at_bat_count=3 (BB除く), hits=2, walks=1
        # OBP=(2+1)/(3+1)=0.75, SLG=(1+4)/3=1.667, OPS=2.417
        [
          { code: "HR", rbi: 1, seq: 1 },
          { code: "BB", rbi: 0, seq: 2 },
          { code: "K",  rbi: 0, seq: 3 },
          { code: "1B", rbi: 0, seq: 4 }
        ].each do |d|
          create(:at_bat,
            game: confirmed_game, batter: batter, pitcher: pitcher,
            result_code: d[:code], status: :confirmed, seq: d[:seq], rbi: d[:rbi]
          )
        end

        stats = described_class.new(competition).calculate
        s = stats.find { |x| x[:player_id] == batter.id }
        expect(s[:home_runs]).to eq(1)
        expect(s[:walks]).to eq(1)
        expect(s[:on_base_pct]).to eq(0.75)
        expect(s[:slugging_pct]).to eq(((1 + 4) / 3.0).round(3))
        expect(s[:ops]).to eq((s[:on_base_pct] + s[:slugging_pct]).round(3))
      end
    end

    context "確認済みゲームがない場合" do
      it "空配列を返す" do
        stats = described_class.new(competition).calculate
        expect(stats).to eq([])
      end
    end
  end
end
