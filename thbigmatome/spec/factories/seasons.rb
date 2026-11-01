FactoryBot.define do
  factory :season do
    team
    current_date { Date.current }
  end
end
