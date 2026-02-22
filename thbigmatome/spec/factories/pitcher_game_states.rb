FactoryBot.define do
  factory :pitcher_game_state do
    association :game
    association :pitcher, factory: [ :player, :pitcher ]
    association :competition
    association :team
    role { "starter" }
  end
end
