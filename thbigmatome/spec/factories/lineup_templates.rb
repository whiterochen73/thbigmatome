FactoryBot.define do
  factory :lineup_template do
    association :team
    dh_enabled { true }
    opponent_pitcher_hand { "right" }
  end
end
