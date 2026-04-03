class GameSerializer < ActiveModel::Serializer
  attributes :id, :competition_id, :home_team_id, :visitor_team_id, :real_date, :status, :source, :game_record_id

  def game_record_id
    object.game_record&.id
  end

  has_many :at_bats, serializer: AtBatSerializer
end
