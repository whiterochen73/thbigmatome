FactoryBot.define do
  factory :player_absence do
    team_membership
    season
    absence_type { :injury }
    start_date { Date.current }
    duration { 5 }
    duration_unit { "days" }
    reason { "テスト用離脱" }

    trait :injury do
      absence_type { :injury }
    end

    trait :suspension do
      absence_type { :suspension }
    end

    trait :reconditioning do
      absence_type { :reconditioning }
    end

    trait :games_based do
      duration_unit { "games" }
      duration { 3 }
    end
  end
end
