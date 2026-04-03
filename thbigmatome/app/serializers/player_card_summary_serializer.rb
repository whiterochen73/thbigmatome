class PlayerCardSummarySerializer < ActiveModel::Serializer
  attributes :id, :card_type, :handedness, :speed, :bunt,
             :injury_rate, :is_pitcher, :is_relief_only,
             :starter_stamina, :relief_stamina
  belongs_to :card_set
end
