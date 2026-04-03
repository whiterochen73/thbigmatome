FactoryBot.define do
  factory :at_bat do
    association :game
    association :batter, factory: :player
    association :pitcher, factory: [ :player, :pitcher ]
    sequence(:seq) { |n| n }
    inning { 1 }
    half { "top" }
    outs { 0 }
    outs_after { 1 }
    result_code { "1B" }
    play_type { "normal" }
    rolls { [] }
    runners { [] }
    runners_after { [] }
    scored { false }
    rbi { 0 }
    status { :draft }
  end
end
