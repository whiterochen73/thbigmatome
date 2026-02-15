class LeaguePoolPlayer < ApplicationRecord
  belongs_to :league_season
  belongs_to :player

  validates :league_season_id, uniqueness: { scope: :player_id, message: :already_registered_in_pool }
end
