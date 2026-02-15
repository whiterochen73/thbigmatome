class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :player
  has_many :season_rosters
  has_many :player_absences, dependent: :restrict_with_error

  validates :squad, inclusion: { in: %w[first second] }
  validates :selected_cost_type, presence: true, inclusion: { in: %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost] }
end
