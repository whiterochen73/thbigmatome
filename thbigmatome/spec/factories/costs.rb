FactoryBot.define do
  factory :cost do
    sequence(:name) { |n| "コスト表#{n}" }
    start_date { Date.new(2026, 1, 1) }
    end_date { nil }
  end
end
