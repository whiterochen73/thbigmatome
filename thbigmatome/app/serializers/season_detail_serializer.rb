class SeasonDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :current_date, :start_date, :end_date
  has_many :season_schedules, serializer: SeasonScheduleSerializer

  def start_date
    object.season_schedules.minimum(:date)
  end

  def end_date
    object.season_schedules.maximum(:date)
  end
end
