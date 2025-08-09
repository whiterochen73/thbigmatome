class CostPlayerSerializer < ActiveModel::Serializer
  attributes :id, :cost_id, :player_id, :normal_cost, :relief_only_cost, :pitcher_only_cost, :fielder_only_cost, :two_way_cost
end
