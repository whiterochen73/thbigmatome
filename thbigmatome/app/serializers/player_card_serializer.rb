class PlayerCardSerializer < ActiveModel::Serializer
  attributes :id, :card_set_id, :player_id, :card_type,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :is_pitcher, :is_relief_only,
             :starter_stamina, :relief_stamina,
             :batting_style_id,
             :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id, :pitching_style_description,
             :special_defense_c, :special_throwing_c,
             :batting_table, :pitching_table,
             :variant, :team_label

  # 登録画面で選べるか（現行カードセットか・公式戦で使えるか）の判断に使う
  attribute :card_set_current do
    object.card_set.is_current
  end

  attribute :official_use_prohibited do
    object.official_use_prohibited
  end

  attribute :version_label do
    object.version_label
  end

  attribute :player_name do
    object.player.name
  end

  attribute :player_number do
    object.player.number
  end

  attribute :card_set_name do
    object.card_set.name
  end

  attribute :primary_position do
    object.primary_position
  end

  attribute :cost do
    object.listed_cost
  end

  attribute :image_url do
    object.card_image_url
  end
end
