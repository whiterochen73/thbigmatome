FactoryBot.define do
  factory :team_membership do
    team
    player
    squad { "second" }
    selected_cost_type { "normal_cost" }
    excluded_from_team_total { false }

    trait :first_squad do
      squad { "first" }
    end

    trait :excluded do
      excluded_from_team_total { true }
    end
  end
end
