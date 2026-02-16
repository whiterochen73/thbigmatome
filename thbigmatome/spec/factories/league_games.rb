FactoryBot.define do
  factory :league_game do
    league_season
    association :home_team, factory: :team
    association :away_team, factory: :team
    game_date { Date.current }
    game_number { 1 }
  end
end
