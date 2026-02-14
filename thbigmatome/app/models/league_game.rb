class LeagueGame < ApplicationRecord
  belongs_to :league_season
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'

  validates :game_date, presence: true
  validates :game_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
