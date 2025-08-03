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

ActiveRecord::Schema[8.0].define(version: 2025_08_02_102059) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "batting_skills", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "skill_type", default: "neutral", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_batting_skills_on_name", unique: true
  end

  create_table "batting_styles", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "biorhythms", force: :cascade do |t|
    t.string "name", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_biorhythms_on_name", unique: true
  end

  create_table "catchers_players", id: false, force: :cascade do |t|
    t.bigint "player_id"
    t.bigint "catcher_id"
    t.index ["catcher_id"], name: "index_catchers_players_on_catcher_id"
    t.index ["player_id", "catcher_id"], name: "index_catchers_players_on_player_id_and_catcher_id", unique: true
    t.index ["player_id"], name: "index_catchers_players_on_player_id"
  end

  create_table "managers", force: :cascade do |t|
    t.string "name"
    t.string "short_name"
    t.string "irc_name"
    t.string "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pitching_skills", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "skill_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_pitching_skills_on_name", unique: true
  end

  create_table "pitching_styles", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "player_batting_skills", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "batting_skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batting_skill_id"], name: "index_player_batting_skills_on_batting_skill_id"
    t.index ["player_id", "batting_skill_id"], name: "index_player_batting_skills_on_player_id_and_batting_skill_id", unique: true
    t.index ["player_id"], name: "index_player_batting_skills_on_player_id"
  end

  create_table "player_biorhythms", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "biorhythm_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["biorhythm_id"], name: "index_player_biorhythms_on_biorhythm_id"
    t.index ["player_id", "biorhythm_id"], name: "index_player_biorhythms_on_player_id_and_biorhythm_id", unique: true
    t.index ["player_id"], name: "index_player_biorhythms_on_player_id"
  end

  create_table "player_pitching_skills", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "pitching_skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pitching_skill_id"], name: "index_player_pitching_skills_on_pitching_skill_id"
    t.index ["player_id", "pitching_skill_id"], name: "idx_on_player_id_pitching_skill_id_bd496ce465", unique: true
    t.index ["player_id"], name: "index_player_pitching_skills_on_player_id"
  end

  create_table "player_player_types", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "player_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "player_type_id"], name: "index_player_player_types_on_player_id_and_player_type_id", unique: true
    t.index ["player_id"], name: "index_player_player_types_on_player_id"
    t.index ["player_type_id"], name: "index_player_player_types_on_player_type_id"
  end

  create_table "player_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_player_types_on_name", unique: true
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
    t.index ["batting_style_id"], name: "index_players_on_batting_style_id"
    t.index ["catcher_pitching_style_id"], name: "index_players_on_catcher_pitching_style_id"
    t.index ["pinch_pitching_style_id"], name: "index_players_on_pinch_pitching_style_id"
    t.index ["pitching_style_id"], name: "index_players_on_pitching_style_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "short_name"
    t.boolean "is_active", default: true
    t.bigint "manager_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["manager_id"], name: "index_teams_on_manager_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "display_name"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "catchers_players", "players"
  add_foreign_key "catchers_players", "players", column: "catcher_id"
  add_foreign_key "player_batting_skills", "batting_skills"
  add_foreign_key "player_batting_skills", "players"
  add_foreign_key "player_biorhythms", "biorhythms"
  add_foreign_key "player_biorhythms", "players"
  add_foreign_key "player_pitching_skills", "pitching_skills"
  add_foreign_key "player_pitching_skills", "players"
  add_foreign_key "player_player_types", "player_types"
  add_foreign_key "player_player_types", "players"
  add_foreign_key "players", "batting_styles"
  add_foreign_key "players", "pitching_styles"
  add_foreign_key "players", "pitching_styles", column: "catcher_pitching_style_id"
  add_foreign_key "players", "pitching_styles", column: "pinch_pitching_style_id"
  add_foreign_key "teams", "managers"
end
