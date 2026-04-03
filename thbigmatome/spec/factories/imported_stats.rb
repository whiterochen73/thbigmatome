FactoryBot.define do
  factory :imported_stat do
    association :player
    association :competition
    association :team
    stat_type { "batting" }
  end
end
