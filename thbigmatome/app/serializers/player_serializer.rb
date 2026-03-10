class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :handedness, :position

  has_many :cost_players, serializer: CostPlayerSerializer

  def handedness
    object.player_cards.first&.handedness
  end

  def position
    pc = object.player_cards.first
    if pc&.card_type == "pitcher"
      "pitcher"
    else
      pc&.player_card_defenses&.first&.position&.downcase
    end
  end
end
