FactoryBot.define do
  factory :game_lineup_entry do
    association :game
    association :player_card
    role { :starter }
    batting_order { 1 }
    position { "P" }
    is_dh_pitcher { false }
    is_reliever { false }
  end
end
