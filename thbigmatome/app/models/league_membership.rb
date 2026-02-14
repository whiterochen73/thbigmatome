class LeagueMembership < ApplicationRecord
  belongs_to :league
  belongs_to :team

  validates :league_id, uniqueness: { scope: :team_id }
end
