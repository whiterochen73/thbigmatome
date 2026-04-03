FactoryBot.define do
  factory :squad_text_setting do
    association :team
    position_format { "english" }
    handedness_format { "alphabet" }
    date_format { "absolute" }
    section_header_format { "bracket" }
    show_number_prefix { true }
    batting_stats_config { {} }
    pitching_stats_config { {} }
  end
end
