class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number

  has_many :player_cards, serializer: PlayerCardSummarySerializer

  attribute :costs do
    object.cost_players.includes(:cost).map do |cp|
      {
        cost_name: cp.cost.name,
        normal_cost: cp.normal_cost,
        pitcher_only_cost: cp.pitcher_only_cost,
        fielder_only_cost: cp.fielder_only_cost,
        relief_only_cost: cp.relief_only_cost,
        two_way_cost: cp.two_way_cost
      }
    end
  end
end
