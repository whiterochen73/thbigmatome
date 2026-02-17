FactoryBot.define do
  factory :league_season do
    league
    sequence(:name) { |n| "リーグシーズン#{n}" }
    start_date { Date.current }
    end_date { Date.current + 30.days }
    status { :pending }
  end
end
