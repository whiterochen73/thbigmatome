class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number, :series

  has_many :player_cards, serializer: PlayerCardSummarySerializer

  # 両方のセットのカードを持つ選手は現行セットのカードを先に並べる
  def player_cards
    object.cards_current_first
  end

  # 新しい改定が上・各改定の中は選手の既定が先でカードごとの行が続く（Player#cost_rows）
  attribute :costs do
    object.cost_rows
  end
end
