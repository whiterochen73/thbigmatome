FactoryBot.define do
  factory :lineup_template_entry do
    association :lineup_template
    association :player
    sequence(:batting_order) { |n| ((n - 1) % 9) + 1 }
    position { "RF" }
  end
end
