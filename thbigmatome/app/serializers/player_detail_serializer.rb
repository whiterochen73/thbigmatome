class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number, :handedness,
              :speed, :bunt, :steal_start, :steal_end, :injury_rate,
              :is_pitcher, :is_relief_only,
              :pitching_style_description, :special_throwing_c

  def handedness
    object.player_cards.first&.handedness
  end

  def is_pitcher
    object.player_cards.first&.is_pitcher || false
  end

  def is_relief_only
    object.player_cards.first&.is_relief_only || false
  end
end
