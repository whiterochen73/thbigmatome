class SeasonDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :current_date, :current_range, :start_date, :end_date, :key_player_id, :key_player_name
  has_many :season_schedules, serializer: SeasonScheduleSerializer

  # 各試合日の登板記録の件数を 1 回の問い合わせでまとめて入れる（SeasonSchedule#pitcher_appearance_count）。
  # schedule_date は文字列の列なので、キーは "YYYY-MM-DD"。
  # カレンダーが「得点だけ保存済みで登板記録が無い」などの入力漏れの印を出すために使う。
  def season_schedules
    counts = PitcherGameState.where(team_id: object.team_id).group(:schedule_date).count
    # game_log（最大 1MB の原文）は一覧に要らないので読まない。試合日ごとに読むと全試合日分の転送になる
    schedules = object.season_schedules.select(SeasonSchedule.column_names - [ "game_log" ]).to_a
    schedules.each { |schedule| schedule.pitcher_appearance_count = counts[schedule.date.to_s] || 0 }
    schedules
  end

  # 現在日 = 今の範囲の最後の日（次の試合日）。日程が無い時は列の値（Season#current_date）
  def current_date
    range&.current_date || object.current_date
  end

  # 今の範囲（最後に結果が入った日の翌日〜次の試合日）。登録・離脱を操作できるのはこの範囲の日だけ。
  # 範囲が無い時（最終試合日の後など）は nil
  def current_range
    range&.start_date && range.to_h
  end

  def start_date
    object.season_schedules.minimum(:date)
  end

  def end_date
    object.season_schedules.maximum(:date)
  end

  def key_player_name
    object.key_player&.player&.name
  end

  private

  def range
    return @range if defined?(@range)

    @range = object.current_range
  end
end
