FactoryBot.define do
  factory :player do
    sequence(:name) { |n| "選手#{n}" }
    sequence(:short_name) { |n| "P#{n}" }
    sequence(:number) { |n| n.to_s }
    throwing_hand { :right_throw }
    batting_hand { :right_bat }
    speed { 3 }
    bunt { 5 }
    steal_start { 10 }
    steal_end { 10 }
    injury_rate { 3 }
    is_pitcher { false }

    trait :pitcher do
      is_pitcher { true }
    end

    trait :relief_only do
      pitcher
      is_relief_only { true }
    end

    trait :fielder do
      is_pitcher { false }
    end

    trait :outfielder do
      is_pitcher { false }
    end

    trait :catcher_position do
      is_pitcher { false }
    end

    trait :two_way do
      is_pitcher { true }
    end
  end
end
