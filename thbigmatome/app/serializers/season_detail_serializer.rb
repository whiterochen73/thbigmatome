class SeasonDetailSerializer < ActiveModel::Serializer
  attributes :id, :current_date, :current_range, :start_date, :end_date, :key_player_id, :key_player_name, :game_date_types
  has_many :season_schedules, serializer: SeasonScheduleSerializer

  # 各試合日の登板記録の件数を 1 回の問い合わせでまとめて入れる（SeasonSchedule#pitcher_appearance_count）。
  # 日程の行に紐づく登板（season_schedule_id）はその行の件数に、まだ紐づけていない登板は schedule_date（文字列。"YYYY-MM-DD"）の日の件数に数える
  # （PitcherGameState.on_day と同じ読み方）。同じ日に日程の行が複数ある日は決められないので、その日の登板を日付だけで数える。
  # カレンダーが「得点だけ保存済みで登板記録が無い」などの入力漏れの印を出すために使う。
  def season_schedules
    rows = PitcherGameState.where(team_id: object.team_id).group(:season_schedule_id, :schedule_date).count
    linked = Hash.new(0)
    unlinked = Hash.new(0)
    by_date = Hash.new(0)
    rows.each do |(schedule_id, date), n|
      by_date[date] += n
      schedule_id ? linked[schedule_id] += n : unlinked[date] += n
    end
    # game_log（最大 1MB の原文）は一覧に要らないので読まない。試合日ごとに読むと全試合日分の転送になる
    schedules = object.season_schedules.select(SeasonSchedule.column_names - [ "game_log" ]).to_a
    rows_per_date = schedules.group_by(&:date).transform_values(&:size)
    schedules.each do |schedule|
      date = schedule.date.to_s
      schedule.pitcher_appearance_count = rows_per_date[schedule.date] == 1 ? linked[schedule.id] + unlinked[date] : by_date[date]
    end
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

  # 試合日とみなす種別（サーバの定義 SeasonSchedule::GAME_DATE_TYPES をそのまま返す。画面の isGameType が使う）
  def game_date_types
    SeasonSchedule::GAME_DATE_TYPES
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
