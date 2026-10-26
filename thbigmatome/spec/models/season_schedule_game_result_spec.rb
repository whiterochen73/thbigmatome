require "rails_helper"

# Test Basis: 台帳 D-11 再確認（2026-10-26 Operator）「ノーゲームは負傷と登板の疲労計算だけはする。勝敗・成績は算入しない」/
#   cmd_1775 第3段の追補（シーズン画面の勝敗の印がノーゲームを見ていなかった）
RSpec.describe SeasonSchedule, "#game_result_hash" do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }
  let(:opponent) { create(:team, short_name: "相手") }

  def schedule(**attrs)
    create(:season_schedule, season: season, date: Date.new(2026, 3, 20), opponent_team: opponent, **attrs)
  end

  it "得点が両方あれば勝敗を返す（従来どおり）" do
    expect(schedule(score: 3, opponent_score: 1).game_result_hash).to eq({ opponent_short_name: "相手", score: "3 - 1", result: "win" })
    expect(schedule(score: 1, opponent_score: 3).game_result_hash[:result]).to eq("lose")
    expect(schedule(score: 2, opponent_score: 2).game_result_hash[:result]).to eq("draw")
  end

  it "得点が未入力なら nil（従来どおり）" do
    expect(schedule.game_result_hash).to be_nil
  end

  it "ノーゲームは、得点が勝ち・負け・引き分け相当でも勝敗を出さず result は no_game" do
    [ [ 5, 1 ], [ 0, 4 ], [ 2, 2 ] ].each do |mine, theirs|
      s = schedule(score: mine, opponent_score: theirs, no_game: true)
      expect(s.game_result_hash).to include(opponent_short_name: "相手", result: "no_game")
      s.destroy
    end
  end

  it "ノーゲームは得点を成績の印として出さない（score は nil）" do
    expect(schedule(score: 5, opponent_score: 1, no_game: true).game_result_hash[:score]).to be_nil
  end

  it "ノーゲームは得点が未入力でも印を返す（ノーゲームと分かる表示にするため）" do
    expect(schedule(no_game: true).game_result_hash).to include(result: "no_game")
  end

  it "ノーゲームを外せば得点の勝敗に戻る" do
    s = schedule(score: 5, opponent_score: 1, no_game: true)
    s.update!(no_game: false)
    expect(s.game_result_hash).to include(result: "win", score: "5 - 1")
  end

  it "SeasonScheduleSerializer の game_result にも no_game が出る" do
    s = schedule(score: 5, opponent_score: 1, no_game: true)
    json = JSON.parse(SeasonScheduleSerializer.new(s).to_json)
    expect(json["game_result"]).to include("result" => "no_game")
  end
end
