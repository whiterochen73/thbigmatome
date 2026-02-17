class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :position, :player_type_ids, :throwing_hand, :batting_hand,
             :defense_p, :defense_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss,
             :defense_of, :defense_lf, :defense_cf, :defense_rf,
             :throwing_c, :throwing_of, :throwing_lf, :throwing_cf, :throwing_rf

  has_many :cost_players, serializer: CostPlayerSerializer

  def player_type_ids
    object.player_player_types.pluck(:player_type_id)
  end
end