FactoryBot.define do
  factory :player_card do
    association :card_set
    association :player
    speed { 3 }
    bunt { 5 }
    steal_start { 10 }
    steal_end { 10 }
    injury_rate { 3 }
  end
end
