FactoryBot.define do
  factory :game_event do
    association :game
    sequence(:seq) { |n| n }
    event_type { "score" }
    inning { 1 }
    half { "top" }
    details { {} }
  end
end
