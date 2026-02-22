FactoryBot.define do
  factory :competition_roster do
    association :competition_entry
    association :player_card
    squad { :first_squad }
  end
end
