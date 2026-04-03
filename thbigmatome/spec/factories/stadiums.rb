FactoryBot.define do
  factory :stadium do
    sequence(:name) { |n| "Stadium #{n}" }
    sequence(:code) { |n| "ST#{n}" }
    indoor { false }
    up_table_ids { [] }
  end
end
