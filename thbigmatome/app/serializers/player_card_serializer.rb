class PlayerCardSerializer < ActiveModel::Serializer
  attributes :id, :card_set_id, :player_id,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :is_pitcher, :is_relief_only,
             :starter_stamina, :relief_stamina,
             :batting_style_id, :batting_style_description,
             :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id, :pitching_style_description,
             :defense_p, :defense_c, :special_defense_c,
             :throwing_c, :special_throwing_c,
             :defense_1b, :defense_2b, :defense_3b, :defense_ss,
             :defense_of, :throwing_of,
             :defense_lf, :throwing_lf,
             :defense_cf, :throwing_cf,
             :defense_rf, :throwing_rf,
             :batting_table, :pitching_table, :abilities,
             :card_image_path
end
