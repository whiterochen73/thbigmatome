class CompetitionEntry < ApplicationRecord
  belongs_to :competition
  belongs_to :team
  belongs_to :base_team, class_name: "Team", optional: true

  has_many :competition_rosters, dependent: :destroy
  has_many :player_cards, through: :competition_rosters

  validates :competition_id, uniqueness: { scope: :team_id }
end
