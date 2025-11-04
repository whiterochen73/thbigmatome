class PlayerAbsence < ApplicationRecord
  belongs_to :team_membership
  belongs_to :season

  enum :absence_type, { injury: 0, suspension: 1, reconditioning: 2 }

  validates :absence_type, presence: true
  validates :start_date, presence: true
  validates :duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :duration_unit, presence: true, inclusion: { in: %w(days games) }
end
