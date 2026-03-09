FactoryBot.define do
  factory :player do
    sequence(:name) { |n| "選手#{n}" }
    sequence(:short_name) { |n| "P#{n}" }
    sequence(:number) { |n| n.to_s }

    trait :pitcher do
    end

    trait :relief_only do
      pitcher
    end

    trait :fielder do
    end

    trait :outfielder do
    end

    trait :catcher_position do
    end

    trait :two_way do
    end
  end
end
