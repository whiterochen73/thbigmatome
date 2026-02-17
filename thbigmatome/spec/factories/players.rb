FactoryBot.define do
  factory :player do
    sequence(:name) { |n| "選手#{n}" }
    sequence(:short_name) { |n| "P#{n}" }
    sequence(:number) { |n| n.to_s }
    position { :catcher }
    throwing_hand { :right_throw }
    batting_hand { :right_bat }
    speed { 3 }
    bunt { 5 }
    steal_start { 10 }
    steal_end { 10 }
    injury_rate { 3 }
    is_pitcher { false }

    trait :pitcher do
      position { :pitcher }
      is_pitcher { true }
      defense_p { "3B" }
      starter_stamina { 6 }
      relief_stamina { 2 }
    end

    trait :relief_only do
      pitcher
      is_relief_only { true }
      starter_stamina { nil }
    end

    trait :fielder do
      position { :infielder }
      is_pitcher { false }
      defense_1b { "3B" }
    end

    trait :outfielder do
      position { :outfielder }
      defense_of { "3B" }
      throwing_of { "B" }
    end

    trait :catcher_position do
      position { :catcher }
      defense_c { "4A" }
      throwing_c { 2 }
    end

    trait :two_way do
      is_pitcher { true }
      defense_p { "3B" }
      starter_stamina { 5 }
      relief_stamina { 1 }
      defense_1b { "2C" }
    end
  end
end
