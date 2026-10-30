class SeasonDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :current_date, :start_date, :end_date, :key_player_id, :key_player_name
  has_many :season_schedules, serializer: SeasonScheduleSerializer

  # 各試合日の登板記録の件数を 1 回の問い合わせでまとめて入れる（SeasonSchedule#pitcher_appearance_count）。
  # schedule_date は文字列の列なので、キーは "YYYY-MM-DD"。
  # カレンダーが「得点だけ保存済みで登板記録が無い」などの入力漏れの印を出すために使う。
  def season_schedules
    counts = PitcherGameState.where(team_id: object.team_id).group(:schedule_date).count
    schedules = object.season_schedules.to_a
    schedules.each { |schedule| schedule.pitcher_appearance_count = counts[schedule.date.to_s] || 0 }
    schedules
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
end
