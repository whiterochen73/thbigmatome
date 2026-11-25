# 「今の範囲」と現在日を、日程の結果から導く（cmd_1784 段2b。Operator 決定 2026-11-01）。
#
# - 今の範囲 = 最後に試合結果が入った日の翌日から、次の試合日までの全日（移動日・予備日・休日・雨天中止を含む）。
#   この範囲の日は、試合日ページで登録・離脱を操作でき、操作はその日の日付で記録される。
# - 現在日 = 範囲の最後の日（= 次の試合日）。次の試合日の結果が入ると、次の範囲へ進む。
#
# 「結果が入った」は試合日ページの結果の段（gameDayStatus.ts の resultStageState）と同じ定義:
#   得点（自軍・相手とも）が保存済み、またはノーゲーム（真偽値 no_game）。日程の種別は問わない
#   （予備日に試合が入った日も結果の日として数える）。
# 「試合日」は SeasonSchedule::GAME_DATE_TYPES（game_day / interleague_game_day / playoff_day。画面の isGameType はこれをサーバから受け取る）。
# ノーゲームの日（真偽値 no_game）も種別が試合日なら試合日として範囲の終わりになる（試合数には数えない。SeasonSchedule.counted_games）。
#
# 毎回、日程から導く（現在日カーソルの列 seasons.current_date は写しにしない）。理由: 日程の編集・結果の保存・取り込みなど
# 結果を変える経路が複数あり、写しを更新する処理を全部に付けると 1 か所の漏れで古い値が残る。1 シーズンの日程は
# 200 行前後なので、導くコストは小さい。
#
# 境界の決め方:
# - 結果が 1 件も無い（初日〜最初の試合日）: 範囲 = 日程の最初の日 〜 最初の試合日。現在日 = 最初の試合日
# - 結果の後に試合日が無い（最終試合日に結果が入った後）: 範囲 = 最後に結果が入った日の 1 日だけ（start_date = end_date = 現在日）。
#   最終試合の結果を保存した後も、その日付で登録・昇降格・離脱を記録できるようにするため（cmd_1836。Operator 決定 2026-11-05）。
#   最終試合日より後の日は操作できない
# - 結果が前後して入っている（後の試合日の結果だけ先に入った等）: 一番後ろの結果の日を基準にする
# - 雨天中止・延期の日（postponed / no_game_day）は試合日ではないので範囲の中に入る。結果が入らない
# - 日程が 1 行も無い: 導けない（nil）。呼び出し側が seasons.current_date の列へ倒す
# - プレーオフの日（playoff_day）は、そのシーズンのプレーオフの日のどれかに始まった印（STARTED_MARK_SQL の項目、または登板記録）が
#   入るまで試合日に数えない（cmd_1975。Operator 決定 2026-11-25）。印が無い間、レギュラー最終戦の結果の後は上の「最終試合日の後」と同じ。
#   プレーオフは通常使わず、全シーズンで空のまま並ぶため。印が 1 つでも入れば、今までどおり試合日に数える
# - 試合日がひとつも無く結果も無い: 範囲 = なし、現在日 = 日程の最初の日
class SeasonCurrentRange
  Window = Struct.new(:current_date, :start_date, :end_date, :last_result_date, keyword_init: true) do
    # 範囲の中の日か（範囲が無い時は常に false）
    def covers?(date)
      return false if start_date.nil? || end_date.nil? || date.nil?

      date.to_date.between?(start_date, end_date)
    end

    def to_h
      { start_date: start_date, end_date: end_date }
    end
  end

  COLUMNS = %i[date date_type score opponent_score no_game].freeze

  # 「プレーオフの日が始まった」印（行に入っている項目）。SQL で 1 つの真偽値にして引く（オーダー等の jsonb を読み込まない）。
  # 相手・予告先発・自軍と相手のオーダー（player_id が入った行が 1 つ以上）・得点（どちらか）・ノーゲーム・スコアボード（home / away に値が 1 つ以上）・試合ログ（空文字は印にしない）・勝敗投手。
  # jsonb は構造で空を判定する（jsonpath の lax モードは想定外の形でも例外にならず、一致しないだけ）。
  # ホーム／ビジター・DH・球場・実日時・試合番号は日程の一括編集で入りうるので印にしない。登板記録（PitcherGameState）は別に引く
  STARTED_MARK_SQL = Arel.sql(<<~SQL.squish).freeze
    (season_schedules.opponent_team_id IS NOT NULL
     OR season_schedules.announced_starter_id IS NOT NULL
     OR jsonb_path_exists(season_schedules.starting_lineup, '$[*] ? (@.player_id != null)')
     OR jsonb_path_exists(season_schedules.opponent_starting_lineup, '$[*] ? (@.player_id != null)')
     OR season_schedules.score IS NOT NULL
     OR season_schedules.opponent_score IS NOT NULL
     OR season_schedules.no_game = TRUE
     OR jsonb_path_exists(season_schedules.scoreboard, '$.home[*] ? (@ != null)') OR jsonb_path_exists(season_schedules.scoreboard, '$.away[*] ? (@ != null)')
     OR (season_schedules.game_log IS NOT NULL AND season_schedules.game_log <> '')
     OR season_schedules.winning_pitcher_id IS NOT NULL
     OR season_schedules.losing_pitcher_id IS NOT NULL)
  SQL

  # 1 シーズン分。日程が無ければ nil
  def self.for_season(season)
    for_seasons([ season.id ])[season.id]
  end

  # 複数シーズンをまとめて（一覧用）。{ season_id => Window }。日程の無いシーズンは含まない。
  # 問い合わせは日程 1 回。空のプレーオフの日を持つシーズンがある時だけ、登板記録を 1 回足す
  def self.for_seasons(season_ids)
    grouped = SeasonSchedule.where(season_id: season_ids).joins(:season)
                            .pluck(:id, :season_id, "seasons.team_id", *COLUMNS, STARTED_MARK_SQL)
                            .group_by { |row| row[1] }
    pitched = pitched_playoff_season_ids(grouped)
    grouped.to_h do |season_id, rows|
      playoff_started = rows.any? { |row| row[4] == SeasonSchedule::PLAYOFF_DATE_TYPE && row.last } || pitched.include?(season_id)
      [ season_id, compute(rows.map { |row| row[3, COLUMNS.size] }, playoff_started: playoff_started) ]
    end
  end

  # 印の無いプレーオフの日を持つシーズンのうち、その日に登板記録があるシーズンの id。
  # 日程の行に紐づく登板（season_schedule_id）か、紐づけ前の登板（season_schedule_id が nil で schedule_date が同じ日付）で拾う
  def self.pitched_playoff_season_ids(grouped)
    candidates = grouped.filter_map do |season_id, rows|
      empty = rows.select { |row| row[4] == SeasonSchedule::PLAYOFF_DATE_TYPE }
      next if empty.empty? || empty.any?(&:last)

      [ season_id, rows.first[2], empty.map(&:first), empty.map { |row| row[3].to_s } ]
    end
    return Set.new if candidates.empty?

    team_ids = candidates.map { |_, team_id, _, _| team_id }
    schedule_ids = candidates.flat_map { |_, _, ids, _| ids }
    dates = candidates.flat_map { |_, _, _, ds| ds }
    found = PitcherGameState.where(team_id: team_ids)
                            .where(season_schedule_id: schedule_ids)
                            .or(PitcherGameState.where(team_id: team_ids, season_schedule_id: nil, schedule_date: dates))
                            .pluck(:team_id, :season_schedule_id, :schedule_date)
    candidates.each_with_object(Set.new) do |(season_id, team_id, ids, ds), set|
      set << season_id if found.any? { |t, sid, date| sid ? ids.include?(sid) : (t == team_id && ds.include?(date)) }
    end
  end

  # rows: [[date, date_type, score, opponent_score, no_game], ...]
  # playoff_started: そのシーズンのプレーオフの日のどれかに始まった印があるか。false の間は playoff_day を試合日に数えない
  def self.compute(rows, playoff_started: true)
    return nil if rows.empty?

    first_date = rows.map(&:first).min
    last_result = rows.select { |_, _, score, opponent_score, no_game| result?(score, opponent_score, no_game) }.map(&:first).max
    game_dates = rows.select { |_, type, *| game_date_type?(type, playoff_started) }.map(&:first).sort

    if last_result
      next_game = game_dates.find { |date| date > last_result }
      if next_game.nil?
        return Window.new(current_date: last_result, start_date: last_result, end_date: last_result, last_result_date: last_result)
      end

      Window.new(current_date: next_game, start_date: last_result + 1, end_date: next_game, last_result_date: last_result)
    else
      first_game = game_dates.first
      return Window.new(current_date: first_date) if first_game.nil?

      Window.new(current_date: first_game, start_date: first_date, end_date: first_game)
    end
  end

  def self.game_date_type?(type, playoff_started)
    return false if type == SeasonSchedule::PLAYOFF_DATE_TYPE && !playoff_started

    SeasonSchedule::GAME_DATE_TYPES.include?(type)
  end

  def self.result?(score, opponent_score, no_game)
    (!score.nil? && !opponent_score.nil?) || no_game == true
  end
end
