require "rails_helper"

# 「今の範囲」と現在日（cmd_1784 段2b。Operator 決定 2026-11-01）
# 範囲 = 最後に結果が入った日の翌日 〜 次の試合日。現在日 = 範囲の最後の日。
# Test Basis: context/thbig-dugout-season-record-restructure-design.md 2026-11-01 の追記 2 本、
#             context/thbig-dugout-game-day-flow-design.md §5.1 の追記（結果の定義は gameDayStatus.ts と同じ）
RSpec.describe SeasonCurrentRange do
  let(:season) { create(:season, current_date: Date.new(2026, 1, 1)) }

  def d(day) = Date.new(2026, 5, day)

  def schedule(day, type = "game_day", **attrs)
    create(:season_schedule, season: season, date: d(day), date_type: type, **attrs)
  end

  # 5/1 試合 5/2 試合 5/3 移動 5/4 試合 5/5 延期 5/6 予備 5/7 試合 5/8 試合
  def build_calendar
    schedule(1); schedule(2); schedule(3, "travel_day"); schedule(4); schedule(5, "postponed")
    schedule(6, "reserve_day"); schedule(7); schedule(8)
  end

  def range = described_class.for_season(season)

  def result(day, score: 3, opponent_score: 1, **attrs)
    SeasonSchedule.find_by!(season: season, date: d(day)).update!(score: score, opponent_score: opponent_score, **attrs)
  end

  it "日程が無いシーズンは導けない（nil）。Season#current_date は列の値に倒れる" do
    expect(range).to be_nil
    expect(season.current_date).to eq(Date.new(2026, 1, 1))
  end

  describe "結果がひとつも無い（初日〜最初の試合日）" do
    it "最初の試合日が初日なら、範囲はその 1 日だけ" do
      build_calendar
      expect(range.to_h).to eq(start_date: d(1), end_date: d(1))
      expect(range.current_date).to eq(d(1))
    end

    it "初日が移動日なら、初日から最初の試合日までが範囲" do
      schedule(1, "travel_day"); schedule(2, "off_day"); schedule(3)
      expect(range.to_h).to eq(start_date: d(1), end_date: d(3))
      expect(range.current_date).to eq(d(3))
    end
  end

  describe "結果が入った後" do
    before { build_calendar }

    it "結果の翌日から次の試合日まで（移動日を挟む）。現在日は次の試合日" do
      result(2)
      expect(range.to_h).to eq(start_date: d(3), end_date: d(4))
      expect(range.current_date).to eq(d(4))
      expect(range.last_result_date).to eq(d(2))
    end

    it "雨天中止・延期・予備日は試合日ではないので、範囲の中に入る" do
      result(4)
      expect(range.to_h).to eq(start_date: d(5), end_date: d(7))
      expect(range.covers?(d(5))).to be true
      expect(range.covers?(d(6))).to be true
      expect(range.covers?(d(7))).to be true
    end

    it "範囲の外（結果の日・次の試合日の後）は covers? が false" do
      result(4)
      expect(range.covers?(d(4))).to be false
      expect(range.covers?(d(8))).to be false
      expect(range.covers?(nil)).to be false
    end

    it "次の試合日の結果が入ると、次の範囲へ進む" do
      result(2)
      expect(range.current_date).to eq(d(4))
      result(4)
      expect(range.to_h).to eq(start_date: d(5), end_date: d(7))
      expect(range.current_date).to eq(d(7))
    end

    it "ノーゲーム（真偽値 no_game）は結果が入った扱い。得点が無くても進む" do
      SeasonSchedule.find_by!(season: season, date: d(1)).update!(no_game: true)
      expect(range.last_result_date).to eq(d(1))
      expect(range.current_date).to eq(d(2))
    end

    it "得点が片側だけの日は結果とみなさない（試合結果の段と同じ定義）" do
      SeasonSchedule.find_by!(season: season, date: d(1)).update!(score: 3)
      expect(range.last_result_date).to be_nil
      expect(range.current_date).to eq(d(1))
    end

    it "0 点は正当な得点（0 - 0 でも結果が入った扱い）" do
      result(1, score: 0, opponent_score: 0)
      expect(range.last_result_date).to eq(d(1))
    end

    it "予備日に試合が入って結果がある日は、種別を問わず結果の日。その翌日から次の範囲" do
      result(6)
      expect(range.to_h).to eq(start_date: d(7), end_date: d(7))
    end

    it "結果が前後して入っている時は、一番後ろの結果の日が基準（手前の入力漏れは範囲に入らない）" do
      result(7)
      expect(range.last_result_date).to eq(d(7))
      expect(range.to_h).to eq(start_date: d(8), end_date: d(8))
    end

    it "最終試合日に結果が入った後は範囲なし。現在日は最後に結果が入った日" do
      result(8)
      expect(range.to_h).to eq(start_date: nil, end_date: nil)
      expect(range.current_date).to eq(d(8))
      expect(range.covers?(d(8))).to be false
    end

    it "最終試合日の後ろに試合の無い日が続いていても範囲なし" do
      schedule(9, "travel_day")
      result(8)
      expect(range.start_date).to be_nil
      expect(range.current_date).to eq(d(8))
    end
  end

  it "種別 no_game（雨天ノーゲームの旧表現）は試合日として数えるが、真偽値が立つまでは結果ではない" do
    schedule(1); schedule(2, "no_game"); schedule(3)
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
    SeasonSchedule.find_by!(season: season, date: d(2)).update!(no_game: true)
    expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
  end

  it "プレーオフ日（playoff_day）も試合日として数える（範囲はプレーオフ日で終わる）" do
    schedule(1); schedule(2, "travel_day"); schedule(3, "playoff_day"); schedule(4)
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(3))
    expect(range.current_date).to eq(d(3))
  end

  it "予備日（reserve_day）・交流戦予備日・休日・延期は試合日ではない（範囲の終わりにならない）" do
    schedule(1); schedule(2, "reserve_day"); schedule(3, "interleague_reserve_day"); schedule(4, "no_game_day")
    schedule(5, "postponed"); schedule(6, "interleague_game_day")
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(6))
  end

  it "試合日がひとつも無く結果も無い日程は、範囲なし。現在日は日程の最初の日" do
    schedule(1, "travel_day"); schedule(2, "off_day")
    expect(range.start_date).to be_nil
    expect(range.current_date).to eq(d(1))
  end

  describe "Season#current_date / current_range" do
    it "呼ぶたびに日程から導く（結果の保存に追従し、列の値は使わない）" do
      build_calendar
      expect(season.current_date).to eq(d(1))
      result(1)
      expect(season.current_date).to eq(d(2))
      expect(season.current_range.to_h).to eq(start_date: d(2), end_date: d(2))
      expect(season[:current_date]).to eq(Date.new(2026, 1, 1))
    end
  end

  describe ".for_seasons" do
    it "複数シーズンを 1 回の問い合わせでまとめて導く。日程の無いシーズンは含めない" do
      build_calendar
      result(1)
      other = create(:season)
      create(:season_schedule, season: other, date: Date.new(2026, 6, 1), date_type: "game_day")
      empty = create(:season)

      ranges = nil
      queries = count_queries { ranges = described_class.for_seasons([ season.id, other.id, empty.id ]) }

      expect(queries).to eq(1)
      expect(ranges[season.id].current_date).to eq(d(2))
      expect(ranges[other.id].current_date).to eq(Date.new(2026, 6, 1))
      expect(ranges).not_to have_key(empty.id)
    end

    def count_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
  end
end
