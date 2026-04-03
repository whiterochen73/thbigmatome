FactoryBot.define do
  factory :game_record do
    association :team
    opponent_team_name { "対戦チーム" }
    game_date { Date.today }
    stadium { "甲子園" }
    score_home { 3 }
    score_away { 2 }
    result { "win" }
    status { "draft" }
    parser_version { "1.0.0" }
    parsed_at { Time.current }

    trait :confirmed do
      status { "confirmed" }
      confirmed_at { Time.current }
    end
  end
end
