FactoryBot.define do
  factory :competition_entry do
    competition { create(:competition) }
    team { create(:team) }
    base_team { nil }
  end
end
