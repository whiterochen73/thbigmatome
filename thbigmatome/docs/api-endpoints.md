# API エンドポイント仕様

最終更新日: 2026-03-21

## 参照ソースファイル

- `config/routes.rb`
- `config/game_rules.yaml` — ゲームルール正本（バリデーション値の照合に使用）
- `app/controllers/api/v1/base_controller.rb`
- `app/controllers/api/v1/auth_controller.rb`
- `app/controllers/api/v1/teams_controller.rb`
- `app/controllers/api/v1/team_seasons_controller.rb`
- `app/controllers/api/v1/team_rosters_controller.rb`
- `app/controllers/api/v1/team_players_controller.rb`
- `app/controllers/api/v1/team_memberships_controller.rb`
- `app/controllers/api/v1/team_key_players_controller.rb`
- `app/controllers/api/v1/lineup_templates_controller.rb`
- `app/controllers/api/v1/game_lineups_controller.rb`
- `app/controllers/api/v1/squad_text_settings_controller.rb`
- `app/controllers/api/v1/roster_changes_controller.rb`
- `app/controllers/api/v1/game_controller.rb`
- `app/controllers/api/v1/games_controller.rb`
- `app/controllers/api/v1/game_lineup_entries_controller.rb`
- `app/controllers/api/v1/game_records_controller.rb`
- `app/controllers/api/v1/at_bat_records_controller.rb`
- `app/controllers/api/v1/players_controller.rb`
- `app/controllers/api/v1/player_cards_controller.rb`
- `app/controllers/api/v1/team_registration_players_controller.rb`
- `app/controllers/api/v1/card_sets_controller.rb`
- `app/controllers/api/v1/player_types_controller.rb`
- `app/controllers/api/v1/pitching_styles_controller.rb`
- `app/controllers/api/v1/batting_styles_controller.rb`
- `app/controllers/api/v1/biorhythms_controller.rb`
- `app/controllers/api/v1/costs_controller.rb`
- `app/controllers/api/v1/cost_assignments_controller.rb`
- `app/controllers/api/v1/seasons_controller.rb`
- `app/controllers/api/v1/player_absences_controller.rb`
- `app/controllers/api/v1/schedules_controller.rb`
- `app/controllers/api/v1/schedule_details_controller.rb`
- `app/controllers/api/v1/competitions_controller.rb`
- `app/controllers/api/v1/competition_rosters_controller.rb`
- `app/controllers/api/v1/managers_controller.rb`
- `app/controllers/api/v1/stadiums_controller.rb`
- `app/controllers/api/v1/home_controller.rb`
- `app/controllers/api/v1/stats_controller.rb`
- `app/controllers/api/v1/users_controller.rb`

---

## 認証・共通仕様

- **BaseController**: `Api::V1::BaseController < ApplicationController`
- **認証**: `before_action :authenticate_user!` — 全エンドポイントに適用（ログイン・ログアウトを除く）
- **レスポンス形式**: JSON
- **Commissionerロール必須**: `authorize_commissioner!` を呼ぶアクション（competitions#create/update/destroy, stadiums#create/update, users#index/create/reset_password）

---

## ヘルスチェック

| Method | Path | Controller#Action | 認証 |
|--------|------|-------------------|------|
| GET    | `/up` | `rails/health#show` | 不要 |

---

## 認証 (Auth)

### POST /api/v1/auth/login

- **Controller**: `Api::V1::AuthController#login`
- **認証**: 不要
- **Body Params**: `name` (string), `password` (string)
- **Response**: `{ user: { id, name }, message: "ログイン成功" }` / `{ error: "..." }` 401

### POST /api/v1/auth/logout

- **Controller**: `Api::V1::AuthController#logout`
- **認証**: 不要
- **Response**: `{ message: "ログアウトしました" }`

### GET /api/v1/auth/current_user

- **Controller**: `Api::V1::AuthController#show_current_user`
- **認証**: 必要
- **Response**: `{ user: { id, name, role } }` / `{ error: "..." }` 401

---

## 監督 (Managers)

### GET /api/v1/managers

- **Controller**: `Api::V1::ManagersController#index`
- **Query Params**: `page` (integer, default: 1), `per_page` (integer, default: 25, max: 100)
- **Response**: `{ data: [...managers with teams], meta: { total_count, per_page, current_page, total_pages } }`
- **ページネーション**: 手動実装（Kaminari不使用）

### GET /api/v1/managers/:id

- **Controller**: `Api::V1::ManagersController#show`
- **Response**: manager JSON with teams included

### POST /api/v1/managers

- **Controller**: `Api::V1::ManagersController#create`
- **Body Params**: `manager: { name, short_name, irc_name, user_id }`
- **Response**: manager JSON 201

### PATCH/PUT /api/v1/managers/:id

- **Controller**: `Api::V1::ManagersController#update`
- **Body Params**: `manager: { name, short_name, irc_name, user_id }`
- **Response**: manager JSON

### DELETE /api/v1/managers/:id

- **Controller**: `Api::V1::ManagersController#destroy`
- **Response**: 204 No Content

---

## チーム (Teams)

### GET /api/v1/teams

- **Controller**: `Api::V1::TeamsController#index`
- **Response**: `[...TeamSerializer]` (preloads director, coaches)

### GET /api/v1/teams/:id

- **Controller**: `Api::V1::TeamsController#show`
- **Response**: `TeamSerializer`

### POST /api/v1/teams

- **Controller**: `Api::V1::TeamsController#create`
- **Body Params**: `team: { name, short_name, is_active, director_id, coach_ids: [] }`
- **Response**: `TeamSerializer` 201

### PATCH/PUT /api/v1/teams/:id

- **Controller**: `Api::V1::TeamsController#update`
- **Body Params**: `team: { name, short_name, is_active, director_id, coach_ids: [] }`
- **Response**: `TeamSerializer`

### DELETE /api/v1/teams/:id

- **Controller**: `Api::V1::TeamsController#destroy`
- **Response**: 204 No Content

---

## チームシーズン (Team Seasons)

### GET /api/v1/teams/:team_id/season

- **Controller**: `Api::V1::TeamSeasonsController#show`
- **Response**: `SeasonDetailSerializer`

### PATCH/PUT /api/v1/teams/:team_id/season

- **Controller**: `Api::V1::TeamSeasonsController#update`
- **Body Params**: `season: { current_date }`
- **Response**: `{ season: ... }`

### PATCH /api/v1/teams/:team_id/season/season_schedules/:id

- **Controller**: `Api::V1::TeamSeasonsController#update_season_schedule`
- **Path Params**: `:id` (SeasonSchedule ID)
- **Body Params**: `season_schedule: { date_type }`
- **Response**: SeasonSchedule JSON

---

## チームロスター (Team Rosters)

### GET /api/v1/teams/:team_id/roster

- **Controller**: `Api::V1::TeamRostersController#show`
- **Response**:
  ```json
  {
    "season_id": int,
    "current_date": date,
    "season_start_date": date,
    "key_player_id": int|null,
    "previous_game_date": date|null,
    "roster": [
      {
        "team_membership_id": int,
        "player_id": int,
        "number": string,
        "player_name": string,
        "handedness": string|null,
        "squad": "first"|"second",
        "player_types": [],
        "selected_cost_type": string,
        "cost": int,
        "cooldown_until": date|null,
        "same_day_exempt": boolean,
        "is_outside_world": boolean,
        "is_starter_pitcher": boolean,
        "is_relief_only": boolean,
        "is_absent": boolean,
        "absence_info": object|null
      }
    ]
  }
  ```

### POST /api/v1/teams/:team_id/roster

- **Controller**: `Api::V1::TeamRostersController#create`
- **Body Params**:
  - `roster_updates`: `[{ team_membership_id: int, squad: "first"|"second" }]`
  - `target_date`: date string
- **バリデーション**: 1軍人数上限(29)、最小人数（game_rules.yaml#team_composition.first_squad_minimum_players）、コスト上限（game_rules.yaml#team_composition.team_total_max_cost: 200）、クールダウン(10日: game_rules.yaml#season.cooldown_days)、再調整中選手の昇格禁止
- **Response**: `{ message: "Roster updated successfully", warnings: [] }`

---

## キープレイヤー (Team Key Players)

### POST /api/v1/teams/:team_id/key_player

- **Controller**: `Api::V1::TeamKeyPlayersController#create`
- **Body Params**: `key_player_id` (integer|null)
- **制約**: シーズン初日のみ設定可能
- **Response**: `{ message: "Key player set successfully" }`

---

## チーム選手 (Team Players)

### GET /api/v1/teams/:team_id/team_players

- **Controller**: `Api::V1::TeamPlayersController#index`
- **Query Params**: `cost_list_id` (integer, optional)
- **Response**: `[...TeamPlayerSerializer]`

### POST /api/v1/teams/:team_id/team_players

- **Controller**: `Api::V1::TeamPlayersController#create`
- **Body Params**:
  - `players`: `[{ player_id, selected_cost_type, excluded_from_team_total, display_name }]`
  - `cost_list_id`: integer (optional, チーム合計コスト検証用)
- **挙動**: 既存メンバーシップをupsert、リストにないプレイヤーを削除
- **Response**: `{ message: "Team members updated successfully" }`

---

## チームメンバーシップ (Team Memberships)

### GET /api/v1/teams/:team_id/team_memberships

- **Controller**: `Api::V1::TeamMembershipsController#index`
- **Response**: `[{ id, name: "#{number} #{name}", player_id }]`

---

## オーダーテンプレート (Lineup Templates)

### GET /api/v1/teams/:team_id/lineup_templates

- **Controller**: `Api::V1::LineupTemplatesController#index`
- **Response**: `[{ id, dh_enabled, opponent_pitcher_hand, entries: [...] }]`

### GET /api/v1/teams/:team_id/lineup_templates/:id

- **Controller**: `Api::V1::LineupTemplatesController#show`
- **Response**: `{ id, dh_enabled, opponent_pitcher_hand, entries: [{ id, batting_order, player_id, position, player_name, player_number }] }`

### POST /api/v1/teams/:team_id/lineup_templates

- **Controller**: `Api::V1::LineupTemplatesController#create`
- **Body Params**: `lineup_template: { dh_enabled, opponent_pitcher_hand, entries_attributes: [{ batting_order, player_id, position }] }`
- **Response**: テンプレートJSON 201

### PUT /api/v1/teams/:team_id/lineup_templates/:id

- **Controller**: `Api::V1::LineupTemplatesController#update`
- **Body Params**: `lineup_template: { dh_enabled, opponent_pitcher_hand, entries_attributes: [{ batting_order, player_id, position }] }`
- **Response**: テンプレートJSON

### DELETE /api/v1/teams/:team_id/lineup_templates/:id

- **Controller**: `Api::V1::LineupTemplatesController#destroy`
- **Response**: 204 No Content

---

## 試合オーダー (Game Lineup)

### GET /api/v1/teams/:team_id/game_lineup

- **Controller**: `Api::V1::GameLineupsController#show`
- **Response**: `{ id, lineup_data: {...}, updated_at }`

### PUT /api/v1/teams/:team_id/game_lineup

- **Controller**: `Api::V1::GameLineupsController#update`
- **Body Params**: `game_lineup: { lineup_data: {...} }`
- **Response**: `{ id, lineup_data: {...}, updated_at }`

---

## スカッドテキスト設定 (Squad Text Settings)

### GET /api/v1/teams/:team_id/squad_text_settings

- **Controller**: `Api::V1::SquadTextSettingsController#show`
- **挙動**: 存在しない場合はデフォルト値で新規作成して返す
- **Response**: `{ id, team_id, position_format, handedness_format, date_format, section_header_format, show_number_prefix, batting_stats_config, pitching_stats_config, updated_at }`

### PUT /api/v1/teams/:team_id/squad_text_settings

- **Controller**: `Api::V1::SquadTextSettingsController#update`
- **Body Params**: `squad_text_setting: { position_format, handedness_format, date_format, section_header_format, show_number_prefix, batting_stats_config: {}, pitching_stats_config: {} }`
- **Response**: 設定JSON

---

## 公示変更 (Roster Changes)

### GET /api/v1/teams/:team_id/roster_changes

- **Controller**: `Api::V1::RosterChangesController#index`
- **Query Params**: `since` (date, 必須), `season_id` (integer, 必須)
- **Response**: `RosterChangeService` の返り値（公示テキスト用変更差分）

---

## 試合スケジュール詳細 (Game / SeasonSchedule)

### GET /api/v1/game/:id

- **Controller**: `Api::V1::GameController#show`
- **Path Params**: `:id` (SeasonSchedule ID)
- **Response**: `{ team_id, team_name, season_id, game_date, game_number, announced_starter_id, stadium, home_away, designated_hitter_enabled, score, opponent_score, opponent_team_id, opponent_team, winning_pitcher_id, losing_pitcher_id, save_pitcher_id, scoreboard, starting_lineup, opponent_starting_lineup, game_result }`

### PATCH/PUT /api/v1/game/:id

- **Controller**: `Api::V1::GameController#update`
- **Path Params**: `:id` (SeasonSchedule ID)
- **Body Params**: `announced_starter_id, stadium, home_away, designated_hitter_enabled, score, opponent_score, opponent_team_id, winning_pitcher_id, losing_pitcher_id, save_pitcher_id, scoreboard: { home: [], away: [] }, starting_lineup: [{ player_id, position, order }], opponent_starting_lineup: [...]`
- **Response**: SeasonSchedule JSON

---

## 試合 (Games)

### GET /api/v1/games

- **Controller**: `Api::V1::GamesController#index`
- **Query Params**: `competition_id` (integer, optional), `from` (date), `to` (date)
- **Response**: `[...GameSerializer]` (ordered by id desc)

### GET /api/v1/games/:id

- **Controller**: `Api::V1::GamesController#show`
- **Response**: `GameSerializer` (includes at_bats)

### POST /api/v1/games

- **Controller**: `Api::V1::GamesController#create`
- **Body Params**: `game: { competition_id, home_team_id, visitor_team_id, real_date, stadium_id, status, source }`
- **Response**: `GameSerializer` 201

### POST /api/v1/games/import_log

- **Controller**: `Api::V1::GamesController#import_log`
- **Body Params**: `log` (string), `raw_at_bats` (string JSON, optional), `competition_id`, `home_team_id`, `visitor_team_id`, `real_date`, `stadium_id`
- **挙動**: ゲームログをパース → draft Game + AtBat + GameRecord + AtBatRecord を作成
- **Response**: `{ game: GameSerializer, game_record_id, parsed_at_bats: { at_bats: [...], innings }, at_bat_count, imported_count }` 201

### POST /api/v1/games/parse_log

- **Controller**: `Api::V1::GamesController#parse_log`
- **Body Params**: `log` (string)
- **挙動**: ログをパースして結果を返すのみ（DB変更なし）
- **Response**: `{ pregame_info, parsed_at_bats: { at_bats: [...], innings }, at_bat_count, raw_at_bats }`

### POST /api/v1/games/:id/confirm

- **Controller**: `Api::V1::GamesController#confirm`
- **挙動**: draft → confirmed ステータス変更、配下AtBatsも confirmed に
- **Response**: `{ game: GameSerializer, confirmed_count }`

---

## 試合オーダーエントリ (Game Lineup Entries)

### GET /api/v1/games/:game_id/lineup

- **Controller**: `Api::V1::GameLineupEntriesController#show`
- **Response**: `{ lineup: [...GameLineupEntrySerializer] }`

### POST /api/v1/games/:game_id/lineup

- **Controller**: `Api::V1::GameLineupEntriesController#create`
- **Body Params**: `lineup: [{ player_card_id, role, batting_order, position, is_dh_pitcher, is_reliever }]`
- **挙動**: 既存エントリを全削除して再作成
- **Response**: `{ lineup: [...GameLineupEntrySerializer] }` 201

### PUT /api/v1/games/:game_id/lineup

- **Controller**: `Api::V1::GameLineupEntriesController#update`
- **Body Params**: POST と同じ
- **挙動**: 既存エントリを全削除して再作成
- **Response**: `{ lineup: [...GameLineupEntrySerializer] }`

---

## 試合記録 (Game Records)

### GET /api/v1/game_records

- **Controller**: `Api::V1::GameRecordsController#index`
- **Query Params**: `team_id` (integer), `status` (string), `game_date_from` (date), `game_date_to` (date), `page` (integer, default: 1), `per_page` (integer, default: 20, max: 100)
- **Response**:
  ```json
  {
    "game_records": [...],
    "pagination": { "page", "per_page", "total", "total_pages" }
  }
  ```

### GET /api/v1/game_records/:id

- **Controller**: `Api::V1::GameRecordsController#show`
- **Response**: game_record JSON with at_bat_records included

### POST /api/v1/game_records

- **Controller**: `Api::V1::GameRecordsController#create`
- **Body Params**: `team_id, opponent_team_name, game_date, played_at, stadium, score_home, score_away, result, source_log, parser_version, parsed_at` + `at_bat_records: [...]`
- **Response**: game_record JSON with at_bat_records 201

### POST /api/v1/game_records/:id/confirm

- **Controller**: `Api::V1::GameRecordsController#confirm`
- **挙動**: draft → confirmed、全AtBatRecordをis_reviewed=true、打撃・投球成績を計算・保存
- **Response**: game_record JSON

---

## 打席記録 (At Bat Records)

### PATCH /api/v1/at_bat_records/:id

- **Controller**: `Api::V1::AtBatRecordsController#update`
- **Body Params**: `result_code, runs_scored, outs_before, outs_after, pitcher_name, pitcher_id, batter_name, batter_id, pitch_roll, pitch_result, bat_roll, bat_result, strategy, play_description, is_reviewed, review_notes, runners_before: [], runners_after: [], extra_data: {}`
- **挙動**: is_modified=true、modified_fieldsに差分記録、discrepanciesにresolution追加、adopted_value更新、後続レコードgsm_value再計算
- **Response**: at_bat_record JSON

---

## 選手 (Players)

### GET /api/v1/players

- **Controller**: `Api::V1::PlayersController#index`
- **Response**: `[...PlayerDetailSerializer]` (includes player_cards with card_set)

### GET /api/v1/players/:id

- **Controller**: `Api::V1::PlayersController#show`
- **Response**: `PlayerDetailSerializer`

### POST /api/v1/players

- **Controller**: `Api::V1::PlayersController#create`
- **Body Params**: `player: { name, number, short_name }`
- **Response**: player JSON 201

### PATCH/PUT /api/v1/players/:id

- **Controller**: `Api::V1::PlayersController#update`
- **Body Params**: `player: { name, number, short_name }`
- **Response**: player JSON

### DELETE /api/v1/players/:id

- **Controller**: `Api::V1::PlayersController#destroy`
- **Response**: 204 No Content

---

## 登録選手一覧 (Team Registration Players)

### GET /api/v1/team_registration_players

- **Controller**: `Api::V1::TeamRegistrationPlayersController#index`
- **Response**: `[...PlayerSerializer]` (全選手 + cost_players eager load)

---

## 選手カード (Player Cards)

### GET /api/v1/player_cards

- **Controller**: `Api::V1::PlayerCardsController#index`
- **Query Params**: `card_set_id` (integer), `card_type` (string), `name` (string, ILIKE), `page` (integer, default: 1), `per_page` (integer, default: 50, max: 100)
- **Response**: `{ player_cards: [...PlayerCardSerializer], meta: { total, page, per_page } }`

### GET /api/v1/player_cards/:id

- **Controller**: `Api::V1::PlayerCardsController#show`
- **Response**: `PlayerCardDetailSerializer`

### PATCH/PUT /api/v1/player_cards/:id

- **Controller**: `Api::V1::PlayerCardsController#update`
- **Body Params**: `player_card: { card_type, handedness, speed, bunt, steal_start, steal_end, injury_rate, is_relief_only, is_closer, is_switch_hitter, is_dual_wielder, starter_stamina, relief_stamina, biorhythm_period, unique_traits, injury_traits, player_card_defenses_attributes: [...], player_card_traits_attributes: [...], player_card_abilities_attributes: [...] }`
- **Response**: `PlayerCardDetailSerializer`

---

## カードセット (Card Sets)

### GET /api/v1/card_sets

- **Controller**: `Api::V1::CardSetsController#index`
- **Response**: `[...CardSetSerializer]`

### GET /api/v1/card_sets/:id

- **Controller**: `Api::V1::CardSetsController#show`
- **Response**: `CardSetSerializer`

---

## 選手タイプ (Player Types)

### GET /api/v1/player-types

- **Controller**: `Api::V1::PlayerTypesController#index`
- **Response**: PlayerType JSON array

### POST/PATCH/DELETE /api/v1/player-types[/:id]

- **注意**: configファイル管理のため、create/update/destroy は 403 Forbidden を返す

---

## 投球スタイル (Pitching Styles)

### GET /api/v1/pitching-styles

- **Controller**: `Api::V1::PitchingStylesController#index`
- **Response**: PitchingStyle JSON array

### POST/PATCH/DELETE /api/v1/pitching-styles[/:id]

- **注意**: configファイル管理のため、create/update/destroy は 403 Forbidden を返す

---

## 打撃スタイル (Batting Styles)

### GET /api/v1/batting-styles

- **Controller**: `Api::V1::BattingStylesController#index`
- **Response**: BattingStyle JSON array

### POST/PATCH/DELETE /api/v1/batting-styles[/:id]

- **注意**: configファイル管理のため、create/update/destroy は 403 Forbidden を返す

---

## バイオリズム (Biorhythms)

### GET /api/v1/biorhythms

- **Controller**: `Api::V1::BiorhythmsController#index`
- **Response**: Biorhythm JSON array (ordered by start_date, name)

### POST /api/v1/biorhythms

- **Controller**: `Api::V1::BiorhythmsController#create`
- **Body Params**: `biorhythm: { name, start_date, end_date }`
- **Response**: Biorhythm JSON 201

### PATCH/PUT /api/v1/biorhythms/:id

- **Controller**: `Api::V1::BiorhythmsController#update`
- **Body Params**: `biorhythm: { name, start_date, end_date }`
- **Response**: Biorhythm JSON

### DELETE /api/v1/biorhythms/:id

- **Controller**: `Api::V1::BiorhythmsController#destroy`
- **Response**: 204 No Content

---

## コストリスト (Costs)

### GET /api/v1/costs

- **Controller**: `Api::V1::CostsController#index`
- **Response**: `[...CostSerializer]`

### GET /api/v1/costs/:id

- **Controller**: `Api::V1::CostsController#show`
- **Response**: `CostSerializer`

### POST /api/v1/costs

- **Controller**: `Api::V1::CostsController#create`
- **Body Params**: `cost: { name, start_date, end_date }`
- **Response**: CostSerializer 201

### PATCH/PUT /api/v1/costs/:id

- **Controller**: `Api::V1::CostsController#update`
- **Body Params**: `cost: { name, start_date, end_date }`
- **Response**: CostSerializer

### DELETE /api/v1/costs/:id

- **Controller**: `Api::V1::CostsController#destroy`
- **Response**: 204 No Content

### POST /api/v1/costs/:id/duplicate

- **Controller**: `Api::V1::CostsController#duplicate`
- **挙動**: Cost + 全CostPlayerを複製。名前に "(コピー)" 追加、日付を1年後にずらす
- **Response**: 複製したCost JSON 201

---

## シーズン (Seasons)

### POST /api/v1/seasons

- **Controller**: `Api::V1::SeasonsController#create`
- **Body Params**: `team_id` (integer), `schedule_id` (integer), `name` (string)
- **挙動**: Season作成 + 指定Scheduleの全ScheduleDetailをSeasonScheduleとしてコピー
- **Response**: `{ season: {...}, schedule_count: integer }` 201

---

## 選手欠場 (Player Absences)

### GET /api/v1/player_absences

- **Controller**: `Api::V1::PlayerAbsencesController#index`
- **Query Params**: `season_id` (integer, 必須)
- **Response**: `[...PlayerAbsenceSerializer]`

### POST /api/v1/player_absences

- **Controller**: `Api::V1::PlayerAbsencesController#create`
- **Body Params**: `player_absence: { team_membership_id, season_id, absence_type, reason, start_date, duration, duration_unit }`
- **Response**: PlayerAbsenceSerializer 201

### PATCH/PUT /api/v1/player_absences/:id

- **Controller**: `Api::V1::PlayerAbsencesController#update`
- **Body Params**: `player_absence: { team_membership_id, season_id, absence_type, reason, start_date, duration, duration_unit }`
- **Response**: PlayerAbsenceSerializer

### DELETE /api/v1/player_absences/:id

- **Controller**: `Api::V1::PlayerAbsencesController#destroy`
- **Response**: 204 No Content

---

## 日程表 (Schedules)

### GET /api/v1/schedules

- **Controller**: `Api::V1::SchedulesController#index`
- **Response**: Schedule JSON array

### POST /api/v1/schedules

- **Controller**: `Api::V1::SchedulesController#create`
- **Body Params**: `schedule: { name, start_date, end_date, effective_date }`
- **Response**: Schedule JSON 201

### PATCH/PUT /api/v1/schedules/:id

- **Controller**: `Api::V1::SchedulesController#update`
- **Body Params**: `schedule: { name, start_date, end_date, effective_date }`
- **Response**: Schedule JSON

### DELETE /api/v1/schedules/:id

- **Controller**: `Api::V1::SchedulesController#destroy`
- **Response**: 204 No Content

---

## 日程詳細 (Schedule Details)

### GET /api/v1/schedules/:schedule_id/schedule_details

- **Controller**: `Api::V1::ScheduleDetailsController#index`
- **Response**: ScheduleDetail JSON array (ordered by date)

### POST /api/v1/schedules/:schedule_id/schedule_details/upsert_all

- **Controller**: `Api::V1::ScheduleDetailsController#upsert_all`
- **Body Params**: `schedule_details: [{ id, date, date_type, schedule_id, priority }]`
- **挙動**: `upsert_all` (unique_by: [schedule_id, date])
- **Response**: 200 OK

---

## 大会 (Competitions)

### GET /api/v1/competitions

- **Controller**: `Api::V1::CompetitionsController#index`
- **Response**: `[...CompetitionSerializer]` (ordered by year desc, id asc)

### GET /api/v1/competitions/:id

- **Controller**: `Api::V1::CompetitionsController#show`
- **Response**: `CompetitionSerializer` (includes competition_entries)

### POST /api/v1/competitions

- **Controller**: `Api::V1::CompetitionsController#create`
- **認証**: Commissioner必須
- **Body Params**: `competition: { name, year, competition_type }`
- **Response**: `CompetitionSerializer` 201

### PATCH/PUT /api/v1/competitions/:id

- **Controller**: `Api::V1::CompetitionsController#update`
- **認証**: Commissioner必須
- **Body Params**: `competition: { name, year, competition_type }`
- **Response**: `CompetitionSerializer`

### DELETE /api/v1/competitions/:id

- **Controller**: `Api::V1::CompetitionsController#destroy`
- **認証**: Commissioner必須
- **Response**: 204 No Content

### GET /api/v1/competitions/:id/teams

- **Controller**: `Api::V1::CompetitionsController#teams`
- **Response**: `[...TeamSerializer]` (大会参加チーム一覧)

### GET /api/v1/competitions/:id/roster

- **Controller**: `Api::V1::CompetitionRostersController#index`
- **Query Params**: `team_id` (integer, 必須)
- **Response**: `{ first_squad: [...], second_squad: [...] }` 各要素: `{ player_card_id, player_name, squad, is_reliever, cost }`

### POST /api/v1/competitions/:id/roster/players

- **Controller**: `Api::V1::CompetitionRostersController#add_player`
- **Query Params**: `team_id` (integer, 必須)
- **Body Params**: `player_card_id` (integer), `squad` (string)
- **挙動**: 追加後にCostValidatorでコスト検証。NG時はrollback
- **Response**: `{ player_card_id, player_name, squad, is_reliever, cost }` 201

### DELETE /api/v1/competitions/:id/roster/players/:player_card_id

- **Controller**: `Api::V1::CompetitionRostersController#remove_player`
- **Query Params**: `team_id` (integer, 必須)
- **Response**: 204 No Content

### GET /api/v1/competitions/:id/roster/cost_check

- **Controller**: `Api::V1::CompetitionRostersController#cost_check`
- **Query Params**: `team_id` (integer, 必須)
- **Response**: `CostValidator#validate` の返り値 `{ valid: boolean, errors: [...] }`

---

## ホーム画面 (Home)

### GET /api/v1/home/summary

- **Controller**: `Api::V1::HomeController#summary`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**:
  ```json
  {
    "season_progress": { "completed": int, "total": 143 },
    "recent_games": [{ "id", "real_date", "home_team", "visitor_team", "home_score", "visitor_score" }],
    "batting_top3": [{ ...stats, "hr", "batting_average" }],
    "pitching_top3": [{ ...stats, "era" }],
    "team_summary": { ...TeamStatsCalculator 返り値 }
  }
  ```

---

## 成績集計 (Stats)

### GET /api/v1/stats/batting

- **Controller**: `Api::V1::StatsController#batting`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**: `{ batting_stats: [...] }` (BattingStatsCalculator)

### GET /api/v1/stats/pitching

- **Controller**: `Api::V1::StatsController#pitching`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**: `{ pitching_stats: [...] }` (PitchingStatsCalculator)

### GET /api/v1/stats/team

- **Controller**: `Api::V1::StatsController#team`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**: `{ team_stats: [...] }` (TeamStatsCalculator)

---

## コストアサインメント (Cost Assignments)

### GET /api/v1/cost_assignments

- **Controller**: `Api::V1::CostAssignmentsController#index`
- **Query Params**: `cost_id` (integer)
- **Response**: `[{ ...player_fields, normal_cost, relief_only_cost, pitcher_only_cost, fielder_only_cost, two_way_cost }]`

### POST /api/v1/cost_assignments

- **Controller**: `Api::V1::CostAssignmentsController#create`
- **Body Params**: `assignments: { cost_id, players: [{ player_id, normal_cost, relief_only_cost, pitcher_only_cost, fielder_only_cost, two_way_cost }] }`
- **Response**: 200 (暗黙)

---

## 球場 (Stadiums)

### GET /api/v1/stadiums

- **Controller**: `Api::V1::StadiumsController#index`
- **Response**: `[...StadiumSerializer]`

### GET /api/v1/stadiums/:id

- **Controller**: `Api::V1::StadiumsController#show`
- **Response**: `StadiumSerializer`

### POST /api/v1/stadiums

- **Controller**: `Api::V1::StadiumsController#create`
- **認証**: Commissioner必須
- **Body Params**: `stadium: { code, name, up_table_ids, indoor }`
- **Response**: `StadiumSerializer` 201

### PATCH/PUT /api/v1/stadiums/:id

- **Controller**: `Api::V1::StadiumsController#update`
- **認証**: Commissioner必須
- **Body Params**: `stadium: { code, name, up_table_ids, indoor }`
- **Response**: `StadiumSerializer`

---

## ユーザー (Users)

### GET /api/v1/users/me/teams

- **Controller**: `Api::V1::UsersController#my_teams`
- **認証**: ログイン済みユーザー全員
- **Response**: `[{ id, name, is_active, user_id, short_name }]`

### GET /api/v1/users

- **Controller**: `Api::V1::UsersController#index`
- **認証**: Commissioner必須
- **Response**: `[{ id, name, display_name, role }]`

### POST /api/v1/users

- **Controller**: `Api::V1::UsersController#create`
- **認証**: Commissioner必須
- **Body Params**: `user: { name, display_name, password, role }`
- **Response**: `{ id, name, display_name, role }` 201

### PATCH /api/v1/users/:id/reset_password

- **Controller**: `Api::V1::UsersController#reset_password`
- **認証**: Commissioner必須
- **Body Params**: `password` (string)
- **Response**: `{ message: "パスワードをリセットしました" }`

### PATCH /api/v1/users/:id/update_role

- **Controller**: `Api::V1::UsersController#update_role`
- **認証**: Commissioner必須
- **Body Params**: `role` (string)
- **Response**: `{ id, name, display_name, role }`

### POST /api/v1/users/change_password

- **Controller**: `Api::V1::UsersController#change_password`
- **認証**: ログイン済みユーザー全員
- **Body Params**: `current_password` (string), `new_password` (string)
- **Response**: `{ message: "パスワードを変更しました" }` / 422 on error

---

## 投手登板管理 (Pitcher Appearances)

### POST /api/v1/pitcher_appearances

- **Controller**: `Api::V1::PitcherAppearancesController#create`
- **Body Params**:
  ```json
  {
    "pitcher_appearance": {
      "pitcher_id": int,
      "team_id": int,
      "schedule_date": "YYYY-MM-DD",
      "role": "starter"|"relief"|"closer",
      "innings_pitched": float,
      "decision": "W"|"L"|"S"|"H"|null,
      "game_result": "win"|"lose"|"draw",
      "fatigue_p_used": int,
      "result_category": "完投"|"QS"|"先発中退"|"中継ぎ"|"セーブ"|"ホールド"|"KO"|null
    }
  }
  ```
  ※ `result_category` は省略可（自動計算）
- **Response**: `{ pitcher_appearance: {...}, warnings: [...] }` 201

---

## 投手登板状態 (Pitcher Game States)

### GET /api/v1/teams/:team_id/pitcher_game_states

- **Controller**: `Api::V1::PitcherGameStatesController#index`
- **Query Params**: `date` (YYYY-MM-DD, default: 今日), `player_ids[]` (integer array, optional)
- **Response**: 各投手の登板状態・疲労情報・クールダウン・推定コンディション

### GET /api/v1/teams/:team_id/pitcher_game_states/fatigue_summary

- **Controller**: `Api::V1::PitcherGameStatesController#fatigue_summary`
- **Query Params**: `date` (YYYY-MM-DD, default: 今日)
- **Response**: チーム全投手のシーズン疲労サマリー（累積投球回・平均登板間隔等）

---

## コミッショナーダッシュボード (Commissioner Dashboard)

以下のエンドポイントはすべて Commissioner ロール必須。

### GET /api/v1/commissioner/dashboard/absences

- **Controller**: `Api::V1::Commissioner::DashboardController#absences`
- **Response**: 全アクティブチームの現在有効な離脱者一覧（チーム名・選手名・離脱タイプ・期間・残日数）

### GET /api/v1/commissioner/dashboard/costs

- **Controller**: `Api::V1::Commissioner::DashboardController#costs`
- **Response**: 全アクティブチームのコスト使用状況（合計コスト・上限・外の世界枠等）

### GET /api/v1/commissioner/dashboard/cooldowns

- **Controller**: `Api::V1::Commissioner::DashboardController#cooldowns`
- **Response**: 全アクティブチームのクールダウン中選手一覧（選手名・解除日・残日数）
