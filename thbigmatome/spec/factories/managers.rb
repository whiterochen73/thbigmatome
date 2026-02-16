FactoryBot.define do
  factory :manager do
    sequence(:name) { |n| "監督#{n}" }
    sequence(:short_name) { |n| "M#{n}" }
    role { :director }
  end
end
