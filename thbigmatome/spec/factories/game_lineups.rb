FactoryBot.define do
  factory :game_lineup do
    association :team
    lineup_data { { "dh_enabled" => true, "opponent_pitcher_hand" => "right", "starting_lineup" => [] } }
  end
end
