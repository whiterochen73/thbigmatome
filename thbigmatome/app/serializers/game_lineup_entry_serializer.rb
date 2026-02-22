class GameLineupEntrySerializer < ActiveModel::Serializer
  attributes :id, :player_card_id, :player_name,
             :role, :batting_order, :position,
             :is_dh_pitcher, :is_reliever

  def player_name
    object.player_card.player.name
  end
end
