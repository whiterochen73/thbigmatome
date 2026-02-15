FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "user_#{n}" }
    display_name { Faker::Name.name }
    password { 'password123' }

    trait :commissioner do
      role { :commissioner }
    end
  end
end
