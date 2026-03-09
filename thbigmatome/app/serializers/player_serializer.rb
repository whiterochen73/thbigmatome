class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :handedness

  has_many :cost_players, serializer: CostPlayerSerializer

  def handedness
    object.player_cards.first&.handedness
  end
end
