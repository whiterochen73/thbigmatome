class SeasonScheduleSerializer < ActiveModel::Serializer
  attributes :id, :date, :date_type, :announced_starter, :game_result

  def announced_starter
    return nil unless object.announced_starter_id
    player = object.announced_starter&.player
    return nil unless player
    {
      id: player.id,
      name: player.name
    }
  end

  def game_result
    object.game_result_hash
  end
end
