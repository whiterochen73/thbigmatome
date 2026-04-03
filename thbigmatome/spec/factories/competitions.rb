FactoryBot.define do
  factory :competition do
    sequence(:name) { |n| "Competition#{n}" }
    sequence(:year) { |n| 2020 + (n % 10) }
    competition_type { "league_pennant" }
  end
end
