class ScheduleDetail < ApplicationRecord
  belongs_to :schedule

  validates :date, presence: true
  validates :date_type, presence: true
  validates :date_type, exclusion: { in: [ SeasonSchedule::NO_GAME_DATE_TYPE ], message: "に no_game は指定できません" }, if: :will_save_change_to_date_type?
end
