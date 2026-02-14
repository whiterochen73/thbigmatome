class LeaguePoolPlayerSerializer < ActiveModel::Serializer
  attributes :id, :league_season_id, :player_id

  belongs_to :player
end
