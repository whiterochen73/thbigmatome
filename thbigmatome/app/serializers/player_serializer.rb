class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :handedness, :position

  has_many :cost_players, serializer: CostPlayerSerializer

  def handedness
    object.player_cards.first&.handedness
  end

  def position
    if object.player_cards.any?(&:is_pitcher)
      "pitcher"
    else
      pc = object.player_cards.first
      pc&.player_card_defenses&.first&.position&.downcase
    end
  end
end
