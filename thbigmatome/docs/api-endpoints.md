# API エンドポイント仕様

最終更新日: 2026-04-01

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
- **Response**: SeasonSchedule JSON + `warnings: string[]`。得点（score / opponent_score）を保存すると、その試合の先発の result_category を作り直す。作り直しが想定外のエラーで失敗しても得点は保存され（200）、`warnings` に「判定の作り直しに失敗した・後で作り直しが必要」を入れる（ログにも残る。rake `pitcher_game_states:recalculate_result_category` で作り直せる）

---

## チームロスター (Team Rosters)

### GET /api/v1/teams/:team_id/roster

- **Controller**: `Api::V1::TeamRostersController#show`
- **Query Params**: `target_date` (YYYY-MM-DD, 省略時は現在日カーソル), `phase` (`pre_game` | `in_game` | `post_game`, 省略時は `pre_game`。不正な値は 400)
- **1軍/2軍の決め方**: 昇降格の変更記録（`season_rosters`）を `RosterState` で (日付, 区分) 時点まで畳んで導く。記録が無い選手は 2軍（`team_memberships.squad` の写しには倒さない）。クールダウンも同じ記録から求める（直前と同じ区分への記録は畳む）
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
  - `roster_updates`: `[{ team_membership_id: int, squad: "first"|"second" }]`（`squad` が `first`/`second` 以外、同じ選手の重複は 422）
  - `target_date`: date string（省略時は現在日カーソル。過去日・未来日どちらも保存できる）
  - `phase`: `pre_game` | `in_game` | `post_game`（省略時は `pre_game`。同じ日の中の試合前・試合後の区分。不正な値は 422）
- **バリデーション**: 1軍人数上限(29)、最小人数（game_rules.yaml#team_composition.first_squad_minimum_players）、コスト上限（game_rules.yaml#team_composition.team_total_max_cost: 200）、クールダウン(10日: game_rules.yaml#season.cooldown_days)、再調整中選手の昇格禁止
- **書き込みの規則**（`RosterWriter` / `RosterConstraintChecker`。設計 `context/thbig-dugout-season-record-restructure-design.md` §4.4）:
  - 書き込んだ時点そのもの（対象日・対象区分）は絶対の基準で検査する（試合日の試合前は最低人数、1軍上限 29、1軍コスト、外の世界枠）。再調整中の昇格と、直接の昇格のクールダウン（降格から 10 日未満。同日の昇降格は免除）は、コミッショナーでも 422
  - それより後の各時点（記録のある時点と、日程の試合日の試合前）は、この保存で**新たに生じた、または悪化した**違反だけを検査する（保存の前から外れていた日は、悪化させない限り止めない）。昇格がクールダウンに掛かる場合も同じ
  - 違反があればコミッショナー以外は保存せず 422 `{ error, violations: [{ date, phase, kind, message }] }`（`kind`: `first_squad_min` / `first_squad_max` / `first_squad_cost` / `outside_world_limit` / `outside_world_balance` / `cooldown`）。コミッショナーは保存し、`warnings` に `{ type: "commissioner_override", message, kind, date, phase }` を返す
  - 保存のたびに `team_memberships.squad`（写し）を変更記録の最新の状態に作り直す（現在日カーソルとの一致で条件づけない）
- **Response**: `{ message: "Roster updated successfully", warnings: [] }`

### DELETE /api/v1/teams/:team_id/roster_entries/:id

- **Controller**: `Api::V1::RosterEntriesController#destroy`
- **説明**: 昇降格の変更記録（`season_rosters` の 1 行）を取り消す。そのチームの記録でなければ 404。消したあと、その時点以降の各時点を POST /roster と同じ規則で検査し直し、新たに生じた（悪化した）違反があればコミッショナー以外は 422（記録は残る）、コミッショナーは警告つきで消す。写しは作り直す
- **Response**: `{ message: "Roster entry deleted successfully", warnings: [] }`

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
  - `players`: `[{ player_id, selected_cost_type, excluded_from_team_total, display_name, player_card_id }]`
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
- **Response**: `{ team_id, team_name, season_id, game_date, game_number, announced_starter_id, stadium, home_away, designated_hitter_enabled, score, opponent_score, no_game, opponent_team_id, opponent_team, winning_pitcher_id, losing_pitcher_id, save_pitcher_id, scoreboard, starting_lineup, opponent_starting_lineup, game_result }`

### PATCH/PUT /api/v1/game/:id

- **Controller**: `Api::V1::GameController#update`
- **Path Params**: `:id` (SeasonSchedule ID)
- **Body Params**: `announced_starter_id, stadium, home_away, designated_hitter_enabled, score, opponent_score, no_game, opponent_team_id, winning_pitcher_id, losing_pitcher_id, save_pitcher_id, scoreboard: { home: [], away: [] }, starting_lineup: [{ player_id, position, order }], opponent_starting_lineup: [...]`
- **Response**: SeasonSchedule JSON
- **no_game**: ノーゲーム（試合が成立しなかった）。得点では表せないので試合概要に持つ。true の日は登板記録の `result_category` が全員 `no_game` になり、先発の次回の休養は KO・ノーゲームの表（rulebook 08 §8.3.1）で計算される。得点・`no_game` のどちらかが変わった保存で、その日の先発の判定と、区分が変わった投手の後続の先発が作り直される（`PitcherResultCategoryRebuilder`）

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
- **認可**: TeamAccessible（チームオーナーまたはCommissioner）
- **Body Params**: `team_id` (integer), `schedule_id` (integer), `name` (string)
- **挙動**: Season作成 + 指定Scheduleの全ScheduleDetailをSeasonScheduleとしてコピー
- **Response**: `{ season: {...}, schedule_count: integer }` 201

### PATCH /api/v1/seasons/:id

- **Controller**: `Api::V1::SeasonsController#update`
- **認可**: Commissioner ロール必須
- **Body Params**: `season` → `{ key_player_id }` (TeamMembership ID — 特例選手指定)
- **Response**: `{ season: {...}, key_player_name: string|null }` 200

### DELETE /api/v1/seasons/:id

- **Controller**: `Api::V1::SeasonsController#destroy`
- **認可**: Commissioner ロール必須
- **Response**: 204 No Content

---

## 選手欠場 (Player Absences)

### GET /api/v1/player_absences

- **Controller**: `Api::V1::PlayerAbsencesController#index`
- **Query Params**: `season_id` (integer) または `team_id` (integer) — いずれか必須。team_id指定時はそのチームのシーズンの離脱者を返す
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
- **ノーゲーム**: ノーゲームの試合は消化試合数・直近試合・成績に入れない（台帳 D-11。`Game.excluding_no_game` / `NoGameGames`）

---

## 成績集計 (Stats)

### GET /api/v1/stats/batting

- **Controller**: `Api::V1::StatsController#batting`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**: `{ batting_stats: [...] }` (BattingStatsCalculator)。ノーゲームの試合は集計に入れない（台帳 D-11）

### GET /api/v1/stats/pitching

- **Controller**: `Api::V1::StatsController#pitching`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**: `{ pitching_stats: [...] }` (PitchingStatsCalculator)。ノーゲームの試合は集計に入れない（台帳 D-11）

### GET /api/v1/stats/team

- **Controller**: `Api::V1::StatsController#team`
- **Query Params**: `competition_id` (integer, 必須)
- **Response**: `{ team_stats: [...] }` (TeamStatsCalculator)。ノーゲームの試合は集計に入れない（台帳 D-11）

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

### GET /api/v1/pitcher_appearances

- **Controller**: `Api::V1::PitcherAppearancesController#index`
- **Query Params**: `team_id` (integer, 必須), `schedule_date` (date string, 必須)
- **Response**: 指定チーム・日付の投手登板状態一覧（appearance_order順）。各エントリにid, pitcher_id, role, innings_pitched, earned_runs, decision, is_opener, consecutive_short_rest_count, pre_injury_days_excluded, result_category, injury_check等を含む

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
  ※ `schedule_date` は必須。無い・日付として読めない場合は 422（`errors` に schedule_date を示すメッセージ）。`bulk_save` も保存する登板がある時は同じ
  ※ `consecutive_short_rest_count` はサーバが決める（先発: 直前の登板（役割を問わない）が先発で、そこからの中日数が中4日以下なら前回値+1、それ以外は 0（間にリリーフ・オープナーが入れば 0・AMB-23）。リリーフは 0）。送っても使わない
  ※ 第二先発（オープナーの次の2番手）は `role: "starter"` で送る。KO・長イニング敗戦の判定と次回の休養表は先発として扱う
- **Response**: `{ pitcher_appearance: {...}, warnings: [...] }` 201

---

## 投手登板状態 (Pitcher Game States)

### GET /api/v1/teams/:team_id/pitcher_game_states

- **Controller**: `Api::V1::PitcherGameStatesController#index`
- **Query Params**: `date` (YYYY-MM-DD, default: 今日), `player_ids[]` (integer array, optional)
- **Response**: 各投手の登板状態・疲労情報・クールダウン・推定コンディション

### GET /api/v1/teams/:team_id/pitcher_game_states/fatigue_summary

- **Controller**: `Api::V1::PitcherGameStatesController#fatigue_summary`
- **Query Params**: `date` (YYYY-MM-DD, default: 今日), `phase` (`pre_game` | `in_game` | `post_game`, 省略時は `pre_game`。不正な値は 400)
- **1軍の決め方**: 昇降格の変更記録を `RosterState` で (date, phase) 時点まで畳んで導く（記録が無い投手は 2軍）
- **Response**: チーム1軍投手の登板時の状態。投手ごとに `last_role` / `rest_days`（先発明けのみ）/ `cumulative_innings`（リリーフ明けのみ）/ `is_injured` / `is_unavailable`（先発としては登板不可 = 中2日以内。前回の役割に依らない）と、次の 5 つを返す
  - `projected_status`: 前回と同じ役割で続ける場合の状態（旧来の値）
  - `as_starter` / `as_reliever`: 「先発なら」「リリーフなら」の登板時の状態 `{ status, notes: [] }`。省略する投手は `null`（理由は `as_starter_omitted_reason` / `as_reliever_omitted_reason`）
  - `status`: `full` / `reduced_N`（疲労P -N。`reduced_0` は疲労P 0）/ `injury_check` / `unavailable`（先発→リリーフの表より短い中日数のリリーフも含む。AMB-22）/ `injured` に加え、`fatigued_start`（登板の最初から疲労状態。疲労P 0 とは別）/ `fatigued_start_check`（最初から疲労状態 + 登板後の負傷チェック。累積3I 以上）
  - `as_opener`: 「オープナーなら」の登板時の状態 `{ status, notes: [] }`。「オープナー可」アビリティ（`ability_definitions.name = "オープナー可"` を `player_card_abilities` で持つ。rulebook 08 §8.4.1）を持つ投手だけ返し、持たない投手は `null`（`as_opener_omitted_reason: "no_opener_ability"`）。**ただし `ability_definitions` が 1 件も無い間（カードの記載が未取込）は、リリーフで投げられる投手（`relief_stamina` を持つ、またはリリーフ専門 = `as_reliever` を出す条件と同じ）全員に返す**。出し分けの根拠は各行の `opener_capable_source`（`fallback_all_relievers` = 未取込のため全リリーフ可能投手 / `card_ability` = カードの記載どおり）。`status` は `as_reliever` と同じ（オープナー本人はリリーフ扱い §8.4.2）。登板不可・負傷中の `notes` は空
  - `notes`（`as_reliever`）: `previous_day_one_inning_only`（累積4以上で前日登板: 前日の負傷チェックに合格していれば1イニング限定で登板可。合否は記録しない。`as_opener` にも同条件で付く）
  - `notes`（`as_opener`、負傷チェックの理由。§8.4.3）: `opener_check_consecutive`（中2日以内の連続オープナー登板 = 前回の登板が `opener` で、離脱を差し引いた中日数が 2 以下）/ `opener_check_previous_day`（前日登板 = 離脱を差し引かない実日数が 0）/ `opener_check_cumulative`（累積1以上で登板。休養日数の上限を掛けた後の累積で判定）
  - 省略の理由: `as_starter_omitted_reason` は `relief_only_card`（カードがリリーフ専門）/ `relief_only_contract`（救援専任契約 = `team_memberships.selected_cost_type = relief_only_cost`。先発もできる契約に変えると出る）、`as_reliever_omitted_reason` は `no_relief_stamina`（リリーフ向けの疲労Pをカードに持たない先発）、`as_opener_omitted_reason` は `no_opener_ability`（「オープナー可」アビリティを持たない）
  - `starter_stamina` / `relief_stamina` / `is_relief_only`: カードに記載の疲労P（`player_cards` の値そのまま。`is_relief_only` は NULL を `false` で返す）。画面の「カード疲労P」列が「6/1」「1R」「6」の表記に組み立てる（thbig-rules `sources/card-structure.md` §3）。試合前補正を掛けた計算値ではない
  - ルール: rulebook 08 §8.3.1〜§8.3.4・§8.4.3・§8.7.2、台帳 AMB-18 追補 / AMB-19 追補 / AMB-21 / AMB-22

---

## 内部サービス間API (Internal Exports)

`Api::V1::InternalBaseController` で `X-Internal-Api-Key` ヘッダーまたは `internal_api_key` query param を検証する。`INTERNAL_API_KEY` 未設定時は 503、本番で開発用デフォルト値 `thbig-internal-sync-key` を使っている場合も 503。

### GET /api/v1/internal/players

- **Controller**: `Api::V1::Internal::ExportsController#players`
- **Query Params**: `page`, `per_page`
- **Response**: 未指定時は配列。`page` / `per_page` 指定時は `{ players: [...], meta: { current_page, per_page, total_count, total_pages } }`

### GET /api/v1/internal/teams

- **Controller**: `Api::V1::Internal::ExportsController#teams`
- **Query Params**: `page`, `per_page`
- **Response**: 未指定時は配列。ページング時は `teams` + `meta`

### GET /api/v1/internal/stadiums

- **Controller**: `Api::V1::Internal::ExportsController#stadiums`
- **Query Params**: `page`, `per_page`
- **Response**: 未指定時は配列。ページング時は `stadiums` + `meta`

### GET /api/v1/internal/card_sets

- **Controller**: `Api::V1::Internal::ExportsController#card_sets`
- **Query Params**: `page`, `per_page`
- **Response**: 未指定時は配列。ページング時は `card_sets` + `meta`

### GET /api/v1/internal/player_cards

- **Controller**: `Api::V1::Internal::ExportsController#player_cards`
- **Query Params**: `page`, `per_page`
- **Response**: 未指定時は配列。ページング時は `player_cards` + `meta`

### GET /api/v1/internal/seasons

- **Controller**: `Api::V1::Internal::ExportsController#seasons`
- **Query Params**: `page`, `per_page`
- **Response**: 未指定時は配列。ページング時は `seasons` + `meta`

### GET /api/v1/internal/games

- **Controller**: `Api::V1::Internal::ExportsController#games`
- **Query Params**: `from` (date), `to` (date), `page`, `per_page`
- **Response**: 未指定時は配列。ページング時は `games` + `meta`

### GET /api/v1/internal/games/:id

- **Controller**: `Api::V1::Internal::ExportsController#game_show`
- **Response**: 単一 game の内部同期用 JSON

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

### GET /api/v1/commissioner/dashboard/roster_status

- **Controller**: `Api::V1::Commissioner::DashboardController#roster_status`
- **Query Params**: `team_id` (integer, optional — 指定時は対象チームのみ), `format` ("csv" でCSVダウンロード)
- **Response**: 全アクティブチームのロスター状況（コスト・1軍/2軍人数・外の世界枠・警告等）。1軍/2軍・クールダウンは写しでなく、シーズンの現在日カーソル・試合前の時点の変更記録（`RosterState`）から求める（`/costs`・`/cooldowns` も同じ）
- **CSV**: `format=csv` 指定時はCSVファイルをダウンロード

---

## コミッショナー: 選手離脱管理 (Commissioner Player Absences)

Commissioner ロール必須。チームメンバーシップに紐づく離脱レコードの CRUD。

### GET /api/v1/commissioner/team_memberships/:team_membership_id/player_absences

- **Controller**: `Api::V1::Commissioner::PlayerAbsencesController#index`
- **Response**: 対象メンバーシップの離脱一覧

### POST /api/v1/commissioner/team_memberships/:team_membership_id/player_absences

- **Controller**: `Api::V1::Commissioner::PlayerAbsencesController#create`
- **Body Params**: `player_absence` → `{ season_id, absence_type, start_date, duration, duration_unit }`
- **Response**: 201 Created

### GET /api/v1/commissioner/team_memberships/:team_membership_id/player_absences/:id

- **Controller**: `Api::V1::Commissioner::PlayerAbsencesController#show`

### PATCH /api/v1/commissioner/team_memberships/:team_membership_id/player_absences/:id

- **Controller**: `Api::V1::Commissioner::PlayerAbsencesController#update`
- **Body Params**: `player_absence` → `{ season_id, absence_type, start_date, duration, duration_unit }`

### DELETE /api/v1/commissioner/team_memberships/:team_membership_id/player_absences/:id

- **Controller**: `Api::V1::Commissioner::PlayerAbsencesController#destroy`
- **Response**: 204 No Content

---

## コミッショナー: チーム監督・コーチ管理 (Commissioner Team Managers)

Commissioner ロール必須。チームに紐づく監督・コーチの CRUD。

### GET /api/v1/commissioner/teams/:team_id/team_managers

- **Controller**: `Api::V1::Commissioner::TeamManagersController#index`
- **Response**: 対象チームの監督・コーチ一覧

### POST /api/v1/commissioner/teams/:team_id/team_managers

- **Controller**: `Api::V1::Commissioner::TeamManagersController#create`
- **Body Params**: `team_manager` → `{ manager_id, role }`
- **Response**: 201 Created

### GET /api/v1/commissioner/teams/:team_id/team_managers/:id

- **Controller**: `Api::V1::Commissioner::TeamManagersController#show`

### PATCH /api/v1/commissioner/teams/:team_id/team_managers/:id

- **Controller**: `Api::V1::Commissioner::TeamManagersController#update`
- **Body Params**: `team_manager` → `{ manager_id, role }`

### DELETE /api/v1/commissioner/teams/:team_id/team_managers/:id

- **Controller**: `Api::V1::Commissioner::TeamManagersController#destroy`
- **Response**: 204 No Content

---

## コミッショナー: チームメンバーシップ管理 (Commissioner Team Memberships)

Commissioner ロール必須。チームメンバーシップの参照・更新・削除（createはTeam Players経由）。

### GET /api/v1/commissioner/teams/:team_id/team_memberships

- **Controller**: `Api::V1::Commissioner::TeamMembershipsController#index`
- **Response**: 対象チームのメンバーシップ一覧

### GET /api/v1/commissioner/teams/:team_id/team_memberships/:id

- **Controller**: `Api::V1::Commissioner::TeamMembershipsController#show`

### PATCH /api/v1/commissioner/teams/:team_id/team_memberships/:id

- **Controller**: `Api::V1::Commissioner::TeamMembershipsController#update`
- **Body Params**: `team_membership` → `{ squad, selected_cost_type, display_name }`

### DELETE /api/v1/commissioner/teams/:team_id/team_memberships/:id

- **Controller**: `Api::V1::Commissioner::TeamMembershipsController#destroy`
- **Response**: 204 No Content
