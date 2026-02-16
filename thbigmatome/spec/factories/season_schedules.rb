FactoryBot.define do
  factory :season_schedule do
    season
    sequence(:date) { |n| Date.new(2026, 4, 1) + n.days }
    date_type { "game_day" }

    trait :game_day do
      date_type { "game_day" }
    end

    trait :interleague_game_day do
      date_type { "interleague_game_day" }
    end

    trait :off_day do
      date_type { "off_day" }
    end

    trait :event_day do
      date_type { "event_day" }
    end
  end
end
