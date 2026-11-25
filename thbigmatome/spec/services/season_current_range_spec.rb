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

    # Test Basis: cmd_1836（Operator 2026-11-05「最終試合日にも選手登録、昇降格、離脱の登録ができるように」）
    it "最終試合日に結果が入った後は、範囲が最終試合日の 1 日になる。現在日も最終試合日" do
      result(8)
      expect(range.to_h).to eq(start_date: d(8), end_date: d(8))
      expect(range.current_date).to eq(d(8))
      expect(range.last_result_date).to eq(d(8))
      expect(range.covers?(d(8))).to be true
    end

    it "最終試合日の翌日と、最終試合日の前の日は範囲の外" do
      schedule(9, "travel_day")
      result(8)
      expect(range.covers?(d(9))).to be false
      expect(range.covers?(d(7))).to be false
    end

    it "最終試合日の後ろに試合の無い日が続いていても、範囲は最終試合日の 1 日だけ" do
      schedule(9, "travel_day")
      result(8)
      expect(range.to_h).to eq(start_date: d(8), end_date: d(8))
      expect(range.current_date).to eq(d(8))
    end

    it "最終試合がノーゲームでも、範囲は最終試合日の 1 日" do
      SeasonSchedule.find_by!(season: season, date: d(8)).update!(no_game: true)
      result(7)
      expect(range.to_h).to eq(start_date: d(8), end_date: d(8))
      expect(range.current_date).to eq(d(8))
    end

    it "最終試合日の結果が入っていなければ、範囲は結果の翌日から最終試合日（従来どおり）" do
      result(7)
      expect(range.to_h).to eq(start_date: d(8), end_date: d(8))
      expect(range.covers?(d(7))).to be false
    end
  end

  it "ノーゲームの日（種別は試合日のまま真偽値 no_game）は試合日として範囲の終わりになり、真偽値が立つと結果になる" do
    schedule(1); schedule(2); schedule(3)
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
    SeasonSchedule.find_by!(season: season, date: d(2)).update!(no_game: true)
    expect(range.last_result_date).to eq(d(2))
    expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
  end

  it "ノーゲームの日の後に振り替えた試合（予備日を試合日にして入力した日）が次の範囲の終わりになる" do
    schedule(1); schedule(2); schedule(3, "reserve_day"); schedule(4)
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
    SeasonSchedule.find_by!(season: season, date: d(2)).update!(no_game: true)
    expect(range.to_h).to eq(start_date: d(3), end_date: d(4)) # 予備日のままなら次の試合日(5/4)まで
    SeasonSchedule.find_by!(season: season, date: d(3)).update!(date_type: "game_day") # 振替
    expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
    result(3)
    expect(range.to_h).to eq(start_date: d(4), end_date: d(4))
  end

  it "移行前に種別 no_game のまま残っている日は試合日の種別ではない（rake season_records:normalize_no_game_dates で戻す）" do
    schedule(1); legacy = create(:season_schedule, season: season, date: d(2), date_type: "game_day"); schedule(3)
    legacy.update_columns(date_type: "no_game")
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(3))
  end

  it "プレーオフ日（playoff_day）は、始まった印が入っていれば試合日として数える（範囲はプレーオフ日で終わる）" do
    # Test Basis: cmd_1975 仕様 3 / 設計書 §5.3 の 2026-11-25 追記
    schedule(1); schedule(2, "travel_day"); schedule(3, "playoff_day", opponent_team: create(:team)); schedule(4)
    result(1)
    expect(range.to_h).to eq(start_date: d(2), end_date: d(3))
    expect(range.current_date).to eq(d(3))
  end

  # cmd_1975（Operator 決定 2026-11-25）: プレーオフの日のどれかに何か入るまで、プレーオフの日は試合日に数えない
  # Test Basis: cmd_1975 仕様 1・2・3・4 / 設計書 §5.3 の 2026-11-25 追記
  describe "プレーオフの日が空の間" do
    # 5/1 5/2 試合 → 5/3 移動 → 5/4 5/5 プレーオフ（空）
    def regular_then_playoff
      schedule(1); schedule(2); schedule(3, "travel_day"); schedule(4, "playoff_day"); schedule(5, "playoff_day")
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "レギュラー最終戦の結果の後は範囲なし（最終試合日の後と同じ）。現在日は最後に結果が入った日" do
      regular_then_playoff
      result(1); result(2)
      expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
      expect(range.current_date).to eq(d(2))
      expect(range.last_result_date).to eq(d(2))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "レギュラー途中は従来どおり（次のレギュラー試合日まで）" do
      regular_then_playoff
      result(1)
      expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
      expect(range.current_date).to eq(d(2))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "結果がひとつも無く、試合日がプレーオフの日だけなら、範囲なし・現在日は日程の最初の日" do
      schedule(1, "travel_day"); schedule(2, "playoff_day")
      expect(range.start_date).to be_nil
      expect(range.current_date).to eq(d(1))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "結果ゼロで通常の試合日があれば従来どおり最初の試合日まで" do
      regular_then_playoff
      expect(range.to_h).to eq(start_date: d(1), end_date: d(1))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "home_away・DH・球場・実日時・試合番号は印にしない" do
      schedule(1)
      schedule(2, "playoff_day", home_away: "home", designated_hitter_enabled: true, stadium: "x", venue: "ch1",
                                 real_start_time: "20:00", real_date: d(2), game_number: 1)
      result(1)
      expect(range.to_h).to eq(start_date: d(1), end_date: d(1))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "空のオーダー・空のスコアボード・空文字の試合ログも印にしない" do
      schedule(1)
      schedule(2, "playoff_day", starting_lineup: [], opponent_starting_lineup: {}, scoreboard: {}, game_log: "")
      result(1)
      expect(range.to_h).to eq(start_date: d(1), end_date: d(1))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "画面や API が作りうる空の形（player_id が null の行・home / away が空のスコアボード・想定外の形）も印にしない" do
      schedule(1)
      schedule(2, "playoff_day", starting_lineup: [ { "player_id" => nil, "position" => "CF", "order" => 1 } ],
                                 opponent_starting_lineup: "x", scoreboard: { "home" => [], "away" => [ nil ] })
      schedule(3, "playoff_day", starting_lineup: { "a" => 1 }, opponent_starting_lineup: 5, scoreboard: [ 1 ])
      result(1)
      expect(range.to_h).to eq(start_date: d(1), end_date: d(1))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "スコアボードの home / away に値があれば印" do
      schedule(1); schedule(2, "playoff_day", scoreboard: { "home" => [ 0 ], "away" => [] })
      result(1)
      expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
    end

    {
      "相手" => -> { { opponent_team: create(:team) } },
      "自軍オーダー" => -> { { starting_lineup: [ { "player_id" => 1 } ] } },
      "相手オーダー" => -> { { opponent_starting_lineup: [ { "player_id" => 1 } ] } },
      "得点（自軍だけ）" => -> { { score: 2 } },
      "得点（相手だけ）" => -> { { opponent_score: 2 } },
      "ノーゲーム" => -> { { no_game: true } },
      "スコアボード" => -> { { scoreboard: { "home" => [ 1 ], "away" => [] } } },
      "試合ログ" => -> { { game_log: "log" } }
    }.each do |label, attrs|
      # Test Basis: cmd_1975 仕様 2（印の線引き）
      it "印: #{label} が入ると、プレーオフの日を試合日に数える" do
        schedule(1); schedule(2); schedule(3, "playoff_day", **instance_exec(&attrs)); schedule(4, "playoff_day")
        result(1); result(2)
        expect(range.current_date).to be >= d(3)
        expect(range.end_date).to be >= d(3)
      end
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "印: 予告先発 / 勝敗投手が入ると数える" do
      schedule(1); schedule(2)
      playoff = schedule(3, "playoff_day")
      result(1); result(2)
      expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
      membership = create(:team_membership, team: season.team)
      playoff.update!(announced_starter: membership)
      expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
      playoff.update!(announced_starter: nil)
      player = create(:player)
      playoff.update!(winning_pitcher: player)
      expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "印: その日の登板記録（PitcherGameState）があれば数える" do
      schedule(1); schedule(2)
      playoff = schedule(3, "playoff_day"); schedule(4, "playoff_day")
      result(1); result(2)
      expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
      create(:pitcher_game_state, team: season.team, season_schedule: playoff, schedule_date: d(3).to_s)
      expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "印: 日程に紐づいていない登板記録も schedule_date で拾う" do
      schedule(1); schedule(2); schedule(3, "playoff_day")
      result(1); result(2)
      create(:pitcher_game_state, team: season.team, season_schedule: nil, schedule_date: d(3).to_s)
      expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "印がプレーオフの 2 日目だけにあっても、シーズン内のどれかに入っていれば数える（初日が次の試合日）" do
      schedule(1); schedule(2); schedule(3, "playoff_day"); schedule(4, "playoff_day", opponent_team: create(:team))
      result(1); result(2)
      expect(range.to_h).to eq(start_date: d(3), end_date: d(3))
      expect(range.current_date).to eq(d(3))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "他チームの登板記録は印にしない" do
      schedule(1); schedule(2); schedule(3, "playoff_day")
      result(1); result(2)
      create(:pitcher_game_state, team: create(:team), season_schedule: nil, schedule_date: d(3).to_s)
      expect(range.to_h).to eq(start_date: d(2), end_date: d(2))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "for_seasons も for_season と同じ結果（印なし・印あり・プレーオフなしのシーズンが混在）" do
      regular_then_playoff
      result(1); result(2)
      marked = create(:season)
      [ [ 1, "game_day" ], [ 2, "playoff_day" ], [ 3, "playoff_day" ] ].each do |day, type|
        create(:season_schedule, season: marked, date: d(day), date_type: type, **(day == 3 ? { opponent_team: create(:team) } : {}))
      end
      marked.season_schedules.find_by!(date: d(1)).update!(score: 1, opponent_score: 0)
      piped = create(:season)
      pitched = create(:pitcher_game_state, team: piped.team, season_schedule: nil, schedule_date: d(2).to_s)
      create(:season_schedule, season: piped, date: d(1), date_type: "game_day", score: 1, opponent_score: 0)
      create(:season_schedule, season: piped, date: d(2), date_type: "playoff_day")
      expect(pitched).to be_persisted

      ids = [ season.id, marked.id, piped.id ]
      ranges = described_class.for_seasons(ids)
      ids.zip([ season, marked, Season.find(piped.id) ]).each do |id, s|
        expect(ranges[id].to_h).to eq(described_class.for_season(s).to_h)
        expect(ranges[id].current_date).to eq(described_class.for_season(s).current_date)
      end
      expect(ranges[season.id].to_h).to eq(start_date: d(2), end_date: d(2))
      expect(ranges[marked.id].to_h).to eq(start_date: d(2), end_date: d(2))
      expect(ranges[piped.id].to_h).to eq(start_date: d(2), end_date: d(2))
    end

    # Test Basis: cmd_1975 仕様 1〜4 / 設計書 §5.3 の 2026-11-25 追記
    it "for_seasons の問い合わせは、空のプレーオフの日があっても 2 回以内" do
      regular_then_playoff
      result(1); result(2)
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.for_seasons([ season.id ]) }
      expect(queries).to be <= 2
    end
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
