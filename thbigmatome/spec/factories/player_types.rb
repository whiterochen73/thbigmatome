FactoryBot.define do
  factory :player_type do
    sequence(:name) { |n| "タイプ#{n}" }
    description { nil }
    category { nil }

    trait :touhou do
      name { "東方" }
      category { "touhou" }
    end

    trait :outside_world do
      name { "外の世界" }
      category { "outside_world" }
    end

    trait :two_way do
      name { "二刀流" }
      category { nil }
    end
  end
end
