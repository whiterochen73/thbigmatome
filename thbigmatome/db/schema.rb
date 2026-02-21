# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_21_000012) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "at_bats", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "seq", null: false
    t.integer "inning", null: false
    t.string "half", null: false
    t.integer "outs", null: false
    t.jsonb "runners", default: [], null: false
    t.bigint "batter_id", null: false
    t.bigint "pitcher_id", null: false
    t.bigint "pinch_hit_for_id"
    t.string "play_type", default: "normal", null: false
    t.jsonb "rolls", default: [], null: false
    t.string "result_code", null: false
    t.integer "rbi", default: 0
    t.boolean "scored", default: false
    t.jsonb "runners_after", default: [], null: false
    t.integer "outs_after", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "batter_id" ], name: "index_at_bats_on_batter_id"
    t.index [ "game_id", "inning", "half" ], name: "index_at_bats_on_game_id_and_inning_and_half"
    t.index [ "game_id", "seq" ], name: "index_at_bats_on_game_id_and_seq", unique: true
    t.index [ "game_id" ], name: "index_at_bats_on_game_id"
    t.index [ "pinch_hit_for_id" ], name: "index_at_bats_on_pinch_hit_for_id"
    t.index [ "pitcher_id" ], name: "index_at_bats_on_pitcher_id"
  end

  create_table "batting_skills", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "skill_type", default: "neutral", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_batting_skills_on_name", unique: true
  end

  create_table "batting_styles", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_batting_styles_on_name", unique: true
  end

  create_table "biorhythms", force: :cascade do |t|
    t.string "name", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_biorhythms_on_name", unique: true
  end

  create_table "card_sets", force: :cascade do |t|
    t.integer "year", null: false
    t.string "name", null: false
    t.string "set_type", default: "annual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "year", "set_type" ], name: "index_card_sets_on_year_and_set_type"
  end

  create_table "catchers_players", id: false, force: :cascade do |t|
    t.bigint "player_id"
    t.bigint "catcher_id"
    t.index [ "catcher_id" ], name: "index_catchers_players_on_catcher_id"
    t.index [ "player_id", "catcher_id" ], name: "index_catchers_players_on_player_id_and_catcher_id", unique: true
    t.index [ "player_id" ], name: "index_catchers_players_on_player_id"
  end

  create_table "competition_entries", force: :cascade do |t|
    t.bigint "competition_id", null: false
    t.bigint "team_id", null: false
    t.bigint "base_team_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "base_team_id" ], name: "index_competition_entries_on_base_team_id"
    t.index [ "competition_id", "team_id" ], name: "index_competition_entries_on_competition_id_and_team_id", unique: true
    t.index [ "competition_id" ], name: "index_competition_entries_on_competition_id"
    t.index [ "team_id" ], name: "index_competition_entries_on_team_id"
  end

  create_table "competitions", force: :cascade do |t|
    t.string "name", null: false
    t.string "competition_type", null: false
    t.integer "year", null: false
    t.jsonb "rules", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_type" ], name: "index_competitions_on_competition_type"
    t.index [ "name", "year" ], name: "index_competitions_on_name_and_year", unique: true
  end

  create_table "cost_players", force: :cascade do |t|
    t.bigint "cost_id", null: false
    t.bigint "player_id", null: false
    t.integer "normal_cost"
    t.integer "relief_only_cost"
    t.integer "pitcher_only_cost"
    t.integer "fielder_only_cost"
    t.integer "two_way_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "cost_exempt", default: false, null: false
    t.index [ "cost_id", "player_id" ], name: "index_cost_players_on_cost_id_and_player_id"
    t.index [ "cost_id" ], name: "index_cost_players_on_cost_id"
    t.index [ "player_id" ], name: "index_cost_players_on_player_id"
  end

  create_table "costs", force: :cascade do |t|
    t.string "name"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "end_date" ], name: "index_costs_on_active", unique: true, where: "(end_date IS NULL)"
  end

  create_table "game_events", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "seq", null: false
    t.string "event_type", null: false
    t.integer "inning", null: false
    t.string "half", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "event_type" ], name: "index_game_events_on_event_type"
    t.index [ "game_id", "inning", "half" ], name: "index_game_events_on_game_id_and_inning_and_half"
    t.index [ "game_id", "seq" ], name: "index_game_events_on_game_id_and_seq", unique: true
    t.index [ "game_id" ], name: "index_game_events_on_game_id"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "competition_id", null: false
    t.bigint "home_team_id", null: false
    t.bigint "visitor_team_id", null: false
    t.bigint "stadium_id", null: false
    t.boolean "dh", default: false
    t.string "setting_date"
    t.string "home_schedule_date"
    t.string "visitor_schedule_date"
    t.integer "home_game_number"
    t.integer "visitor_game_number"
    t.date "real_date"
    t.integer "home_score"
    t.integer "visitor_score"
    t.string "status", default: "draft", null: false
    t.string "source", default: "live", null: false
    t.text "raw_log"
    t.jsonb "roster_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_id" ], name: "index_games_on_competition_id"
    t.index [ "home_team_id", "visitor_team_id", "real_date" ], name: "index_games_on_home_team_id_and_visitor_team_id_and_real_date"
    t.index [ "home_team_id" ], name: "index_games_on_home_team_id"
    t.index [ "stadium_id" ], name: "index_games_on_stadium_id"
    t.index [ "status" ], name: "index_games_on_status"
    t.index [ "visitor_team_id" ], name: "index_games_on_visitor_team_id"
  end

  create_table "imported_stats", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "competition_id", null: false
    t.bigint "team_id", null: false
    t.string "stat_type", null: false
    t.string "as_of_date"
    t.integer "as_of_game_number"
    t.jsonb "stats", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_id" ], name: "index_imported_stats_on_competition_id"
    t.index [ "player_id", "competition_id", "stat_type" ], name: "idx_on_player_id_competition_id_stat_type_0f5a1c1e93", unique: true
    t.index [ "player_id" ], name: "index_imported_stats_on_player_id"
    t.index [ "team_id" ], name: "index_imported_stats_on_team_id"
  end

  create_table "league_games", force: :cascade do |t|
    t.bigint "league_season_id", null: false
    t.bigint "home_team_id", null: false
    t.bigint "away_team_id", null: false
    t.date "game_date", null: false
    t.integer "game_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "away_team_id" ], name: "index_league_games_on_away_team_id"
    t.index [ "home_team_id" ], name: "index_league_games_on_home_team_id"
    t.index [ "league_season_id" ], name: "index_league_games_on_league_season_id"
  end

  create_table "league_memberships", force: :cascade do |t|
    t.bigint "league_id", null: false
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "league_id", "team_id" ], name: "index_league_memberships_on_league_id_and_team_id", unique: true
    t.index [ "league_id" ], name: "index_league_memberships_on_league_id"
    t.index [ "team_id" ], name: "index_league_memberships_on_team_id"
  end

  create_table "league_pool_players", force: :cascade do |t|
    t.bigint "league_season_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "league_season_id" ], name: "index_league_pool_players_on_league_season_id"
    t.index [ "player_id" ], name: "index_league_pool_players_on_player_id"
  end

  create_table "league_seasons", force: :cascade do |t|
    t.bigint "league_id", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "league_id" ], name: "index_league_seasons_on_league_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.string "name", null: false
    t.integer "num_teams", default: 6, null: false
    t.integer "num_games", default: 30, null: false
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "managers", force: :cascade do |t|
    t.string "name"
    t.string "short_name"
    t.string "irc_name"
    t.string "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
  end

  create_table "pitcher_game_states", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "pitcher_id", null: false
    t.bigint "competition_id", null: false
    t.bigint "team_id", null: false
    t.string "role", null: false
    t.decimal "innings_pitched", precision: 5, scale: 1
    t.string "result_category"
    t.integer "cumulative_innings", default: 0
    t.integer "fatigue_p_used", default: 0
    t.string "injury_check"
    t.string "schedule_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_id" ], name: "index_pitcher_game_states_on_competition_id"
    t.index [ "game_id", "pitcher_id" ], name: "index_pitcher_game_states_on_game_id_and_pitcher_id", unique: true
    t.index [ "game_id" ], name: "index_pitcher_game_states_on_game_id"
    t.index [ "pitcher_id" ], name: "index_pitcher_game_states_on_pitcher_id"
    t.index [ "team_id" ], name: "index_pitcher_game_states_on_team_id"
  end

  create_table "pitching_skills", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "skill_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_pitching_skills_on_name", unique: true
  end

  create_table "pitching_styles", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_pitching_styles_on_name", unique: true
  end

  create_table "player_absences", force: :cascade do |t|
    t.bigint "team_membership_id", null: false
    t.bigint "season_id", null: false
    t.integer "absence_type", null: false
    t.text "reason"
    t.date "start_date", null: false
    t.integer "duration", null: false
    t.string "duration_unit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "season_id" ], name: "index_player_absences_on_season_id"
    t.index [ "team_membership_id" ], name: "index_player_absences_on_team_membership_id"
  end

  create_table "player_batting_skills", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "batting_skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "batting_skill_id" ], name: "index_player_batting_skills_on_batting_skill_id"
    t.index [ "player_id", "batting_skill_id" ], name: "index_player_batting_skills_on_player_id_and_batting_skill_id", unique: true
    t.index [ "player_id" ], name: "index_player_batting_skills_on_player_id"
  end

  create_table "player_biorhythms", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "biorhythm_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "biorhythm_id" ], name: "index_player_biorhythms_on_biorhythm_id"
    t.index [ "player_id", "biorhythm_id" ], name: "index_player_biorhythms_on_player_id_and_biorhythm_id", unique: true
    t.index [ "player_id" ], name: "index_player_biorhythms_on_player_id"
  end

  create_table "player_card_player_types", force: :cascade do |t|
    t.bigint "player_card_id", null: false
    t.bigint "player_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "player_card_id", "player_type_id" ], name: "idx_on_player_card_id_player_type_id_81367eec7c", unique: true
    t.index [ "player_card_id" ], name: "index_player_card_player_types_on_player_card_id"
    t.index [ "player_type_id" ], name: "index_player_card_player_types_on_player_type_id"
  end

  create_table "player_cards", force: :cascade do |t|
    t.bigint "card_set_id", null: false
    t.bigint "player_id", null: false
    t.integer "speed"
    t.integer "bunt"
    t.integer "steal_start"
    t.integer "steal_end"
    t.integer "injury_rate"
    t.boolean "is_pitcher", default: false
    t.boolean "is_relief_only", default: false
    t.integer "starter_stamina"
    t.integer "relief_stamina"
    t.bigint "batting_style_id"
    t.string "batting_style_description"
    t.bigint "pitching_style_id"
    t.bigint "pinch_pitching_style_id"
    t.bigint "catcher_pitching_style_id"
    t.string "pitching_style_description"
    t.string "defense_p"
    t.integer "throwing_c"
    t.string "defense_c"
    t.string "special_defense_c"
    t.integer "special_throwing_c"
    t.string "defense_1b"
    t.string "defense_2b"
    t.string "defense_3b"
    t.string "defense_ss"
    t.string "defense_of"
    t.string "throwing_of"
    t.string "defense_lf"
    t.string "throwing_lf"
    t.string "defense_cf"
    t.string "throwing_cf"
    t.string "defense_rf"
    t.string "throwing_rf"
    t.jsonb "batting_table", default: {}, null: false
    t.jsonb "pitching_table", default: {}, null: false
    t.jsonb "abilities", default: {}, null: false
    t.string "card_image_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "batting_style_id" ], name: "index_player_cards_on_batting_style_id"
    t.index [ "card_set_id", "player_id" ], name: "index_player_cards_on_card_set_id_and_player_id", unique: true
    t.index [ "card_set_id" ], name: "index_player_cards_on_card_set_id"
    t.index [ "catcher_pitching_style_id" ], name: "index_player_cards_on_catcher_pitching_style_id"
    t.index [ "pinch_pitching_style_id" ], name: "index_player_cards_on_pinch_pitching_style_id"
    t.index [ "pitching_style_id" ], name: "index_player_cards_on_pitching_style_id"
    t.index [ "player_id" ], name: "index_player_cards_on_player_id"
  end

  create_table "player_pitching_skills", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "pitching_skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "pitching_skill_id" ], name: "index_player_pitching_skills_on_pitching_skill_id"
    t.index [ "player_id", "pitching_skill_id" ], name: "idx_on_player_id_pitching_skill_id_bd496ce465", unique: true
    t.index [ "player_id" ], name: "index_player_pitching_skills_on_player_id"
  end

  create_table "player_player_types", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "player_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "player_id", "player_type_id" ], name: "index_player_player_types_on_player_id_and_player_type_id", unique: true
    t.index [ "player_id" ], name: "index_player_player_types_on_player_id"
    t.index [ "player_type_id" ], name: "index_player_player_types_on_player_type_id"
  end

  create_table "player_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.index [ "name" ], name: "index_player_types_on_name", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.string "name", null: false
    t.string "short_name"
    t.string "number", null: false
    t.string "position"
    t.string "throwing_hand"
    t.string "batting_hand"
    t.integer "speed"
    t.integer "bunt"
    t.integer "steal_start"
    t.integer "steal_end"
    t.integer "injury_rate"
    t.string "defense_p"
    t.string "defense_c"
    t.integer "throwing_c"
    t.string "defense_1b"
    t.string "defense_2b"
    t.string "defense_3b"
    t.string "defense_ss"
    t.string "defense_of"
    t.string "throwing_of"
    t.string "defense_lf"
    t.string "throwing_lf"
    t.string "defense_cf"
    t.string "throwing_cf"
    t.string "defense_rf"
    t.string "throwing_rf"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batting_style_id"
    t.boolean "is_pitcher", default: false
    t.boolean "is_relief_only", default: false
    t.integer "starter_stamina"
    t.integer "relief_stamina"
    t.bigint "pitching_style_id"
    t.bigint "pinch_pitching_style_id"
    t.bigint "catcher_pitching_style_id"
    t.string "special_defense_c"
    t.integer "special_throwing_c"
    t.string "pitching_style_description"
    t.string "batting_style_description"
    t.index [ "batting_style_id" ], name: "index_players_on_batting_style_id"
    t.index [ "catcher_pitching_style_id" ], name: "index_players_on_catcher_pitching_style_id"
    t.index [ "pinch_pitching_style_id" ], name: "index_players_on_pinch_pitching_style_id"
    t.index [ "pitching_style_id" ], name: "index_players_on_pitching_style_id"
  end

  create_table "schedule_details", force: :cascade do |t|
    t.bigint "schedule_id", null: false
    t.date "date"
    t.string "date_type"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "schedule_id", "date" ], name: "index_schedule_details_on_schedule_id_and_date", unique: true
    t.index [ "schedule_id" ], name: "index_schedule_details_on_schedule_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.string "name"
    t.date "start_date"
    t.date "end_date"
    t.date "effective_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "season_rosters", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.bigint "team_membership_id", null: false
    t.string "squad", null: false
    t.date "registered_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "season_id" ], name: "index_season_rosters_on_season_id"
    t.index [ "team_membership_id" ], name: "index_season_rosters_on_team_membership_id"
  end

  create_table "season_schedules", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.date "date", null: false
    t.string "date_type"
    t.bigint "announced_starter_id"
    t.bigint "opponent_team_id"
    t.integer "game_number"
    t.string "stadium"
    t.string "home_away"
    t.boolean "designated_hitter_enabled"
    t.integer "score"
    t.integer "opponent_score"
    t.bigint "winning_pitcher_id"
    t.bigint "losing_pitcher_id"
    t.bigint "save_pitcher_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "scoreboard"
    t.jsonb "starting_lineup"
    t.jsonb "opponent_starting_lineup"
    t.index [ "announced_starter_id" ], name: "index_season_schedules_on_announced_starter_id"
    t.index [ "losing_pitcher_id" ], name: "index_season_schedules_on_losing_pitcher_id"
    t.index [ "opponent_team_id" ], name: "index_season_schedules_on_opponent_team_id"
    t.index [ "save_pitcher_id" ], name: "index_season_schedules_on_save_pitcher_id"
    t.index [ "season_id" ], name: "index_season_schedules_on_season_id"
    t.index [ "winning_pitcher_id" ], name: "index_season_schedules_on_winning_pitcher_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.string "name", null: false
    t.date "current_date", null: false
    t.bigint "key_player_id"
    t.string "team_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "key_player_id" ], name: "index_seasons_on_key_player_id"
    t.index [ "team_id" ], name: "index_seasons_on_team_id"
  end

  create_table "stadiums", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.jsonb "up_table_ids", default: [], null: false
    t.boolean "indoor", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "code" ], name: "index_stadiums_on_code", unique: true
    t.index [ "name" ], name: "index_stadiums_on_name", unique: true
  end

  create_table "team_managers", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "manager_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "manager_id" ], name: "index_team_managers_on_manager_id"
    t.index [ "team_id" ], name: "index_team_managers_on_team_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "player_id", null: false
    t.string "squad", default: "second", null: false
    t.string "selected_cost_type", default: "normal_cost", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "excluded_from_team_total", default: false, null: false
    t.index [ "player_id" ], name: "index_team_memberships_on_player_id"
    t.index [ "team_id", "player_id" ], name: "index_team_memberships_on_team_id_and_player_id", unique: true
    t.index [ "team_id" ], name: "index_team_memberships_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "short_name"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "display_name"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
  end

  add_foreign_key "at_bats", "games"
  add_foreign_key "at_bats", "players", column: "batter_id"
  add_foreign_key "at_bats", "players", column: "pinch_hit_for_id"
  add_foreign_key "at_bats", "players", column: "pitcher_id"
  add_foreign_key "catchers_players", "players"
  add_foreign_key "catchers_players", "players", column: "catcher_id"
  add_foreign_key "competition_entries", "competitions"
  add_foreign_key "competition_entries", "teams"
  add_foreign_key "competition_entries", "teams", column: "base_team_id"
  add_foreign_key "cost_players", "costs"
  add_foreign_key "cost_players", "players"
  add_foreign_key "game_events", "games"
  add_foreign_key "games", "competitions"
  add_foreign_key "games", "stadiums"
  add_foreign_key "games", "teams", column: "home_team_id"
  add_foreign_key "games", "teams", column: "visitor_team_id"
  add_foreign_key "imported_stats", "competitions"
  add_foreign_key "imported_stats", "players"
  add_foreign_key "imported_stats", "teams"
  add_foreign_key "league_games", "league_seasons"
  add_foreign_key "league_games", "teams", column: "away_team_id"
  add_foreign_key "league_games", "teams", column: "home_team_id"
  add_foreign_key "league_memberships", "leagues"
  add_foreign_key "league_memberships", "teams"
  add_foreign_key "league_pool_players", "league_seasons"
  add_foreign_key "league_pool_players", "players"
  add_foreign_key "league_seasons", "leagues"
  add_foreign_key "pitcher_game_states", "competitions"
  add_foreign_key "pitcher_game_states", "games"
  add_foreign_key "pitcher_game_states", "players", column: "pitcher_id"
  add_foreign_key "pitcher_game_states", "teams"
  add_foreign_key "player_absences", "seasons"
  add_foreign_key "player_absences", "team_memberships"
  add_foreign_key "player_batting_skills", "batting_skills"
  add_foreign_key "player_batting_skills", "players"
  add_foreign_key "player_biorhythms", "biorhythms"
  add_foreign_key "player_biorhythms", "players"
  add_foreign_key "player_card_player_types", "player_cards"
  add_foreign_key "player_card_player_types", "player_types"
  add_foreign_key "player_cards", "batting_styles"
  add_foreign_key "player_cards", "card_sets"
  add_foreign_key "player_cards", "pitching_styles"
  add_foreign_key "player_cards", "pitching_styles", column: "catcher_pitching_style_id"
  add_foreign_key "player_cards", "pitching_styles", column: "pinch_pitching_style_id"
  add_foreign_key "player_cards", "players"
  add_foreign_key "player_pitching_skills", "pitching_skills"
  add_foreign_key "player_pitching_skills", "players"
  add_foreign_key "player_player_types", "player_types"
  add_foreign_key "player_player_types", "players"
  add_foreign_key "players", "batting_styles"
  add_foreign_key "players", "pitching_styles"
  add_foreign_key "players", "pitching_styles", column: "catcher_pitching_style_id"
  add_foreign_key "players", "pitching_styles", column: "pinch_pitching_style_id"
  add_foreign_key "schedule_details", "schedules"
  add_foreign_key "season_rosters", "seasons"
  add_foreign_key "season_rosters", "team_memberships"
  add_foreign_key "season_schedules", "players", column: "losing_pitcher_id"
  add_foreign_key "season_schedules", "players", column: "save_pitcher_id"
  add_foreign_key "season_schedules", "players", column: "winning_pitcher_id"
  add_foreign_key "season_schedules", "seasons"
  add_foreign_key "season_schedules", "team_memberships", column: "announced_starter_id"
  add_foreign_key "season_schedules", "teams", column: "opponent_team_id"
  add_foreign_key "seasons", "team_memberships", column: "key_player_id"
  add_foreign_key "seasons", "teams"
  add_foreign_key "team_managers", "managers"
  add_foreign_key "team_managers", "teams"
  add_foreign_key "team_memberships", "players"
  add_foreign_key "team_memberships", "teams"
end
