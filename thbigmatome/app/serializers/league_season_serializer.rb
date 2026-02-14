class LeagueSeasonSerializer < ActiveModel::Serializer
  attributes :id, :league_id, :name, :start_date, :end_date, :status
end
