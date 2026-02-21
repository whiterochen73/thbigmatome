class CompetitionEntry < ApplicationRecord
  belongs_to :competition
  belongs_to :team
  belongs_to :base_team, class_name: "Team", optional: true

  validates :competition_id, uniqueness: { scope: :team_id }
end
