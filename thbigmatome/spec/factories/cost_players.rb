FactoryBot.define do
  factory :cost_player do
    cost
    player
    normal_cost { 5 }
    relief_only_cost { nil }
    pitcher_only_cost { nil }
    fielder_only_cost { nil }
    two_way_cost { nil }
  end
end
