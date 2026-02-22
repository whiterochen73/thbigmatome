FactoryBot.define do
  factory :player_card_player_type do
    association :player_card
    association :player_type
  end
end
