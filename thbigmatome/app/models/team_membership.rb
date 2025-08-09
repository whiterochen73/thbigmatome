class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :player

  validates :squad, inclusion: { in: %w(first second) }
  validates :selected_cost_type, presence: true
end
