FactoryBot.define do
  factory :game do
    association :competition
    association :home_team, factory: :team
    association :visitor_team, factory: :team
    association :stadium
    real_date { Date.today }
    status { "draft" }
    source { "live" }
  end
end
