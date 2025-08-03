class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number, :position, :throwing_hand, :batting_hand,
              :speed, :bunt, :steal_start, :steal_end, :injury_rate, :defense_p, :defense_c,
              :throwing_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss, :defense_of,
              :throwing_of, :defense_lf, :throwing_lf, :defense_cf, :throwing_cf, :defense_rf,
              :throwing_rf, :is_pitcher, :starter_stamina, :relief_stamina, :is_relief_only,
              :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id, :batting_style_id

  # 関連付けられたIDを返すように設定
  has_many :batting_skills
  has_many :player_types
  has_many :biorhythms
  has_many :pitching_skills
  has_many :catchers

  def catchers
    object.catchers.pluck(:id)
  end
  def batting_skills
    object.batting_skills.pluck(:id)
  end
  def player_types
    object.player_types.pluck(:id)
  end
  def biorhythms
    object.biorhythms.pluck(:id)
  end
  def catchers
    object.catchers.pluck(:id)
  end
end