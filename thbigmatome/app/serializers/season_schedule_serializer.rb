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
    return nil if object.score.blank? || object.opponent_score.blank?

    result = if object.score > object.opponent_score
               "win"
    elsif object.score < object.opponent_score
               "lose"
    else
               "draw"
    end

    {
      opponent_short_name: object.opponent_team&.short_name,
      score: "#{object.score} - #{object.opponent_score}",
      result: result
    }
  end
end
