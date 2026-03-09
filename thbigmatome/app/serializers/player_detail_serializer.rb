class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number

  has_many :player_cards, serializer: PlayerCardSummarySerializer
end
