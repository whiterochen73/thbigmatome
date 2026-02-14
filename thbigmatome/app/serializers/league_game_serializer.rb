class LeagueGameSerializer < ActiveModel::Serializer
  attributes :id, :league_season_id, :home_team_id, :away_team_id, :game_date, :game_number

  belongs_to :home_team
  belongs_to :away_team
end
