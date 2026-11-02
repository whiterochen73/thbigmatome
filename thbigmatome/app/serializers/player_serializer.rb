class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :handedness, :position, :is_pitcher, :available_cost_types

  has_many :cost_players, serializer: CostPlayerSerializer

  def handedness
    object.player_cards.first&.handedness
  end

  def position
    if object.player_cards.any?(&:can_pitch?)
      "pitcher"
    else
      pc = object.player_cards.first
      pc&.primary_position&.downcase
    end
  end

  def is_pitcher
    object.player_cards.any?(&:can_pitch?)
  end
end
