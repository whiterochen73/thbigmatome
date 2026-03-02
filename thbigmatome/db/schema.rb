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

ActiveRecord::Schema[8.1].define(version: 2026_03_02_114440) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ability_definitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "effect_description"
    t.string "name", null: false
    t.string "typical_role"
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_ability_definitions_on_name", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index [ "blob_id" ], name: "index_active_storage_attachments_on_blob_id"
    t.index [ "record_type", "record_id", "name", "blob_id" ], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index [ "key" ], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index [ "blob_id", "variation_digest" ], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "at_bat_records", force: :cascade do |t|
    t.integer "ab_num"
    t.string "bat_result"
    t.integer "bat_roll"
    t.string "batter_id"
    t.string "batter_name"
    t.datetime "created_at", null: false
    t.jsonb "discrepancies", default: [], null: false
    t.jsonb "extra_data", default: {}
    t.bigint "game_record_id", null: false
    t.string "half"
    t.integer "inning"
    t.boolean "is_modified", default: false, null: false
    t.boolean "is_reviewed", default: false, null: false
    t.jsonb "modified_fields"
    t.integer "outs_after"
    t.integer "outs_before"
    t.string "pitch_result"
    t.integer "pitch_roll"
    t.string "pitcher_id"
    t.string "pitcher_name"
    t.text "play_description"
    t.string "result_code"
    t.text "review_notes"
    t.jsonb "runners_after", default: {}
    t.jsonb "runners_before", default: {}
    t.integer "runs_scored", default: 0, null: false
    t.jsonb "source_events", default: [], null: false
    t.string "strategy"
    t.datetime "updated_at", null: false
    t.index [ "game_record_id", "ab_num" ], name: "index_at_bat_records_on_game_record_id_and_ab_num", unique: true
    t.index [ "game_record_id" ], name: "index_at_bat_records_on_game_record_id"
  end

  create_table "at_bats", force: :cascade do |t|
    t.bigint "batter_id", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.string "half", null: false
    t.integer "inning", null: false
    t.integer "outs", null: false
    t.integer "outs_after", null: false
    t.bigint "pinch_hit_for_id"
    t.bigint "pitcher_id", null: false
    t.string "play_type", default: "normal", null: false
    t.integer "rbi", default: 0
    t.string "result_code", null: false
    t.jsonb "rolls", default: [], null: false
    t.jsonb "runners", default: [], null: false
    t.jsonb "runners_after", default: [], null: false
    t.boolean "scored", default: false
    t.integer "seq", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index [ "batter_id" ], name: "index_at_bats_on_batter_id"
    t.index [ "game_id", "inning", "half" ], name: "index_at_bats_on_game_id_and_inning_and_half"
    t.index [ "game_id", "seq" ], name: "index_at_bats_on_game_id_and_seq", unique: true
    t.index [ "game_id", "status" ], name: "index_at_bats_on_game_id_and_status"
    t.index [ "game_id" ], name: "index_at_bats_on_game_id"
    t.index [ "pinch_hit_for_id" ], name: "index_at_bats_on_pinch_hit_for_id"
    t.index [ "pitcher_id" ], name: "index_at_bats_on_pitcher_id"
  end

  create_table "batting_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "skill_type", default: "neutral", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_batting_skills_on_name", unique: true
  end

  create_table "batting_styles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_batting_styles_on_name", unique: true
  end

  create_table "biorhythms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_biorhythms_on_name", unique: true
  end

  create_table "card_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "set_type", default: "annual", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index [ "year", "set_type" ], name: "index_card_sets_on_year_and_set_type", unique: true
  end

  create_table "catchers_players", id: false, force: :cascade do |t|
    t.bigint "catcher_id"
    t.bigint "player_id"
    t.index [ "catcher_id" ], name: "index_catchers_players_on_catcher_id"
    t.index [ "player_id", "catcher_id" ], name: "index_catchers_players_on_player_id_and_catcher_id", unique: true
    t.index [ "player_id" ], name: "index_catchers_players_on_player_id"
  end

  create_table "competition_entries", force: :cascade do |t|
    t.bigint "base_team_id"
    t.bigint "competition_id", null: false
    t.datetime "created_at", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "base_team_id" ], name: "index_competition_entries_on_base_team_id"
    t.index [ "competition_id", "team_id" ], name: "index_competition_entries_on_competition_id_and_team_id", unique: true
    t.index [ "competition_id" ], name: "index_competition_entries_on_competition_id"
    t.index [ "team_id" ], name: "index_competition_entries_on_team_id"
  end

  create_table "competition_rosters", force: :cascade do |t|
    t.bigint "competition_entry_id", null: false
    t.datetime "created_at", null: false
    t.bigint "player_card_id", null: false
    t.integer "squad", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_entry_id", "player_card_id" ], name: "index_competition_rosters_on_entry_and_card", unique: true
    t.index [ "competition_entry_id" ], name: "index_competition_rosters_on_competition_entry_id"
    t.index [ "player_card_id" ], name: "index_competition_rosters_on_player_card_id"
  end

  create_table "competitions", force: :cascade do |t|
    t.string "competition_type", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "rules", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index [ "competition_type" ], name: "index_competitions_on_competition_type"
    t.index [ "name", "year" ], name: "index_competitions_on_name_and_year", unique: true
  end

  create_table "cost_players", force: :cascade do |t|
    t.boolean "cost_exempt", default: false, null: false
    t.bigint "cost_id", null: false
    t.datetime "created_at", null: false
    t.integer "fielder_only_cost"
    t.integer "normal_cost"
    t.integer "pitcher_only_cost"
    t.bigint "player_id", null: false
    t.integer "relief_only_cost"
    t.integer "two_way_cost"
    t.datetime "updated_at", null: false
    t.index [ "cost_id", "player_id" ], name: "index_cost_players_on_cost_id_and_player_id"
    t.index [ "cost_id" ], name: "index_cost_players_on_cost_id"
    t.index [ "player_id" ], name: "index_cost_players_on_player_id"
  end

  create_table "costs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "name"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index [ "end_date" ], name: "index_costs_on_active", unique: true, where: "(end_date IS NULL)"
  end

  create_table "game_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.string "event_type", null: false
    t.bigint "game_id", null: false
    t.string "half", null: false
    t.integer "inning", null: false
    t.integer "seq", null: false
    t.datetime "updated_at", null: false
    t.index [ "event_type" ], name: "index_game_events_on_event_type"
    t.index [ "game_id", "inning", "half" ], name: "index_game_events_on_game_id_and_inning_and_half"
    t.index [ "game_id", "seq" ], name: "index_game_events_on_game_id_and_seq", unique: true
    t.index [ "game_id" ], name: "index_game_events_on_game_id"
  end

  create_table "game_lineup_entries", force: :cascade do |t|
    t.integer "batting_order"
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.boolean "is_dh_pitcher", default: false, null: false
    t.boolean "is_reliever", default: false, null: false
    t.bigint "player_card_id", null: false
    t.string "position"
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.index [ "game_id", "player_card_id" ], name: "index_game_lineup_entries_on_game_id_and_player_card_id", unique: true
    t.index [ "game_id" ], name: "index_game_lineup_entries_on_game_id"
    t.index [ "player_card_id" ], name: "index_game_lineup_entries_on_player_card_id"
  end

  create_table "game_records", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.date "game_date"
    t.bigint "game_id"
    t.string "opponent_team_name"
    t.datetime "parsed_at"
    t.string "parser_version"
    t.datetime "played_at"
    t.string "result"
    t.integer "score_away"
    t.integer "score_home"
    t.text "source_log"
    t.string "stadium"
    t.string "status", default: "draft", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "game_date" ], name: "index_game_records_on_game_date"
    t.index [ "game_id" ], name: "index_game_records_on_game_id_partial", unique: true, where: "(game_id IS NOT NULL)"
    t.index [ "status" ], name: "index_game_records_on_status"
    t.index [ "team_id" ], name: "index_game_records_on_team_id"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "competition_id", null: false
    t.datetime "created_at", null: false
    t.boolean "dh", default: false
    t.integer "home_game_number"
    t.string "home_schedule_date"
    t.integer "home_score"
    t.bigint "home_team_id", null: false
    t.text "raw_log"
    t.date "real_date"
    t.jsonb "roster_data", default: {}, null: false
    t.string "setting_date"
    t.string "source", default: "live", null: false
    t.bigint "stadium_id"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.integer "visitor_game_number"
    t.string "visitor_schedule_date"
    t.integer "visitor_score"
    t.bigint "visitor_team_id", null: false
    t.index [ "competition_id" ], name: "index_games_on_competition_id"
    t.index [ "home_team_id", "visitor_team_id", "real_date" ], name: "index_games_on_home_team_id_and_visitor_team_id_and_real_date"
    t.index [ "home_team_id" ], name: "index_games_on_home_team_id"
    t.index [ "stadium_id" ], name: "index_games_on_stadium_id"
    t.index [ "status" ], name: "index_games_on_status"
    t.index [ "visitor_team_id" ], name: "index_games_on_visitor_team_id"
  end

  create_table "imported_stats", force: :cascade do |t|
    t.string "as_of_date"
    t.integer "as_of_game_number"
    t.bigint "competition_id", null: false
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.string "stat_type", null: false
    t.jsonb "stats", default: {}, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_id" ], name: "index_imported_stats_on_competition_id"
    t.index [ "player_id", "competition_id", "stat_type" ], name: "idx_on_player_id_competition_id_stat_type_0f5a1c1e93", unique: true
    t.index [ "player_id" ], name: "index_imported_stats_on_player_id"
    t.index [ "team_id" ], name: "index_imported_stats_on_team_id"
  end

  create_table "league_games", force: :cascade do |t|
    t.bigint "away_team_id", null: false
    t.datetime "created_at", null: false
    t.date "game_date", null: false
    t.integer "game_number", null: false
    t.bigint "home_team_id", null: false
    t.bigint "league_season_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "away_team_id" ], name: "index_league_games_on_away_team_id"
    t.index [ "home_team_id" ], name: "index_league_games_on_home_team_id"
    t.index [ "league_season_id" ], name: "index_league_games_on_league_season_id"
  end

  create_table "league_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "league_id", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "league_id", "team_id" ], name: "index_league_memberships_on_league_id_and_team_id", unique: true
    t.index [ "league_id" ], name: "index_league_memberships_on_league_id"
    t.index [ "team_id" ], name: "index_league_memberships_on_team_id"
  end

  create_table "league_pool_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "league_season_id", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "league_season_id" ], name: "index_league_pool_players_on_league_season_id"
    t.index [ "player_id" ], name: "index_league_pool_players_on_player_id"
  end

  create_table "league_seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.bigint "league_id", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index [ "league_id" ], name: "index_league_seasons_on_league_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "num_games", default: 30, null: false
    t.integer "num_teams", default: 6, null: false
    t.datetime "updated_at", null: false
  end

  create_table "managers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "irc_name"
    t.string "name"
    t.integer "role", default: 0, null: false
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.string "user_id"
  end

  create_table "pitcher_game_states", force: :cascade do |t|
    t.bigint "competition_id", null: false
    t.datetime "created_at", null: false
    t.integer "cumulative_innings", default: 0
    t.string "decision"
    t.integer "earned_runs", default: 0, null: false
    t.integer "fatigue_p_used", default: 0
    t.bigint "game_id", null: false
    t.string "injury_check"
    t.decimal "innings_pitched", precision: 5, scale: 1
    t.bigint "pitcher_id", null: false
    t.string "result_category"
    t.string "role", null: false
    t.string "schedule_date"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "competition_id" ], name: "index_pitcher_game_states_on_competition_id"
    t.index [ "decision" ], name: "index_pitcher_game_states_on_decision"
    t.index [ "game_id", "pitcher_id" ], name: "index_pitcher_game_states_on_game_id_and_pitcher_id", unique: true
    t.index [ "game_id" ], name: "index_pitcher_game_states_on_game_id"
    t.index [ "pitcher_id" ], name: "index_pitcher_game_states_on_pitcher_id"
    t.index [ "team_id" ], name: "index_pitcher_game_states_on_team_id"
  end

  create_table "pitching_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "skill_type"
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_pitching_skills_on_name", unique: true
  end

  create_table "pitching_styles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_pitching_styles_on_name", unique: true
  end

  create_table "player_absences", force: :cascade do |t|
    t.integer "absence_type", null: false
    t.datetime "created_at", null: false
    t.integer "duration", null: false
    t.string "duration_unit", null: false
    t.text "reason"
    t.bigint "season_id", null: false
    t.date "start_date", null: false
    t.bigint "team_membership_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "season_id" ], name: "index_player_absences_on_season_id"
    t.index [ "team_membership_id" ], name: "index_player_absences_on_team_membership_id"
  end

  create_table "player_batting_skills", force: :cascade do |t|
    t.bigint "batting_skill_id", null: false
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "batting_skill_id" ], name: "index_player_batting_skills_on_batting_skill_id"
    t.index [ "player_id", "batting_skill_id" ], name: "index_player_batting_skills_on_player_id_and_batting_skill_id", unique: true
    t.index [ "player_id" ], name: "index_player_batting_skills_on_player_id"
  end

  create_table "player_biorhythms", force: :cascade do |t|
    t.bigint "biorhythm_id", null: false
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "biorhythm_id" ], name: "index_player_biorhythms_on_biorhythm_id"
    t.index [ "player_id", "biorhythm_id" ], name: "index_player_biorhythms_on_player_id_and_biorhythm_id", unique: true
    t.index [ "player_id" ], name: "index_player_biorhythms_on_player_id"
  end

  create_table "player_card_abilities", force: :cascade do |t|
    t.bigint "ability_definition_id", null: false
    t.bigint "condition_id"
    t.datetime "created_at", null: false
    t.bigint "player_card_id", null: false
    t.string "role"
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index [ "ability_definition_id" ], name: "index_player_card_abilities_on_ability_definition_id"
    t.index [ "condition_id" ], name: "index_player_card_abilities_on_condition_id"
    t.index [ "player_card_id" ], name: "index_player_card_abilities_on_player_card_id"
  end

  create_table "player_card_defenses", force: :cascade do |t|
    t.bigint "condition_id"
    t.datetime "created_at", null: false
    t.string "error_rank", null: false
    t.bigint "player_card_id", null: false
    t.string "position", null: false
    t.integer "range_value", null: false
    t.string "throwing"
    t.datetime "updated_at", null: false
    t.index [ "condition_id" ], name: "index_player_card_defenses_on_condition_id"
    t.index [ "player_card_id", "position", "condition_id" ], name: "index_player_card_defenses_on_card_position_condition", unique: true
    t.index [ "player_card_id" ], name: "index_player_card_defenses_on_player_card_id"
  end

  create_table "player_card_exclusive_catchers", primary_key: [ "player_card_id", "catcher_player_id" ], force: :cascade do |t|
    t.bigint "catcher_player_id", null: false
    t.bigint "player_card_id", null: false
  end

  create_table "player_card_player_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_card_id", null: false
    t.bigint "player_type_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "player_card_id", "player_type_id" ], name: "idx_on_player_card_id_player_type_id_81367eec7c", unique: true
    t.index [ "player_card_id" ], name: "index_player_card_player_types_on_player_card_id"
    t.index [ "player_type_id" ], name: "index_player_card_player_types_on_player_type_id"
  end

  create_table "player_card_traits", force: :cascade do |t|
    t.bigint "condition_id"
    t.datetime "created_at", null: false
    t.bigint "player_card_id", null: false
    t.string "role"
    t.integer "sort_order", default: 0
    t.bigint "trait_definition_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "condition_id" ], name: "index_player_card_traits_on_condition_id"
    t.index [ "player_card_id" ], name: "index_player_card_traits_on_player_card_id"
    t.index [ "trait_definition_id" ], name: "index_player_card_traits_on_trait_definition_id"
  end

  create_table "player_cards", force: :cascade do |t|
    t.jsonb "abilities", default: {}, null: false
    t.string "batting_style_description"
    t.bigint "batting_style_id"
    t.jsonb "batting_table", default: {}, null: false
    t.jsonb "biorhythm_date_ranges"
    t.string "biorhythm_period"
    t.integer "bunt"
    t.string "card_image_path"
    t.string "card_label"
    t.bigint "card_set_id", null: false
    t.string "card_type", null: false
    t.bigint "catcher_pitching_style_id"
    t.datetime "created_at", null: false
    t.string "handedness"
    t.integer "injury_rate"
    t.jsonb "injury_traits"
    t.string "irc_display_name"
    t.string "irc_macro_name"
    t.boolean "is_closer", default: false, null: false
    t.boolean "is_dual_wielder", default: false, null: false
    t.boolean "is_pitcher", default: false
    t.boolean "is_relief_only", default: false
    t.boolean "is_switch_hitter", default: false, null: false
    t.bigint "pinch_pitching_style_id"
    t.string "pitching_style_description"
    t.bigint "pitching_style_id"
    t.jsonb "pitching_table", default: {}, null: false
    t.bigint "player_id", null: false
    t.integer "relief_stamina"
    t.string "special_defense_c"
    t.integer "special_throwing_c"
    t.integer "speed"
    t.integer "starter_stamina"
    t.integer "steal_end"
    t.integer "steal_start"
    t.text "unique_traits"
    t.datetime "updated_at", null: false
    t.index [ "batting_style_id" ], name: "index_player_cards_on_batting_style_id"
    t.index [ "card_set_id", "player_id", "card_type" ], name: "index_player_cards_on_card_set_player_card_type", unique: true
    t.index [ "card_set_id" ], name: "index_player_cards_on_card_set_id"
    t.index [ "catcher_pitching_style_id" ], name: "index_player_cards_on_catcher_pitching_style_id"
    t.index [ "pinch_pitching_style_id" ], name: "index_player_cards_on_pinch_pitching_style_id"
    t.index [ "pitching_style_id" ], name: "index_player_cards_on_pitching_style_id"
    t.index [ "player_id" ], name: "index_player_cards_on_player_id"
  end

  create_table "player_pitching_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "pitching_skill_id", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "pitching_skill_id" ], name: "index_player_pitching_skills_on_pitching_skill_id"
    t.index [ "player_id", "pitching_skill_id" ], name: "idx_on_player_id_pitching_skill_id_bd496ce465", unique: true
    t.index [ "player_id" ], name: "index_player_pitching_skills_on_player_id"
  end

  create_table "player_player_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.bigint "player_type_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "player_id", "player_type_id" ], name: "index_player_player_types_on_player_id_and_player_type_id", unique: true
    t.index [ "player_id" ], name: "index_player_player_types_on_player_id"
    t.index [ "player_type_id" ], name: "index_player_player_types_on_player_type_id"
  end

  create_table "player_types", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_player_types_on_name", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.string "batting_hand"
    t.string "batting_style_description"
    t.bigint "batting_style_id"
    t.integer "bunt"
    t.bigint "catcher_pitching_style_id"
    t.datetime "created_at", null: false
    t.string "defense_1b"
    t.string "defense_2b"
    t.string "defense_3b"
    t.string "defense_c"
    t.string "defense_cf"
    t.string "defense_lf"
    t.string "defense_of"
    t.string "defense_p"
    t.string "defense_rf"
    t.string "defense_ss"
    t.integer "injury_rate"
    t.boolean "is_pitcher", default: false
    t.boolean "is_relief_only", default: false
    t.string "name", null: false
    t.string "number", null: false
    t.bigint "pinch_pitching_style_id"
    t.string "pitching_style_description"
    t.bigint "pitching_style_id"
    t.string "position"
    t.integer "relief_stamina"
    t.string "short_name"
    t.string "special_defense_c"
    t.integer "special_throwing_c"
    t.integer "speed"
    t.integer "starter_stamina"
    t.integer "steal_end"
    t.integer "steal_start"
    t.integer "throwing_c"
    t.string "throwing_cf"
    t.string "throwing_hand"
    t.string "throwing_lf"
    t.string "throwing_of"
    t.string "throwing_rf"
    t.datetime "updated_at", null: false
    t.index [ "batting_style_id" ], name: "index_players_on_batting_style_id"
    t.index [ "catcher_pitching_style_id" ], name: "index_players_on_catcher_pitching_style_id"
    t.index [ "pinch_pitching_style_id" ], name: "index_players_on_pinch_pitching_style_id"
    t.index [ "pitching_style_id" ], name: "index_players_on_pitching_style_id"
  end

  create_table "schedule_details", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.string "date_type"
    t.integer "priority"
    t.bigint "schedule_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "schedule_id", "date" ], name: "index_schedule_details_on_schedule_id_and_date", unique: true
    t.index [ "schedule_id" ], name: "index_schedule_details_on_schedule_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "effective_date"
    t.date "end_date"
    t.string "name"
    t.date "start_date"
    t.datetime "updated_at", null: false
  end

  create_table "season_rosters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "registered_on", null: false
    t.bigint "season_id", null: false
    t.string "squad", null: false
    t.bigint "team_membership_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "season_id" ], name: "index_season_rosters_on_season_id"
    t.index [ "team_membership_id" ], name: "index_season_rosters_on_team_membership_id"
  end

  create_table "season_schedules", force: :cascade do |t|
    t.bigint "announced_starter_id"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "date_type"
    t.boolean "designated_hitter_enabled"
    t.integer "game_number"
    t.string "home_away"
    t.bigint "losing_pitcher_id"
    t.integer "opponent_score"
    t.jsonb "opponent_starting_lineup"
    t.bigint "opponent_team_id"
    t.bigint "save_pitcher_id"
    t.integer "score"
    t.jsonb "scoreboard"
    t.bigint "season_id", null: false
    t.string "stadium"
    t.jsonb "starting_lineup"
    t.datetime "updated_at", null: false
    t.bigint "winning_pitcher_id"
    t.index [ "announced_starter_id" ], name: "index_season_schedules_on_announced_starter_id"
    t.index [ "losing_pitcher_id" ], name: "index_season_schedules_on_losing_pitcher_id"
    t.index [ "opponent_team_id" ], name: "index_season_schedules_on_opponent_team_id"
    t.index [ "save_pitcher_id" ], name: "index_season_schedules_on_save_pitcher_id"
    t.index [ "season_id" ], name: "index_season_schedules_on_season_id"
    t.index [ "winning_pitcher_id" ], name: "index_season_schedules_on_winning_pitcher_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "current_date", null: false
    t.bigint "key_player_id"
    t.string "name", null: false
    t.bigint "team_id", null: false
    t.string "team_type"
    t.datetime "updated_at", null: false
    t.index [ "key_player_id" ], name: "index_seasons_on_key_player_id"
    t.index [ "team_id" ], name: "index_seasons_on_team_id"
  end

  create_table "stadiums", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "indoor", default: false, null: false
    t.string "name", null: false
    t.jsonb "up_table_ids", default: [], null: false
    t.datetime "updated_at", null: false
    t.index [ "code" ], name: "index_stadiums_on_code", unique: true
    t.index [ "name" ], name: "index_stadiums_on_name", unique: true
  end

  create_table "team_managers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "manager_id", null: false
    t.integer "role", default: 0, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "manager_id" ], name: "index_team_managers_on_manager_id"
    t.index [ "team_id" ], name: "index_team_managers_on_team_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.boolean "excluded_from_team_total", default: false, null: false
    t.bigint "player_id", null: false
    t.string "selected_cost_type", default: "normal_cost", null: false
    t.string "squad", default: "second", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "player_id" ], name: "index_team_memberships_on_player_id"
    t.index [ "team_id", "player_id" ], name: "index_team_memberships_on_team_id_and_player_id", unique: true
    t.index [ "team_id" ], name: "index_team_memberships_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true
    t.string "name"
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
  end

  create_table "trait_conditions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_trait_conditions_on_name", unique: true
  end

  create_table "trait_definitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "typical_role"
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_trait_definitions_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "name"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "at_bat_records", "game_records"
  add_foreign_key "at_bats", "games"
  add_foreign_key "at_bats", "players", column: "batter_id"
  add_foreign_key "at_bats", "players", column: "pinch_hit_for_id"
  add_foreign_key "at_bats", "players", column: "pitcher_id"
  add_foreign_key "catchers_players", "players"
  add_foreign_key "catchers_players", "players", column: "catcher_id"
  add_foreign_key "competition_entries", "competitions"
  add_foreign_key "competition_entries", "teams"
  add_foreign_key "competition_entries", "teams", column: "base_team_id"
  add_foreign_key "competition_rosters", "competition_entries"
  add_foreign_key "competition_rosters", "player_cards"
  add_foreign_key "cost_players", "costs"
  add_foreign_key "cost_players", "players"
  add_foreign_key "game_events", "games"
  add_foreign_key "game_records", "games", on_delete: :nullify
  add_foreign_key "game_records", "teams"
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
  add_foreign_key "player_card_abilities", "ability_definitions"
  add_foreign_key "player_card_abilities", "player_cards"
  add_foreign_key "player_card_abilities", "trait_conditions", column: "condition_id"
  add_foreign_key "player_card_defenses", "player_cards"
  add_foreign_key "player_card_defenses", "trait_conditions", column: "condition_id"
  add_foreign_key "player_card_exclusive_catchers", "player_cards"
  add_foreign_key "player_card_exclusive_catchers", "players", column: "catcher_player_id"
  add_foreign_key "player_card_player_types", "player_cards"
  add_foreign_key "player_card_player_types", "player_types"
  add_foreign_key "player_card_traits", "player_cards"
  add_foreign_key "player_card_traits", "trait_conditions", column: "condition_id"
  add_foreign_key "player_card_traits", "trait_definitions"
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
