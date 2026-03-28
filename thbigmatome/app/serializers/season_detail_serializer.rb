class SeasonDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :current_date, :start_date, :end_date, :key_player_id, :key_player_name
  has_many :season_schedules, serializer: SeasonScheduleSerializer

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
