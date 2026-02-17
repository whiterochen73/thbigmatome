FactoryBot.define do
  factory :season_roster do
    season
    team_membership
    squad { "first" }
    registered_on { Date.current }
  end
end
