FactoryBot.define do
  factory :card_set do
    sequence(:year) { |n| 2020 + n }
    sequence(:name) { |n| "Card Set #{n}" }
    set_type { "annual" }
    series { CardSet.series_for(set_type) || "touhou" }
  end
end
