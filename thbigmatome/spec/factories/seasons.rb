FactoryBot.define do
  factory :season do
    team
    sequence(:name) { |n| "シーズン#{n}" }
    current_date { Date.current }
  end
end
