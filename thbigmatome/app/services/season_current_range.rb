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

  # 1 シーズン分。日程が無ければ nil
  def self.for_season(season)
    compute(season.season_schedules.pluck(*COLUMNS))
  end

  # 複数シーズンをまとめて（一覧用。問い合わせは 1 回）。{ season_id => Window }。日程の無いシーズンは含まない
  def self.for_seasons(season_ids)
    SeasonSchedule.where(season_id: season_ids)
                  .pluck(:season_id, *COLUMNS)
                  .group_by(&:first)
                  .transform_values { |rows| compute(rows.map { |row| row.drop(1) }) }
  end

  # rows: [[date, date_type, score, opponent_score, no_game], ...]
  def self.compute(rows)
    return nil if rows.empty?

    first_date = rows.map(&:first).min
    last_result = rows.select { |_, _, score, opponent_score, no_game| result?(score, opponent_score, no_game) }.map(&:first).max
    game_dates = rows.select { |_, type, *| SeasonSchedule::GAME_DATE_TYPES.include?(type) }.map(&:first).sort

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

  def self.result?(score, opponent_score, no_game)
    (!score.nil? && !opponent_score.nil?) || no_game == true
  end
end
