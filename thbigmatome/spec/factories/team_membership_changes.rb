FactoryBot.define do
  factory :team_membership_change do
    team_membership
    season
    kind { "join" }
    effective_on { Date.current }
    phase { "pre_game" }
    selected_cost_type { "normal_cost" }
    excluded_from_team_total { false }
  end
end
