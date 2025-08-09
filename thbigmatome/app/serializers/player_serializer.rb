class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :position, :player_type_ids
  has_many :cost_players, serializer: CostPlayerSerializer

  def player_type_ids
    object.player_player_types.pluck(:player_type_id)
  end
end