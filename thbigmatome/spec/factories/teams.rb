FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "チーム#{n}" }
    sequence(:short_name) { |n| "T#{n}" }
    is_active { true }
  end
end
