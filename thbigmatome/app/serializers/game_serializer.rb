class GameSerializer < ActiveModel::Serializer
  attributes :id, :competition_id, :home_team_id, :visitor_team_id, :real_date, :status, :source

  has_many :at_bats, serializer: AtBatSerializer
end
