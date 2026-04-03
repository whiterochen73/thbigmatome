# シリアライザ仕様

最終更新日: 2026-04-01

## 参照ソースファイル

- `app/serializers/at_bat_serializer.rb`
- `app/serializers/card_set_serializer.rb`
- `app/serializers/competition_serializer.rb`
- `app/serializers/cost_player_serializer.rb`
- `app/serializers/cost_serializer.rb`
- `app/serializers/game_lineup_entry_serializer.rb`
- `app/serializers/game_serializer.rb`
- `app/serializers/manager_serializer.rb`
- `app/serializers/player_absence_serializer.rb`
- `app/serializers/player_card_detail_serializer.rb`
- `app/serializers/player_card_serializer.rb`
- `app/serializers/player_card_summary_serializer.rb`
- `app/serializers/player_detail_serializer.rb`
- `app/serializers/player_serializer.rb`
- `app/serializers/roster_player_serializer.rb`
- `app/serializers/schedule_serializer.rb`
- `app/serializers/season_detail_serializer.rb`
- `app/serializers/season_schedule_serializer.rb`
- `app/serializers/stadium_serializer.rb`
- `app/serializers/team_manager_serializer.rb`
- `app/serializers/team_membership_serializer.rb`
- `app/serializers/team_player_serializer.rb`
- `app/serializers/team_serializer.rb`

---

## 共通仕様

- フレームワーク: `ActiveModel::Serializer` (active_model_serializers gem)
- 基底クラス: `ActiveModel::Serializer`
- `TeamPlayerSerializer` のみ `PlayerSerializer` を継承（単一継承）

---

## シリアライザ一覧・詳細

### AtBatSerializer

**ファイル**: `app/serializers/at_bat_serializer.rb`

**使用箇所**: `GamesController#show`（GameSerializerのhas_many :at_bats経由）

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 打席ID |
| `game_id` | 試合ID |
| `inning` | イニング |
| `half` | 表/裏 |
| `seq` | 打席順序 |
| `batter_id` | 打者Player ID |
| `pitcher_id` | 投手Player ID |
| `result_code` | 結果コード (例: H, K, BB, HR) |
| `play_type` | プレイ種別 |
| `rolls` | ダイス結果 (JSONB配列) |
| `rbi` | 打点 |
| `runners` | 走者情報 |
| `runners_after` | 打席後走者情報 |
| `outs_after` | 打席後アウト数 |
| `scored` | 得点したか |

---

### CardSetSerializer

**ファイル**: `app/serializers/card_set_serializer.rb`

**使用箇所**:
- `CardSetsController#index`, `#show`
- `PlayerCardSummarySerializer` の `belongs_to :card_set`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | カードセットID |
| `year` | 年度 |
| `set_type` | セット種別 |
| `name` | セット名 |

---

### CompetitionSerializer

**ファイル**: `app/serializers/competition_serializer.rb`

**使用箇所**: `CompetitionsController#index`, `#show`, `#create`, `#update`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 大会ID |
| `name` | 大会名 |
| `year` | 開催年 |
| `competition_type` | 大会種別 |
| `entry_count` | 参加チーム数（computed） |

**computed属性の計算ロジック**:
- `entry_count`: `object.competition_entries.count` — 大会エントリー数をカウント

---

### CostPlayerSerializer

**ファイル**: `app/serializers/cost_player_serializer.rb`

**使用箇所**: `PlayerSerializer` の `has_many :cost_players`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | CostPlayer ID |
| `cost_id` | コストリストID |
| `player_id` | 選手ID |
| `normal_cost` | 通常コスト |
| `relief_only_cost` | リリーフ専用コスト |
| `pitcher_only_cost` | 投手専用コスト |
| `fielder_only_cost` | 野手専用コスト |
| `two_way_cost` | 二刀流コスト |

---

### CostSerializer

**ファイル**: `app/serializers/cost_serializer.rb`

**使用箇所**: `CostsController#index`, `#create`, `#update`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | コストリストID |
| `name` | コストリスト名 |
| `start_date` | 開始日 |
| `end_date` | 終了日 |

---

### GameLineupEntrySerializer

**ファイル**: `app/serializers/game_lineup_entry_serializer.rb`

**使用箇所**: `GameLineupEntriesController#show`, `#create`, `#update`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | エントリーID |
| `player_card_id` | 選手カードID |
| `player_id` | 選手ID（computed） |
| `player_name` | 選手名（computed） |
| `role` | 役割（starter/reliever等） |
| `batting_order` | 打順 |
| `position` | 守備位置 |
| `is_dh_pitcher` | DH投手フラグ |
| `is_reliever` | リリーフフラグ |

**computed属性の計算ロジック**:
- `player_name`: `object.player_card.player.name` — 関連PlayerCardからPlayer名を取得
- `player_id`: `object.player_card.player_id` — 関連PlayerCardからPlayer IDを取得

---

### GameSerializer

**ファイル**: `app/serializers/game_serializer.rb`

**使用箇所**: `GamesController#index`, `#show`, `#create`, `#confirm`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 試合ID |
| `competition_id` | 大会ID |
| `home_team_id` | ホームチームID |
| `visitor_team_id` | ビジターチームID |
| `real_date` | 試合実施日 |
| `status` | ステータス (draft/confirmed) |
| `source` | ソース種別 |
| `game_record_id` | 試合記録ID（computed） |

**ネスト関係**:
- `has_many :at_bats, serializer: AtBatSerializer` — 打席データ一覧

**computed属性の計算ロジック**:
- `game_record_id`: `object.game_record&.id` — 紐づくGameRecordのIDを返す（存在しない場合はnil）

---

### ManagerSerializer

**ファイル**: `app/serializers/manager_serializer.rb`

**使用箇所**: `ManagersController` では直接使用せず（`as_json`を使用）。`TeamSerializer` の `has_one :director`, `has_many :coaches` 経由で参照される可能性あり。

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 監督ID |
| `name` | 氏名 |
| `short_name` | 略称 |
| `irc_name` | IRC名 |
| `user_id` | ユーザーID |

**ネスト関係**:
- `has_many :teams` — 監督が担当するチーム一覧

---

### PlayerAbsenceSerializer

**ファイル**: `app/serializers/player_absence_serializer.rb`

**使用箇所**: `PlayerAbsencesController#index`, `#create`, `#update`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 欠場記録ID |
| `team_membership_id` | チームメンバーシップID |
| `season_id` | シーズンID |
| `absence_type` | 欠場種別 (injury/reconditioning等) |
| `reason` | 理由 |
| `start_date` | 開始日 |
| `duration` | 欠場期間 |
| `duration_unit` | 期間単位 |
| `player_name` | 選手名（computed） |
| `player_id` | 選手ID（computed） |
| `effective_end_date` | 実質終了日（computed、モデル側で計算） |

**computed属性の計算ロジック**:
- `player_name`: `object.team_membership.player.name` — TeamMembership経由でPlayer名を取得
- `player_id`: `object.team_membership.player_id` — TeamMembership経由でPlayer IDを取得

---

### PlayerCardDetailSerializer

**ファイル**: `app/serializers/player_card_detail_serializer.rb`

**使用箇所**: `PlayerCardsController#show`, `#update`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | カードID |
| `card_type` | カード種別 |
| `speed` | 走力 |
| `bunt` | バント |
| `steal_start` | 盗塁スタート |
| `steal_end` | 盗塁エンド |
| `injury_rate` | 怪我率 |
| `is_pitcher` | 投手フラグ |
| `is_relief_only` | リリーフ専用フラグ |
| `is_closer` | クローザーフラグ |
| `is_switch_hitter` | スイッチヒッターフラグ |
| `is_dual_wielder` | 二刀流フラグ |
| `starter_stamina` | 先発スタミナ |
| `relief_stamina` | リリーフスタミナ |
| `biorhythm_period` | バイオリズム周期 |
| `unique_traits` | 固有特性 |
| `injury_traits` | 怪我特性 |
| `batting_table` | 打撃テーブル (JSONB) |
| `pitching_table` | 投球テーブル (JSONB) |
| `handedness` | 利き手（computed） |
| `player` | 選手情報（computed） |
| `card_set` | カードセット情報（computed） |
| `defenses` | 守備能力一覧（computed） |
| `trait_list` | 特性一覧（computed） |
| `ability_list` | 能力一覧（computed） |
| `cost` | コスト（computed） |
| `image_url` | カード画像URL（computed） |

**computed属性の計算ロジック**:
- `handedness`: `object.handedness` — PlayerCardモデルのhandedness属性（モデル側に計算ロジックあり）
- `player`: `{ id: object.player.id, name: object.player.name, number: object.player.number }` — 基本選手情報
- `card_set`: `{ id: object.card_set.id, name: object.card_set.name }` — カードセット基本情報
- `defenses`: `object.player_card_defenses.order(:position).map { ... }` — 守備位置・レンジ値・エラーランク・送球を配列で返す
- `trait_list`: `object.player_card_traits.includes(:trait_definition, :condition).order(:sort_order).map { ... }` — 特性定義・条件込みの一覧
- `ability_list`: `object.player_card_abilities.includes(:ability_definition, :condition).order(:sort_order).map { ... }` — 能力定義・条件込みの一覧
- `cost`: `object.player.cost_players.max_by(&:cost_id)&.normal_cost` — 最新コストリストの通常コスト
- `image_url`: ActiveStorage添付があれば `rails_blob_url`、なければnil

---

### PlayerCardSerializer

**ファイル**: `app/serializers/player_card_serializer.rb`

**使用箇所**: `PlayerCardsController#index`（`each_serializer: PlayerCardSerializer`）

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | カードID |
| `card_set_id` | カードセットID |
| `player_id` | 選手ID |
| `card_type` | カード種別 |
| `speed` | 走力 |
| `bunt` | バント |
| `steal_start` | 盗塁スタート |
| `steal_end` | 盗塁エンド |
| `injury_rate` | 怪我率 |
| `is_pitcher` | 投手フラグ |
| `is_relief_only` | リリーフ専用フラグ |
| `starter_stamina` | 先発スタミナ |
| `relief_stamina` | リリーフスタミナ |
| `batting_style_id` | 打撃スタイルID |
| `pitching_style_id` | 投球スタイルID |
| `pinch_pitching_style_id` | ピンチ時投球スタイルID |
| `catcher_pitching_style_id` | 捕手時投球スタイルID |
| `pitching_style_description` | 投球スタイル説明 |
| `special_defense_c` | 守備特殊能力C |
| `special_throwing_c` | 送球特殊能力C |
| `batting_table` | 打撃テーブル (JSONB) |
| `pitching_table` | 投球テーブル (JSONB) |
| `player_name` | 選手名（computed） |
| `player_number` | 選手背番号（computed） |
| `card_set_name` | カードセット名（computed） |
| `primary_position` | 主守備位置（computed） |
| `cost` | コスト（computed） |
| `image_url` | カード画像URL（computed） |

**computed属性の計算ロジック**:
- `player_name`: `object.player.name`
- `player_number`: `object.player.number`
- `card_set_name`: `object.card_set.name`
- `primary_position`: `object.player_card_defenses.first&.position` — 最初の守備定義の守備位置
- `cost`: `object.player.cost_players.max_by(&:cost_id)&.normal_cost` — 最新コストリストの通常コスト
- `image_url`: ActiveStorage添付があれば `rails_blob_url`、なければnil

---

### PlayerCardSummarySerializer

**ファイル**: `app/serializers/player_card_summary_serializer.rb`

**使用箇所**: `PlayerDetailSerializer` の `has_many :player_cards`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | カードID |
| `card_type` | カード種別 |
| `handedness` | 利き手 |
| `speed` | 走力 |
| `bunt` | バント |
| `injury_rate` | 怪我率 |
| `is_pitcher` | 投手フラグ |
| `is_relief_only` | リリーフ専用フラグ |
| `starter_stamina` | 先発スタミナ |
| `relief_stamina` | リリーフスタミナ |

**ネスト関係**:
- `belongs_to :card_set` — カードセット情報（CardSetSerializerで展開）

---

### PlayerDetailSerializer

**ファイル**: `app/serializers/player_detail_serializer.rb`

**使用箇所**: `PlayersController#index`, `#show`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 選手ID |
| `name` | 選手名 |
| `short_name` | 略称 |
| `number` | 背番号 |
| `series` | 作品シリーズ |
| `costs` | コスト情報一覧（computed） |

**ネスト関係**:
- `has_many :player_cards, serializer: PlayerCardSummarySerializer` — 保有カード一覧（サマリー形式）

**computed属性の計算ロジック**:
- `costs`: `object.cost_players.includes(:cost)` から各コスト情報（cost_name, normal_cost, pitcher_only_cost, fielder_only_cost, relief_only_cost, two_way_cost）の配列を返す

---

### PlayerSerializer

**ファイル**: `app/serializers/player_serializer.rb`

**使用箇所**:
- `TeamRegistrationPlayersController#index`
- `TeamPlayerSerializer` の基底クラス

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 選手ID |
| `name` | 選手名 |
| `number` | 背番号 |
| `short_name` | 略称 |
| `handedness` | 利き手（computed） |
| `position` | ポジション（computed） |

**ネスト関係**:
- `has_many :cost_players, serializer: CostPlayerSerializer` — コスト情報一覧

**computed属性の計算ロジック**:
- `handedness`: `object.player_cards.first&.handedness` — 最初のPlayerCardのhandedness属性
- `position`: pitcherカードがあれば"pitcher"、なければ最初のカードの守備位置(downcase)

---

### RosterPlayerSerializer

**ファイル**: `app/serializers/roster_player_serializer.rb`

**使用箇所**: 現在コントローラで直接使用されていない（TeamRostersControllerは手動でハッシュ構築）。定義のみ存在。

**属性**:

| 属性 | 説明 |
|------|------|
| `team_membership_id` | チームメンバーシップID |
| `player_id` | 選手ID |
| `number` | 背番号（computed） |
| `player_name` | 選手名（computed） |
| `squad` | 所属 (first/second) |
| `cooldown_until` | クールダウン終了日（computed） |
| `same_day_exempt` | 当日免除フラグ（computed） |
| `cost` | コスト（computed） |
| `selected_cost_type` | 選択コスト種別 |
| `handedness` | 利き手（computed） |

**computed属性の計算ロジック**:
- `number`: `object.player.number`
- `player_name`: `object.player.name`
- `handedness`: `object.player.player_cards.first&.handedness`
- `cost`: `Cost.current_cost` を取得し、`object.player.cost_players` から `cost_id` で一致するレコードを見つけて `selected_cost_type` で指定されたコスト種別の値を返す
- `cooldown_until` / `same_day_exempt`: `compute_cooldown_data` メソッドで計算
  - 最後の2軍降格日(`last_demotion`)を取得
  - 降格前の最後の1軍昇格日(`previous_promotion`)を取得
  - `cooldown_end = last_demotion.registered_on + 10.days`
  - `same_day_exempt = previous_promotion.registered_on == last_demotion.registered_on`（同日昇格・降格は免除）

---

### ScheduleSerializer

**ファイル**: `app/serializers/schedule_serializer.rb`

**使用箇所**: 現在コントローラでは直接使用されていない（`SchedulesController` は `render json: schedules` で生のJSONを返す）

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | スケジュールID |
| `name` | スケジュール名 |
| `start_date` | 開始日 |
| `end_date` | 終了日 |
| `effective_date` | 有効日 |

---

### SeasonDetailSerializer

**ファイル**: `app/serializers/season_detail_serializer.rb`

**使用箇所**: `TeamSeasonsController#show`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | シーズンID |
| `name` | シーズン名 |
| `current_date` | 現在日付 |
| `start_date` | シーズン開始日（computed） |
| `end_date` | シーズン終了日（computed） |
| `key_player_id` | 特例選手のTeamMembership ID |
| `key_player_name` | 特例選手名（computed） |

**ネスト関係**:
- `has_many :season_schedules, serializer: SeasonScheduleSerializer` — 全試合スケジュール一覧

**computed属性の計算ロジック**:
- `start_date`: `object.season_schedules.minimum(:date)` — シーズンスケジュールの最小日付
- `end_date`: `object.season_schedules.maximum(:date)` — シーズンスケジュールの最大日付
- `key_player_name`: `object.key_player&.player&.name` — 特例選手のPlayer名

---

### SeasonScheduleSerializer

**ファイル**: `app/serializers/season_schedule_serializer.rb`

**使用箇所**: `SeasonDetailSerializer` の `has_many :season_schedules`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | シーズンスケジュールID |
| `date` | 日付 |
| `date_type` | 日付種別 (game_day/off_day等) |
| `announced_starter` | 先発予告（computed） |
| `game_result` | 試合結果（computed） |

**computed属性の計算ロジック**:
- `announced_starter`: `announced_starter_id` が存在する場合、`object.announced_starter` (PlayerCard) から Player を取得して `{ id, name }` を返す。存在しなければnil
- `game_result`: `object.game_result_hash` — モデルのメソッドを呼び出す

---

### StadiumSerializer

**ファイル**: `app/serializers/stadium_serializer.rb`

**使用箇所**: `StadiumsController#index`, `#show`, `#create`, `#update`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | 球場ID |
| `code` | 球場コード |
| `name` | 球場名 |
| `up_table_ids` | UPテーブルID一覧 |
| `indoor` | 屋内フラグ |

---

### TeamManagerSerializer

**ファイル**: `app/serializers/team_manager_serializer.rb`

**使用箇所**: `TeamSerializer` の `has_one :director`, `has_many :coaches` 経由（暗黙的に利用）

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | TeamManager ID |
| `team_id` | チームID |
| `manager_id` | 監督ID |
| `role` | 役割 (director/coach) |

**ネスト関係**:
- `belongs_to :manager` — 監督情報（ManagerSerializerで展開）

---

### TeamMembershipSerializer

**ファイル**: `app/serializers/team_membership_serializer.rb`

**使用箇所**: 現在コントローラでは直接使用されていない（`TeamMembershipsController` は手動でハッシュを返す）

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | チームメンバーシップID |
| `team_id` | チームID |
| `player_id` | 選手ID |
| `player_card_id` | 選手カードID |
| `squad` | 所属 (first/second) |
| `selected_cost_type` | 選択コスト種別 |
| `excluded_from_team_total` | チーム合計除外フラグ |
| `display_name` | 表示名 |
| `player_card_info` | 選手カード情報（computed） |

**ネスト関係**:
- `belongs_to :player` — 選手情報（PlayerSerializerで展開）

**computed属性の計算ロジック**:
- `player_card_info`: player_card が存在する場合 `{ id, card_type, card_set_name, card_set_id }` を返す。なければ null

---

### TeamPlayerSerializer

**ファイル**: `app/serializers/team_player_serializer.rb`

**継承**: `PlayerSerializer` を継承

**使用箇所**: `TeamPlayersController#index`（`each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id`）

**追加属性**（PlayerSerializerの属性に加えて）:

| 属性 | 説明 |
|------|------|
| `selected_cost_type` | チームの選択コスト種別（computed） |
| `current_cost` | 現在のコスト値（computed） |
| `excluded_from_team_total` | チーム合計除外フラグ（computed） |
| `display_name` | 表示名（computed） |
| `player_card_id` | 選手カードID（computed） |
| `player_card_info` | 選手カード情報（computed） |

**computed属性の計算ロジック**:
- `selected_cost_type`: `membership.selected_cost_type` — オプションで渡されたチームのメンバーシップから取得
- `current_cost`: `object.cost_players.find_by(cost_id: @instance_options[:cost_list_id])&.send(cost_type)` — コストリストIDから該当CostPlayerを取得し、selected_cost_typeに応じた値を返す
- `excluded_from_team_total`: `membership.excluded_from_team_total`
- `display_name`: `membership.display_name`
- `player_card_id`: `membership.player_card_id`
- `player_card_info`: player_card が存在する場合 `{ id, card_type, card_set_name, card_set_id }` を返す。なければ null

**注意**: `@instance_options` でコントローラから `team:` と `cost_list_id:` を受け取る。`membership` はteam_idで該当TeamMembershipを検索

---

### TeamSerializer

**ファイル**: `app/serializers/team_serializer.rb`

**使用箇所**:
- `TeamsController#index`, `#show`, `#create`, `#update`
- `CompetitionsController#teams`

**属性**:

| 属性 | 説明 |
|------|------|
| `id` | チームID |
| `name` | チーム名 |
| `short_name` | 略称 |
| `is_active` | 有効フラグ |
| `has_season` | シーズン作成済みフラグ（computed） |
| `user_id` | オーナーユーザーID |

**ネスト関係**:
- `has_one :director` — 監督（TeamManagerSerializer経由）
- `has_many :coaches` — コーチ陣（TeamManagerSerializer経由）

**computed属性の計算ロジック**:
- `has_season`: `object.season.present?` — 関連するSeasonが存在すればtrue

---

## シリアライザ継承・委譲関係

```
ActiveModel::Serializer
├── AtBatSerializer
├── CardSetSerializer
├── CompetitionSerializer
├── CostPlayerSerializer
├── CostSerializer
├── GameLineupEntrySerializer
├── GameSerializer
│   └── has_many :at_bats → AtBatSerializer
├── ManagerSerializer
│   └── has_many :teams
├── PlayerAbsenceSerializer
├── PlayerCardDetailSerializer
├── PlayerCardSerializer
├── PlayerCardSummarySerializer
│   └── belongs_to :card_set → CardSetSerializer
├── PlayerDetailSerializer
│   └── has_many :player_cards → PlayerCardSummarySerializer
├── PlayerSerializer
│   └── has_many :cost_players → CostPlayerSerializer
│   └── TeamPlayerSerializer (継承)
│       ※ instance_optionsでteam/cost_list_idを受け取る
├── RosterPlayerSerializer
├── ScheduleSerializer
├── SeasonDetailSerializer
│   └── has_many :season_schedules → SeasonScheduleSerializer
├── SeasonScheduleSerializer
├── StadiumSerializer
├── TeamManagerSerializer
│   └── belongs_to :manager → ManagerSerializer
├── TeamMembershipSerializer
│   └── belongs_to :player → PlayerSerializer
└── TeamSerializer
    ├── has_one :director → TeamManagerSerializer
    └── has_many :coaches → TeamManagerSerializer
```

---

## 使用箇所クロスリファレンス

| シリアライザ | コントローラ#アクション |
|-------------|----------------------|
| AtBatSerializer | GamesController#show, #index（GameSerializer経由） |
| CardSetSerializer | CardSetsController#index, #show; PlayerCardSummarySerializer経由 |
| CompetitionSerializer | CompetitionsController#index, #show, #create, #update |
| CostPlayerSerializer | PlayerSerializer経由（TeamRegistrationPlayersController#index） |
| CostSerializer | CostsController#index, #create, #update |
| GameLineupEntrySerializer | GameLineupEntriesController#show, #create, #update |
| GameSerializer | GamesController#index, #show, #create, #confirm, #import_log |
| PlayerAbsenceSerializer | PlayerAbsencesController#index, #create, #update |
| PlayerCardDetailSerializer | PlayerCardsController#show, #update |
| PlayerCardSerializer | PlayerCardsController#index |
| PlayerCardSummarySerializer | PlayerDetailSerializer経由（PlayersController#index, #show） |
| PlayerDetailSerializer | PlayersController#index, #show |
| PlayerSerializer | TeamRegistrationPlayersController#index |
| TeamPlayerSerializer | TeamPlayersController#index |
| SeasonDetailSerializer | TeamSeasonsController#show |
| SeasonScheduleSerializer | SeasonDetailSerializer経由 |
| StadiumSerializer | StadiumsController#index, #show, #create, #update |
| TeamSerializer | TeamsController#index, #show, #create, #update; CompetitionsController#teams |

**注**: 以下のシリアライザは定義はあるがコントローラで直接使用されていない（手動ハッシュ構築に切り替わっている）:
- RosterPlayerSerializer（TeamRostersControllerは手動ハッシュを返す）
- ScheduleSerializer（SchedulesControllerは `render json:` をそのまま使用）
- TeamMembershipSerializer（TeamMembershipsControllerは手動ハッシュを返す）
- ManagerSerializer（ManagersControllerは `as_json` を使用、showは `include: :teams`）
- TeamManagerSerializer（TeamSerializerから暗黙的に使用）
