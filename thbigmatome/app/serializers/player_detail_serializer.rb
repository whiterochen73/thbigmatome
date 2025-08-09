class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number, :position, :throwing_hand, :batting_hand,
              :speed, :bunt, :steal_start, :steal_end, :injury_rate, :defense_p, :defense_c,
              :throwing_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss, :defense_of,
              :throwing_of, :defense_lf, :throwing_lf, :defense_cf, :throwing_cf, :defense_rf,
              :throwing_rf, :is_pitcher, :starter_stamina, :relief_stamina, :is_relief_only,
              :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id, :batting_style_id,
              :pitching_style_description, :batting_style_description,
              :special_defense_c, :special_throwing_c, :biorhythm_ids, :batting_skill_ids,
              :pitching_skill_ids, :player_type_ids, :catcher_ids, :partner_pitcher_ids

  def catcher_ids
    object.catchers_players.pluck(:catcher_id)
  end
  def pitching_skill_ids
    object.player_pitching_skills.pluck(:pitching_skill_id)
  end
  def batting_skill_ids
    object.player_batting_skills.pluck(:batting_skill_id)
  end
  def player_type_ids
    object.player_player_types.pluck(:player_type_id)
  end
  def biorhythm_ids
    object.player_biorhythms.pluck(:biorhythm_id)
  end
  def catcher_ids
    object.catchers_players.pluck(:catcher_id)
  end
  def partner_pitchers_players
    object.partner_pitchers_players.pluck(:player_id)
  end
end