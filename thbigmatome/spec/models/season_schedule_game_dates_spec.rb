require "rails_helper"

# Test Basis: cmd_1784 段4。設計書 §4.6（試合日とみなす種別を 1 つに・ノーゲームは真偽値に一本化）、台帳 D-11（ノーゲームは疲労・負傷の計算は行い、
# 勝敗・成績は算入しない）、Operator 2026-11-01「ノーゲームになった試合は振り替える（試合数がその分増える）。ノーゲームになった試合は試合数にカウントしない」。
RSpec.describe SeasonSchedule do
  let(:season) { create(:season) }

  def d(day) = Date.new(2026, 5, day)

  def schedule(day, type = "game_day", **attrs)
    create(:season_schedule, season: season, date: d(day), date_type: type, **attrs)
  end

  describe "GAME_DATE_TYPES（試合日とみなす種別の唯一の定義）" do
    it "通常・交流戦・プレーオフの 3 種で、ノーゲームは種別に含めない" do
      expect(described_class::GAME_DATE_TYPES).to eq(%w[game_day interleague_game_day playoff_day])
      expect(described_class::GAME_DATE_TYPES).not_to include("no_game")
    end

    it "game_days は種別が試合日の行だけ（予備日・移動日・雨天中止・休日は含めない）" do
      ids = %w[game_day interleague_game_day playoff_day reserve_day interleague_reserve_day travel_day postponed no_game_day].each_with_index.map { |t, i| schedule(i + 1, t).id }
      expect(season.season_schedules.game_days.pluck(:id)).to match_array(ids.first(3))
    end
  end

  describe "種別 no_game は新たに作れない" do
    it "作成・種別の変更を検証で断る" do
      expect(build(:season_schedule, season: season, date: d(1), date_type: "no_game")).not_to be_valid
      s = schedule(2)
      expect(s.update(date_type: "no_game")).to be false
      expect(s.errors[:date_type].join).to include("no_game")
      expect(s.reload.date_type).to eq("game_day")
    end

    it "移行前に種別 no_game のまま残っている行は、種別以外の列の保存を止めない（種別を変える時は no_game 以外を選ぶ）" do
      legacy = legacy_no_game_schedule(season: season, date: d(3))
      expect(legacy.update(score: 1, opponent_score: 0)).to be true
      expect(legacy.reload.date_type).to eq("no_game")
      expect(legacy.update(date_type: "game_day")).to be true
    end

    it "ノーゲームは真偽値で表す: 種別は試合日のまま no_game を立てられる" do
      s = schedule(4)
      expect(s.update(no_game: true)).to be true
      expect(s.reload).to have_attributes(date_type: "game_day", no_game: true)
    end
  end

  describe "counted_games（試合数に数える日）" do
    it "試合日のうち、ノーゲームでない日だけ。ノーゲームの日は試合日だが数えない" do
      a = schedule(1)
      schedule(2, no_game: true)
      b = schedule(3, "interleague_game_day")
      c = schedule(4, "playoff_day")
      schedule(5, "reserve_day")
      schedule(6, "reserve_day", no_game: true) # 予備日のままノーゲーム（試合日の種別ではない）
      expect(season.season_schedules.counted_games.pluck(:id)).to match_array([ a.id, b.id, c.id ])
      expect(season.season_schedules.game_days.count).to eq(4)
    end
  end

  describe "#calculated_game_number" do
    it "ノーゲームの日は数えず、後ろの試合番号は繰り上がらない（ノーゲームの日の次の試合は同じ番号）" do
      g1 = schedule(1)
      ng = schedule(2, no_game: true)
      g3 = schedule(3)
      expect([ g1, ng, g3 ].map(&:calculated_game_number)).to eq([ 1, 2, 2 ])
    end

    it "振り替えた試合（予備日を試合日にして入力した日）が 1 試合として数えられ、ノーゲームの日と二重にならない" do
      g1 = schedule(1)
      ng = schedule(2, no_game: true)
      rescheduled = schedule(3, "reserve_day")
      g4 = schedule(4)
      expect(g4.calculated_game_number).to eq(2) # 予備日のままなら、ここまで 1 試合
      rescheduled.update!(date_type: "game_day") # 振替: 予備日を試合日にする
      expect([ g1, ng, rescheduled, g4 ].map { |s| s.reload.calculated_game_number }).to eq([ 1, 2, 2, 3 ])
      expect(season.season_schedules.counted_games.count).to eq(3) # 1 日目・振り替えた日・4 日目。ノーゲームの日は数えない
    end

    it "振り替えた試合もノーゲームになれば、さらに後ろへ振り替える（数えない日が増えるだけ）" do
      schedule(1)
      schedule(2, no_game: true)
      schedule(3, no_game: true)
      g4 = schedule(4)
      expect(g4.calculated_game_number).to eq(2)
    end

    it "ノーゲームの日が連続していても、別チームの日程は数えない" do
      other = create(:season)
      create(:season_schedule, season: other, date: d(1), date_type: "game_day")
      schedule(2)
      expect(schedule(3).calculated_game_number).to eq(2)
    end

    it "プレーオフ日も試合数に数える（試合日の定義が 1 つなので通常・交流戦と同じ）" do
      schedule(1); schedule(2, "interleague_game_day")
      expect(schedule(3, "playoff_day").calculated_game_number).to eq(3)
    end

    it "明示した game_number があればそれを使う" do
      schedule(1)
      expect(schedule(2, game_number: 99).calculated_game_number).to eq(99)
    end

    it "移行前に種別 no_game のまま残っている日も数えない（移行の前後で試合番号が変わらない）" do
      schedule(1)
      legacy_no_game_schedule(season: season, date: d(2))
      expect(schedule(3).calculated_game_number).to eq(2)
    end
  end
end
