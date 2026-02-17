FactoryBot.define do
  factory :league do
    sequence(:name) { |n| "リーグ#{n}" }
    num_teams { 6 }
    num_games { 30 }
    active { false }
  end
end
