class PlayerCardSerializer < ActiveModel::Serializer
  attributes :id, :card_set_id, :player_id, :card_type,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :is_pitcher, :is_relief_only,
             :starter_stamina, :relief_stamina,
             :batting_style_id, :batting_style_description,
             :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id, :pitching_style_description,
             :special_defense_c, :special_throwing_c,
             :batting_table, :pitching_table, :abilities,
             :card_image_path

  attribute :player_name do
    object.player.name
  end

  attribute :player_number do
    object.player.number
  end

  attribute :card_set_name do
    object.card_set.name
  end
end
