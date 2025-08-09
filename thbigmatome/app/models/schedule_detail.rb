class ScheduleDetail < ApplicationRecord
  belongs_to :schedule

  validates :date, presence: true
  validates :date_type, presence: true
end
