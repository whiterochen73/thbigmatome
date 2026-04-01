# モデル仕様書

最終更新日: 2026-04-01

## 参照ソースファイル

- `app/models/*.rb`
- `app/models/concerns/baseball_card_validations.rb`
- `config/game_rules.yaml` — ゲームルール正本（ビジネスルールの値・制約はこのファイルが Single Source of Truth）

---

## モデル一覧

| モデル名 | 対応テーブル | 用途 |
|---------|------------|------|
| AbilityDefinition | ability_definitions | アビリティ定義マスタ |
| ApplicationRecord | — | Railsベースクラス（STI基底） |
| AtBat | at_bats | 試合打席データ（ライブ入力） |
| AtBatRecord | at_bat_records | ゲームレコード打席データ（ログ解析） |
| BattingStyle | batting_styles | 打撃スタイルマスタ |
| Biorhythm | biorhythms | バイオリズム周期マスタ |
| CardSet | card_sets | カードセットマスタ |
| Competition | competitions | 大会マスタ |
| CompetitionEntry | competition_entries | 大会チームエントリ |
| CompetitionRoster | competition_rosters | 大会登録ロスター |
| Cost | costs | コストリストマスタ |
| CostPlayer | cost_players | 選手コスト情報 |
| Game | games | 試合データ |
| GameEvent | game_events | 試合内イベント |
| GameLineup | game_lineups | チーム試合ラインナップ（一時保存） |
| GameLineupEntry | game_lineup_entries | 試合ラインナップエントリ |
| GameRecord | game_records | ゲームレコード（ログ解析結果） |
| ImportedStat | imported_stats | インポート済み選手成績 |
| LineupTemplate | lineup_templates | オーダーテンプレート |
| LineupTemplateEntry | lineup_template_entries | オーダーテンプレートエントリ |
| Manager | managers | 監督・コーチマスタ |
| PitcherGameState | pitcher_game_states | 投手登板状態 |
| PitchingStyle | pitching_styles | 投球スタイルマスタ |
| Player | players | 選手マスタ |
| PlayerAbsence | player_absences | 選手離脱記録 |
| PlayerCard | player_cards | 選手カードデータ |
| PlayerCardAbility | player_card_abilities | カード×アビリティ中間テーブル |
| PlayerCardDefense | player_card_defenses | カード守備能力 |
| PlayerCardExclusiveCatcher | player_card_exclusive_catchers | 専用捕手制約 |
| PlayerCardPlayerType | player_card_player_types | カード×プレイヤータイプ中間テーブル |
| PlayerCardTrait | player_card_traits | カード×トレイト中間テーブル |
| PlayerType | player_types | プレイヤータイプマスタ |
| Schedule | schedules | スケジュールマスタ |
| ScheduleDetail | schedule_details | スケジュール日付詳細 |
| Season | seasons | チームシーズン管理 |
| SeasonRoster | season_rosters | シーズンロスター（公示履歴） |
| SeasonSchedule | season_schedules | シーズン試合スケジュール |
| SquadTextSetting | squad_text_settings | スカッドテキスト生成設定 |
| Stadium | stadiums | 球場マスタ |
| Team | teams | チームマスタ |
| TeamManager | team_managers | チーム×監督・コーチ |
| TeamMembership | team_memberships | チーム×選手所属 |
| TraitCondition | trait_conditions | トレイト発動条件マスタ |
| TraitDefinition | trait_definitions | トレイト定義マスタ |
| User | users | ユーザー（認証・ロール） |

---

## モデル詳細

### AbilityDefinition

```ruby
class AbilityDefinition < ApplicationRecord
```

**関連**:
- (なし — 中間テーブル経由で player_cards と多対多)

**バリデーション**:
- `name`: presence, uniqueness

---

### ApplicationRecord

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
```

全モデルの基底クラス。STI（Single Table Inheritance）の基底としても機能。

---

### AtBat

```ruby
class AtBat < ApplicationRecord
```

**関連**:
- `belongs_to :game`
- `belongs_to :batter, class_name: "Player"` (FK: batter_id)
- `belongs_to :pitcher, class_name: "Player"` (FK: pitcher_id)
- `belongs_to :pinch_hit_for, class_name: "Player", optional: true` (FK: pinch_hit_for_id)

**enum**:
- `status`: `{ draft: 0, confirmed: 1 }`

**バリデーション**:
- `seq`: presence, integer, uniqueness(scope: game_id)
- `half`: inclusion in %w[top bottom]
- `play_type`: inclusion in %w[normal bunt squeeze safety_bunt hit_and_run]
- `result_code`: presence
- `inning`: integer > 0
- `outs`: integer 0..2
- `outs_after`: integer 0..3

---

### AtBatRecord

```ruby
class AtBatRecord < ApplicationRecord
```

ゲームレコード（ログ解析結果）の打席単位データ。`AtBat`（ライブ入力）とは別。

**関連**:
- `belongs_to :game_record`

**定数**:
- `VALID_HALVES = %w[top bottom]`
- `VALID_STRATEGIES = %w[hitting bunt endrun steal intentional_walk]`

**バリデーション**:
- `half`: inclusion in VALID_HALVES, allow_nil
- `strategy`: inclusion in VALID_STRATEGIES, allow_nil
- `runs_scored`: numericality >= 0
- `ab_num`: uniqueness(scope: game_record_id), allow_nil

---

### BattingStyle

```ruby
class BattingStyle < ApplicationRecord
```

**関連**: (なし — player_cards.batting_style_id から参照)

**バリデーション**:
- `name`: presence, uniqueness

---

### Biorhythm

```ruby
class Biorhythm < ApplicationRecord
```

**バリデーション**:
- `name`: presence, uniqueness
- `start_date`: presence
- `end_date`: presence
- カスタムvalidate: `end_date_after_start_date` — end_date > start_date

---

### CardSet

```ruby
class CardSet < ApplicationRecord
```

**関連**:
- `has_many :player_cards, dependent: :destroy`

**バリデーション**:
- `year`: presence, integer
- `name`: presence
- `set_type`: presence
- `year`: uniqueness(scope: set_type)

---

### Competition

```ruby
class Competition < ApplicationRecord
  COMPETITION_TYPES = %w[league_pennant tournament].freeze
```

**関連**:
- `has_many :competition_entries, dependent: :destroy`
- `has_many :teams, through: :competition_entries`
- `has_many :games, dependent: :destroy`
- `has_many :pitcher_game_states, dependent: :destroy`
- `has_many :imported_stats, dependent: :destroy`

**バリデーション**:
- `name`: presence, uniqueness(scope: year)
- `competition_type`: presence, inclusion in COMPETITION_TYPES
- `year`: presence, integer > 0

---

### CompetitionEntry

> **ルール正本**: `config/game_rules.yaml#competition` — 大会制約

```ruby
class CompetitionEntry < ApplicationRecord
```

**関連**:
- `belongs_to :competition`
- `belongs_to :team`
- `belongs_to :base_team, class_name: "Team", optional: true`
- `has_many :competition_rosters, dependent: :destroy`
- `has_many :player_cards, through: :competition_rosters`

**バリデーション**:
- `competition_id`: uniqueness(scope: team_id) — game_rules.yaml#competition.no_duplicate_entry

---

### CompetitionRoster

```ruby
class CompetitionRoster < ApplicationRecord
```

**関連**:
- `belongs_to :competition_entry`
- `belongs_to :player_card`

**enum**:
- `squad`: `{ first_squad: 0, second_squad: 1 }`

**バリデーション**:
- `competition_entry_id`: uniqueness(scope: player_card_id) — game_rules.yaml#competition.no_duplicate_roster
- `squad`: presence

---

### Cost

```ruby
class Cost < ApplicationRecord
```

**関連**:
- `has_many :cost_players, dependent: :destroy`
- `has_many :players, through: :cost_players`

**バリデーション**:
- `name`: presence
- `start_date`: presence

**クラスメソッド**:
- `Cost.current_cost` — `end_date IS NULL` のコストリストを返す（現在有効なコスト）

---

### CostPlayer

```ruby
class CostPlayer < ApplicationRecord
```

**関連**:
- `belongs_to :cost`
- `belongs_to :player`

**バリデーション**:
- `normal_cost`: integer >= 1, allow_blank
- `relief_only_cost`: integer >= 1, allow_blank
- `pitcher_only_cost`: integer >= 1, allow_blank
- `fielder_only_cost`: integer >= 1, allow_blank
- `two_way_cost`: integer >= 1, allow_blank

---

### Game

```ruby
class Game < ApplicationRecord
```

**関連**:
- `belongs_to :competition, optional: true`
- `belongs_to :home_team, class_name: "Team", inverse_of: :home_games`
- `belongs_to :visitor_team, class_name: "Team", inverse_of: :visitor_games`
- `belongs_to :stadium, optional: true`
- `has_many :at_bats, dependent: :destroy`
- `has_many :game_events, dependent: :destroy`
- `has_many :pitcher_game_states, dependent: :destroy`
- `has_many :game_lineup_entries, dependent: :destroy`
- `has_one :game_record, dependent: :nullify`

**バリデーション**:
- `status`: inclusion in %w[draft confirmed]
- `source`: inclusion in %w[live log_import summary]

**インスタンスメソッド**:
- `draft?` — status == "draft"

---

### GameEvent

```ruby
class GameEvent < ApplicationRecord
```

**関連**:
- `belongs_to :game`

**バリデーション**:
- `seq`: presence, integer > 0, uniqueness(scope: game_id)
- `event_type`: presence
- `inning`: integer > 0
- `half`: inclusion in %w[top bottom]

---

### GameLineup

```ruby
class GameLineup < ApplicationRecord
```

1チーム1件の試合ラインナップ一時保存。

**関連**:
- `belongs_to :team`

**バリデーション**:
- `lineup_data`: presence

---

### GameLineupEntry

```ruby
class GameLineupEntry < ApplicationRecord
```

**関連**:
- `belongs_to :game`
- `belongs_to :player_card`

**enum**:
- `role`: `{ starter: 0, bench: 1, off: 2, designated_player: 3 }`

**バリデーション**:
- `batting_order`: numericality 1..9, allow_nil
- `batting_order`: uniqueness(scope: game_id), allow_nil
- `position`: inclusion in %w[P C 1B 2B 3B SS LF CF RF DH], allow_nil
- カスタムvalidate: `starter_requires_batting_order_and_position` — starter時はbatting_order・positionが必須

---

### GameRecord

```ruby
class GameRecord < ApplicationRecord
  VALID_STATUSES = %w[draft confirmed].freeze
  VALID_RESULTS = %w[win lose draw].freeze
```

**関連**:
- `belongs_to :team`
- `belongs_to :game, optional: true`
- `has_many :at_bat_records, dependent: :destroy`

**スコープ**:
- `draft` — status == "draft"
- `confirmed` — status == "confirmed"

**バリデーション**:
- `status`: inclusion in VALID_STATUSES
- `result`: inclusion in VALID_RESULTS, allow_nil

**インスタンスメソッド**:
- `draft?`
- `confirmed?`

---

### ImportedStat

```ruby
class ImportedStat < ApplicationRecord
  STAT_TYPES = %w[batting pitching].freeze
```

**関連**:
- `belongs_to :player`
- `belongs_to :competition`
- `belongs_to :team`

**バリデーション**:
- `stat_type`: presence, inclusion in STAT_TYPES
- `player_id`: uniqueness(scope: [competition_id, stat_type])

---

### LineupTemplate

```ruby
class LineupTemplate < ApplicationRecord
```

投手の左右×DH有無の組み合わせ（最大4パターン）のオーダーテンプレート。

**関連**:
- `belongs_to :team`
- `has_many :lineup_template_entries, dependent: :destroy`
- `accepts_nested_attributes_for :lineup_template_entries, allow_destroy: true`

**バリデーション**:
- `opponent_pitcher_hand`: inclusion in %w[left right]
- `dh_enabled`: inclusion in [true, false]
- `team_id`: uniqueness(scope: [dh_enabled, opponent_pitcher_hand])

---

### LineupTemplateEntry

```ruby
class LineupTemplateEntry < ApplicationRecord
```

**関連**:
- `belongs_to :lineup_template`
- `belongs_to :player`

**バリデーション**:
- `batting_order`: inclusion 1..9
- `position`: presence

---

### Manager

```ruby
class Manager < ApplicationRecord
```

**関連**:
- `has_many :team_managers, dependent: :destroy`
- `has_many :teams, through: :team_managers`

**enum**:
- `role`: `{ director: 0, coach: 1 }`

**バリデーション**:
- `name`: presence

---

### PitcherGameState

```ruby
class PitcherGameState < ApplicationRecord
  VALID_DECISIONS = %w[W L S H].freeze
```

**関連**:
- `belongs_to :game`
- `belongs_to :pitcher, class_name: "Player"` (FK: pitcher_id)
- `belongs_to :competition, optional: true`
- `belongs_to :team`

**バリデーション**:
- `pitcher_id`: uniqueness(scope: game_id)
- `role`: inclusion in %w[starter reliever opener]
- `result_category`: inclusion in %w[normal ko no_game long_loss], allow_nil
- `injury_check`: inclusion in %w[safe injured], allow_nil
- `earned_runs`: numericality >= 0
- `decision`: inclusion in VALID_DECISIONS + [nil]
- `is_opener`: inclusion in [true, false]
- `consecutive_short_rest_count`: numericality >= 0
- `pre_injury_days_excluded`: numericality >= 0

**クラスメソッド**:
- `PitcherGameState.calculate_result_category(role:, innings_pitched:, game_result:, pitchers_in_game:, fatigue_p: 0, decision: nil)` — result_category自動計算。先発で5イニング未満・後続あり・敗戦・L判定→"ko"、敗戦でイニング>疲労P+1→"long_loss"、試合なし→"no_game"、その他→"normal"

---

### PitchingStyle

```ruby
class PitchingStyle < ApplicationRecord
```

**関連**: (なし — player_cards から3種類のFK参照)

**バリデーション**:
- `name`: presence, uniqueness

---

### Player

```ruby
class Player < ApplicationRecord
```

選手マスタ。カード・チーム所属・コストとは独立して管理。

**関連**:
- `has_many :team_memberships, dependent: :destroy`
- `has_many :teams, through: :team_memberships`
- `has_many :cost_players, dependent: :destroy`
- `has_many :player_cards, dependent: :destroy`
- `has_many :at_bats_as_batter, class_name: "AtBat", foreign_key: :batter_id, dependent: :destroy, inverse_of: :batter`
- `has_many :at_bats_as_pitcher, class_name: "AtBat", foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher`
- `has_many :pitcher_game_states, foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher`
- `has_many :imported_stats, dependent: :destroy`

**バリデーション**:
- `name`: presence

---

### PlayerAbsence

```ruby
class PlayerAbsence < ApplicationRecord
```

**関連**:
- `belongs_to :team_membership`
- `belongs_to :season`

**enum**:
- `absence_type`: `{ injury: 0, suspension: 1, reconditioning: 2 }`

**バリデーション**:
- `absence_type`: presence
- `start_date`: presence
- `duration`: presence, integer > 0
- `duration_unit`: presence, inclusion in %w[days games]

**インスタンスメソッド**:
- `effective_end_date` — 離脱終了日を計算
  - `duration_unit == "days"`: `start_date + duration.days`
  - `duration_unit == "games"`: シーズンスケジュールからN試合後の翌日

---

### PlayerCard

```ruby
class PlayerCard < ApplicationRecord
```

選手カードデータ。Active Storageによるカード画像添付を持つ。

**Active Storage**:
- `has_one_attached :card_image` — カード画像ファイル

**関連**:
- `belongs_to :card_set`
- `belongs_to :player`
- `belongs_to :batting_style, optional: true`
- `belongs_to :pitching_style, optional: true`
- `belongs_to :pinch_pitching_style, class_name: "PitchingStyle", foreign_key: :pinch_pitching_style_id, optional: true`
- `belongs_to :catcher_pitching_style, class_name: "PitchingStyle", foreign_key: :catcher_pitching_style_id, optional: true`
- `has_many :player_card_player_types, dependent: :destroy`
- `has_many :player_types, through: :player_card_player_types`
- `has_many :competition_rosters, dependent: :destroy`
- `has_many :game_lineup_entries, dependent: :destroy`
- `has_many :player_card_defenses, dependent: :destroy`
- `has_many :player_card_traits, dependent: :destroy`
- `has_many :player_card_abilities, dependent: :destroy`
- `has_many :player_card_exclusive_catchers, dependent: :destroy`
- `has_many :exclusive_catchers, through: :player_card_exclusive_catchers, source: :catcher_player`
- `accepts_nested_attributes_for :player_card_defenses, allow_destroy: true`
- `accepts_nested_attributes_for :player_card_traits, allow_destroy: true`
- `accepts_nested_attributes_for :player_card_abilities, allow_destroy: true`

**バリデーション**:
- `card_set_id`, `player_id`: presence
- `card_type`: presence, inclusion in %w[pitcher batter]
- `card_set_id`: uniqueness(scope: [player_id, card_type])
- `speed`: presence, integer, 1..5
- `bunt`: presence, integer, 1..10
- `steal_start`: presence, integer, 1..22
- `steal_end`: presence, integer, 1..22
- `injury_rate`: presence, integer, 0..7
- `starter_stamina`: integer 4..9, allow_blank, unless: is_relief_only
- `relief_stamina`: integer 0..3, allow_blank
- `special_defense_c`: format `/\A[0-5][A-ES]\z/`, allow_blank
- `special_throwing_c`: presence if special_defense_c.present?
- `special_throwing_c`: integer -5..5, allow_blank

---

### PlayerCardAbility

```ruby
class PlayerCardAbility < ApplicationRecord
```

**関連**:
- `belongs_to :player_card`
- `belongs_to :ability_definition`
- `belongs_to :condition, class_name: "TraitCondition", optional: true`

---

### PlayerCardDefense

```ruby
class PlayerCardDefense < ApplicationRecord
```

**関連**:
- `belongs_to :player_card`
- `belongs_to :condition, class_name: "TraitCondition", optional: true`

**バリデーション**:
- `position`, `range_value`, `error_rank`: presence

---

### PlayerCardExclusiveCatcher

```ruby
class PlayerCardExclusiveCatcher < ApplicationRecord
  self.primary_key = [:player_card_id, :catcher_player_id]
```

複合主キーを持つ中間テーブル。

**関連**:
- `belongs_to :player_card`
- `belongs_to :catcher_player, class_name: "Player", foreign_key: :catcher_player_id`

---

### PlayerCardPlayerType

```ruby
class PlayerCardPlayerType < ApplicationRecord
```

**関連**:
- `belongs_to :player_card`
- `belongs_to :player_type`

**バリデーション**:
- `player_card_id`: uniqueness(scope: player_type_id)

---

### PlayerCardTrait

```ruby
class PlayerCardTrait < ApplicationRecord
```

**関連**:
- `belongs_to :player_card`
- `belongs_to :trait_definition`
- `belongs_to :condition, class_name: "TraitCondition", optional: true`

---

### PlayerType

```ruby
class PlayerType < ApplicationRecord
```

**関連**:
- `has_many :player_card_player_types, dependent: :restrict_with_error`
- `has_many :player_cards, through: :player_card_player_types`

**バリデーション**:
- `name`: presence, uniqueness

---

### Schedule

```ruby
class Schedule < ApplicationRecord
```

**関連**:
- `has_many :schedule_details, dependent: :destroy`

---

### ScheduleDetail

```ruby
class ScheduleDetail < ApplicationRecord
```

**関連**:
- `belongs_to :schedule`

**バリデーション**:
- `date`: presence
- `date_type`: presence

---

### Season

> **ルール正本**: `config/game_rules.yaml#season` — シーズン制約

```ruby
class Season < ApplicationRecord
```

1チーム1シーズン（game_rules.yaml#season.one_team_one_season）。

**関連**:
- `belongs_to :team`
- `belongs_to :key_player, class_name: "TeamMembership", optional: true`
- `has_many :season_schedules, dependent: :destroy`
- `has_many :player_absences, dependent: :destroy`

**バリデーション**:
- `name`: presence
- `team_id`: uniqueness (message: :season_already_started)

---

### SeasonRoster

```ruby
class SeasonRoster < ApplicationRecord
```

**関連**:
- `belongs_to :season`
- `belongs_to :team_membership`

**バリデーション**:
- `squad`: presence
- `registered_on`: presence

---

### SeasonSchedule

```ruby
class SeasonSchedule < ApplicationRecord
```

**関連**:
- `belongs_to :season`
- `belongs_to :announced_starter, class_name: "TeamMembership", optional: true`
- `belongs_to :opponent_team, class_name: "Team", optional: true`
- `belongs_to :winning_pitcher, class_name: "Player", optional: true`
- `belongs_to :losing_pitcher, class_name: "Player", optional: true`
- `belongs_to :save_pitcher, class_name: "Player", optional: true`

**バリデーション**:
- `home_away`: inclusion in ["home", "visitor"], allow_blank

**インスタンスメソッド**:
- `calculated_game_number` — 明示的なgame_numberがなければ該当日までの試合数から算出
- `game_result_hash` — 試合結果を `{ opponent_short_name:, score:, result: }` で返す

---

### SquadTextSetting

```ruby
class SquadTextSetting < ApplicationRecord
  BATTING_STATS_DEFAULTS = { "avg" => true, "hr" => true, "rbi" => true, ... }.freeze
  PITCHING_STATS_DEFAULTS = { "w_l" => true, "games" => true, "era" => true, ... }.freeze
```

**関連**:
- `belongs_to :team`

**コールバック**:
- `after_initialize :set_defaults` — batting_stats_config / pitching_stats_config にデフォルト値をマージ

---

### Stadium

```ruby
class Stadium < ApplicationRecord
```

**関連**:
- `has_many :games, dependent: :restrict_with_error`

**バリデーション**:
- `name`: presence, uniqueness
- `code`: presence, uniqueness

---

### Team

> **ルール正本**: `config/game_rules.yaml#team_composition` — コスト上限・外の世界枠・ロスター制限等

```ruby
class Team < ApplicationRecord
  COST_LIMIT_CONFIG = YAML.load_file(Rails.root.join("config", "cost_limits.yml")).freeze
  TEAM_TOTAL_MAX_COST = COST_LIMIT_CONFIG["team_total_max_cost"]  # → game_rules.yaml#team_composition.team_total_max_cost: 200
  OUTSIDE_WORLD_LIMIT = 4  # → game_rules.yaml#team_composition.outside_world_max: 4
  VALID_TEAM_TYPES = %w[normal hachinai].freeze
  NATIVE_SERIES = {
    "normal"   => %w[touhou].freeze,
    "hachinai" => %w[hachinai tamayomi].freeze
  }.freeze
```

**関連**:
- `belongs_to :user, optional: true`
- `has_one :season, dependent: :restrict_with_error`
- `has_many :team_memberships, dependent: :destroy`
- `has_many :players, through: :team_memberships`
- `has_many :competition_entries, dependent: :destroy`
- `has_many :competitions, through: :competition_entries`
- `has_many :home_games, class_name: "Game", foreign_key: :home_team_id, dependent: :destroy, inverse_of: :home_team`
- `has_many :visitor_games, class_name: "Game", foreign_key: :visitor_team_id, dependent: :destroy, inverse_of: :visitor_team`
- `has_many :pitcher_game_states, dependent: :destroy`
- `has_many :imported_stats, dependent: :destroy`
- `has_many :lineup_templates, dependent: :destroy`
- `has_one :squad_text_setting, dependent: :destroy`
- `has_one :game_lineup, dependent: :destroy`
- `has_many :team_managers, dependent: :destroy`
- `has_one :director_team_manager, -> { where(role: :director) }, class_name: "TeamManager", dependent: :destroy`
- `has_one :director, through: :director_team_manager, source: :manager`
- `has_many :coach_team_managers, -> { where(role: :coach) }, class_name: "TeamManager", dependent: :destroy`
- `has_many :coaches, through: :coach_team_managers, source: :manager`

**バリデーション**:
- `name`: presence
- `team_type`: inclusion in VALID_TEAM_TYPES

**インスタンスメソッド**:
- `has_season` — season.present? を返す（TopMenu UI判定用）
- `validate_team_total_cost(cost_list_id)` — チーム合計コスト上限チェック（TEAM_TOTAL_MAX_COST固定）
- `validate_outside_world_limit` — 外の世界枠4人以内チェック（NATIVE_SERIESでteam_typeに応じたネイティブ判定）
- `validate_outside_world_balance` — 外の世界枠4人時の投手/野手混在チェック（player_cards.card_typeで判定）
- `outside_world_first_squad_memberships` — 1軍の外の世界枠選手を返す（NATIVE_SERIES[team_type]以外がマッチ）

**クラスメソッド**:
- `Team.first_squad_cost_limit_for_count(count)` — 1軍人数に対応するコスト上限を返す
- `Team.first_squad_minimum_players` — 1軍最小人数を返す

---

### TeamManager

> **ルール正本**: `config/game_rules.yaml#manager` — 監督制約

```ruby
class TeamManager < ApplicationRecord
```

**関連**:
- `belongs_to :team`
- `belongs_to :manager`

**enum**:
- `role`: `{ director: 0, coach: 1 }`

**バリデーション**:
- `role`: presence
- `team_id`: uniqueness(scope: role, if: director?) — 監督は1チーム1人（game_rules.yaml#manager.one_director_per_team）
- カスタムvalidate: `manager_cannot_be_assigned_to_multiple_teams_in_same_league` — リーグ系テーブル廃止により無効化（cmd_511 Phase 3）

---

### TeamMembership

```ruby
class TeamMembership < ApplicationRecord
  attr_accessor :skip_commissioner_validation
```

**関連**:
- `belongs_to :team`
- `belongs_to :player`
- `belongs_to :player_card, optional: true`
- `has_many :season_rosters`
- `has_many :player_absences, dependent: :restrict_with_error`

**スコープ**:
- `included_in_team_total` — `excluded_from_team_total: false`
- `excluded_from_team_total` — `excluded_from_team_total: true`

**バリデーション**:
- `squad`: inclusion in %w[first second]
- `selected_cost_type`: presence, inclusion in %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost]
- カスタムvalidate: `player_not_in_director_sibling_team` (on: :create, unless: skip_commissioner_validation) — 同一監督の兄弟チーム間で選手重複を禁止（game_rules.yaml#team_composition.second_team.player_exclusivity）

---

### TraitCondition

```ruby
class TraitCondition < ApplicationRecord
```

**バリデーション**:
- `name`: presence, uniqueness

---

### TraitDefinition

```ruby
class TraitDefinition < ApplicationRecord
```

**特記事項**: カラム名は `typical_role`（`default_role` はRails 8の予約属性と競合するため回避）

**バリデーション**:
- `name`: presence, uniqueness

---

### User

```ruby
class User < ApplicationRecord
  has_secure_password
```

bcryptによるパスワード認証を使用。

**関連**:
- `has_many :teams, foreign_key: :user_id, dependent: :nullify`

**enum**:
- `role`: `{ player: 0, commissioner: 1 }`

**バリデーション**:
- `name`: presence, uniqueness
- `display_name`: presence

---

## Concerns

### BaseballCardValidations

```ruby
module BaseballCardValidations
  extend ActiveSupport::Concern
```

**ファイル**: `app/models/concerns/baseball_card_validations.rb`

**用途**: 選手カードの走力・バント・盗塁・怪我値バリデーションを共通化するConcern。

**バリデーション（included ブロック）**:
- `speed`: presence, integer, 1..5
- `bunt`: presence, integer, 1..10
- `steal_start`: presence, integer, 1..22
- `steal_end`: presence, integer, 1..22
- `injury_rate`: presence, integer, 0..7 (0=怪我特徴なし, 1-6=怪我レベル, 7=フルイニング)

**特記事項**: 現在PlayerCardモデルで同等のバリデーションが直接定義されており、このConcernの`include`は確認できない（バリデーションは重複して存在する可能性あり）。
