FactoryBot.define do
  factory :at_bat_record do
    association :game_record
    inning { 1 }
    half { "top" }
    sequence(:ab_num) { |n| n }
    pitcher_name { "投手名" }
    batter_name { "打者名" }
    result_code { "H" }
    strategy { "hitting" }
    runners_before { {} }
    runners_after { {} }
    outs_before { 0 }
    outs_after { 1 }
    runs_scored { 0 }
    is_modified { false }
    extra_data { {} }

    trait :modified do
      is_modified { true }
      modified_fields { { "result_code" => { "from" => "K", "to" => "H" } } }
    end
  end
end
