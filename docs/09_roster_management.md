# 09. ロースター管理（一軍/二軍入れ替え）

最終更新: 2026-02-21

## 概要

シーズン中の**一軍/二軍ロースター（Active Roster）管理**機能。選手の昇格・降格を記録し、昇格クールダウンルールを適用することで、戦略的なロースター運用を実現する。

### 主要機能
- **一軍/二軍振り分け**: 選手を `first`（一軍）/ `second`（二軍）に分類
- **昇格クールダウン**: 一軍→二軍降格後、10日間は再昇格不可（同日昇格＋降格は免除）
- **一軍制約ルール**: 人数上限（最大29人）、人数別コスト上限（段階制、設定ファイル駆動）、試合日の最小人数（25人）、外の世界枠上限（4人）
- **離脱選手管理**: 離脱中選手の昇格時に確認ダイアログを表示、再調整中選手は昇格不可
- **ロースター履歴管理**: 日付ごとの変更履歴を `season_rosters` テーブルで記録

---

## チーム登録画面との違い（重要）

**出場選手登録画面（ActiveRoster.vue）**と**チーム登録画面（TeamMembers.vue）**は似ているが、管理する概念と適用される制限が異なる。

| | チーム登録画面 | 出場選手登録画面 |
|---|------------|--------------|
| 目的 | チームの所属選手を管理 | 1軍/2軍のロースターを管理 |
| 概念 | 球団の保有選手 | 1軍出場登録 |
| 対象 | チーム全体 | 1軍メンバー |
| 制限 | チーム全体コスト上限（200）、全体人数制限 | 1軍人数別コスト上限（段階制）、外の世界枠、クールタイム |

**レイヤー構造**: 選手はまず**チームに所属**（`team_memberships`）し、その中から**1軍メンバーが選ばれる**（`season_rosters`）。この2層構造により、各画面の制限は独立して適用される。

詳細は `03_team_management.md` の「チーム登録画面と出場選手登録画面の違い」セクションを参照。

---

## 画面構成（フロントエンド）

### ActiveRoster.vue

**パス**: `thbigmatome-front/src/views/ActiveRoster.vue`

**主要UI要素**:

| セクション | 説明 |
|----------|------|
| ツールバー | `TeamNavigation` コンポーネント + 現在日表示（`primary` カラー） |
| キー選手選択 | シーズン開始日のみ有効。一軍選手から1名を選択（`selectedKeyPlayerId`） |
| 欠場情報 | `AbsenceInfo` コンポーネント（別仕様: 11_player_absence.md） |
| クールダウン情報 | `PromotionCooldownInfo` コンポーネント（後述） |
| 離脱終了間近通知 | 残り3日以内の離脱選手をアラート表示（`nearEndAbsencePlayers`） |
| 一軍制限サマリー | コスト上限超過警告、最小人数未達エラー、外の世界枠超過警告 |
| 一軍リスト | 左カラム。人数・コスト（上限表示付き）・選手タイプ集計・外の世界枠集計 |
| 二軍リスト | 右カラム。凡例（v-chip: クールダウン/負傷/出場停止/再調整）付き |
| 保存ボタン | ロースター変更をPOST送信 |
| 離脱中昇格確認ダイアログ | 離脱中選手を昇格する際の確認ダイアログ |

**一軍テーブルヘッダー**:
```typescript
// firstHeaders: 共通ヘッダー + 操作列（右端）
const headers = [
  { title: t('activeRoster.headers.number'), key: 'number' },
  { title: t('activeRoster.headers.name'), key: 'player_name' },
  { title: t('activeRoster.headers.player_types'), key: 'player_types' },
  { title: t('activeRoster.headers.position'), key: 'position' },
  { title: t('activeRoster.headers.throws'), key: 'throwing_hand' },
  { title: t('activeRoster.headers.bats'), key: 'batting_hand' },
  { title: t('activeRoster.headers.cost_type'), value: 'selected_cost_type' },
  { title: t('activeRoster.headers.cost'), key: 'cost' },
]
const firstHeaders = [...headers, { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' }]
```

**二軍テーブルヘッダー**:
```typescript
// secondHeaders: 操作列（左端）+ 共通ヘッダー
const secondHeaders = [
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
  ...headers,
]
```

**一軍テーブルの操作列**:

| 状態 | 表示 | 動作 |
|-----|------|------|
| キー選手 | `v-chip`（`deep-purple`、`mdi-lock` アイコン）「特例」 | 降格不可（ロック表示） |
| 離脱中（負傷/出場停止） | 降格ボタン（離脱種別ごとの色、`elevated` + `rounded`）+ ツールチップ | 降格可能 |
| 通常 | 降格ボタン（`blue-grey`、`elevated` + `rounded`） | 降格可能 |

**二軍テーブルの操作列**:

| 状態 | 表示 | 動作 |
|-----|------|------|
| 再調整中 | `v-chip`（`blue-grey`、`mdi-wrench` アイコン）「再調整中」 | 昇格不可 |
| クールダウン中 | `v-chip`（`amber`、`mdi-timer-sand` アイコン）「クールダウン」+ ツールチップ | 昇格不可 |
| 離脱中（負傷/出場停止） | 昇格ボタン（離脱種別ごとの色）+ ツールチップ | 昇格可能（確認ダイアログ表示） |
| 通常 | 昇格ボタン（`primary`、`elevated` + `rounded`） | 昇格可能 |

**二軍テーブルの凡例**（v-chip表示）:
```
クールダウン（amber, mdi-timer-sand）| 負傷（red, mdi-hospital-box）| 出場停止（orange, mdi-gavel）| 再調整中（blue-grey, mdi-wrench）
```

**行背景色の統一ルール**:

| 一軍テーブル | 二軍テーブル |
|-----------|-----------|
| キー選手: `bg-deep-purple-lighten-5` | クールダウン: `bg-amber-lighten-5`（優先） |
| 負傷: `bg-red-lighten-5` | 負傷: `bg-red-lighten-5` |
| 出場停止: `bg-orange-lighten-5` | 出場停止: `bg-orange-lighten-5` |
| 再調整: `bg-blue-grey-lighten-5` | 再調整: `bg-blue-grey-lighten-5` |

**主要コンピューテッド**:

```typescript
firstSquadPlayers = rosterPlayers.filter(p => p.squad === 'first')
secondSquadPlayers = rosterPlayers.filter(p => p.squad === 'second')
cooldownPlayers = rosterPlayers.filter(p => p.cooldown_until && now < new Date(p.cooldown_until))
firstSquadTotalCost = firstSquadPlayers.reduce((sum, player) => sum + player.cost, 0)
firstSquadCostLimit = COST_LIMIT_TIERS.find(t => count >= t.minPlayers)?.maxCost ?? null
outsideWorldFirstSquadCount = firstSquadPlayers.filter(p => p.is_outside_world).length
firstSquadPlayerTypeCounts = { [type]: count } // 一軍の選手タイプごとの人数
isSeasonStartDate = currentDate === seasonStartDate // キー選手設定可否
nearEndAbsencePlayers = rosterPlayers.filter(p => is_absent && remaining_days > 0 && remaining_days <= 3)
```

**一軍制限定数（フロントエンド）**:
```typescript
const MAX_FIRST_SQUAD_PLAYERS = 29
const FIRST_SQUAD_MIN_PLAYERS = 25
const OUTSIDE_WORLD_LIMIT = 4
const COST_LIMIT_TIERS = [
  { minPlayers: 28, maxCost: 120 },
  { minPlayers: 27, maxCost: 119 },
  { minPlayers: 26, maxCost: 117 },
  { minPlayers: 25, maxCost: 114 },
]
```

**主要メソッド**:

| メソッド | 説明 |
|---------|------|
| `fetchRoster()` | `GET /teams/:teamId/roster` — ロースターデータ取得（初期化時） |
| `handlePromotePlayer(player)` | 離脱中なら確認ダイアログ表示、通常なら即昇格 |
| `confirmPromoteAbsentPlayer()` | 確認ダイアログOK時に昇格実行 |
| `movePlayer(player, targetSquad)` | ローカル配列の `squad` フィールド更新（画面上の操作のみ） |
| `isPlayerOnCooldown(player)` | `cooldown_until` が現在日より未来かつ `same_day_exempt` でなければクールダウン中 |
| `isKeyPlayer(player)` | `selectedKeyPlayerId` と一致するか判定 |
| `getAbsenceColor(player)` | 離脱種別に応じた色を返す（injury→red, suspension→orange, reconditioning→blue-grey） |
| `getFirstSquadRowProps({item})` | 一軍テーブルの行背景色を返す |
| `getSecondSquadRowProps({item})` | 二軍テーブルの行背景色を返す（クールダウン優先） |
| `getCooldownTooltip(player)` | クールダウン終了日のツールチップテキスト |
| `getAbsenceDetailTooltip(player)` | 離脱詳細のツールチップ（日数単位/試合単位を区別） |
| `saveRoster()` | `POST /teams/:teamId/roster` — 全選手の状態を送信。失敗時にエラーメッセージ表示 |
| `saveKeyPlayer()` | `POST /teams/:teamId/key_player` — キー選手ID送信（別API） |

---

### PromotionCooldownInfo.vue

**パス**: `thbigmatome-front/src/components/PromotionCooldownInfo.vue`

**役割**: クールダウン中選手をアラート形式で表示（同日免除の表示にも対応）

**props**:
```typescript
{
  cooldownPlayers: RosterPlayer[];
  currentDate: string;
}
```

**表示内容**:
- クールダウン選手がいない場合: 「昇格制限中の選手はいません」（`primary` カラー）
- クールダウン選手がいる場合: 「〇〇: ◯月◯日まで昇格不可」（`orange-darken-3` カラー）
- **同日免除の場合**: `player.same_day_exempt === true` のとき、「同日昇格＋降格のため免除」旨の表示（`cooldownSameDayExempt` i18nキー使用）

**UIスタイル**:
- `v-alert` に `variant="tonal"` + `elevation="2"` + `density="compact"`
- `mdi-timer-sand` アイコン付き
- 現在日を括弧内に表示（`currentDateStr`）

---

## APIエンドポイント

### ルーティング

```ruby
# config/routes.rb:27
resource :roster, only: [:show, :create], controller: 'team_rosters'
```

チームスコープ内でシングルリソース扱い（チーム当たり1つのロースター）。

| メソッド | パス | アクション | 説明 |
|---------|------|----------|------|
| GET | `/teams/:team_id/roster` | `show` | 現在日時点のロースター取得 |
| POST | `/teams/:team_id/roster` | `create` | ロースター更新（昇格・降格） |

---

### GET /teams/:team_id/roster

**コントローラー**: `app/controllers/api/v1/team_rosters_controller.rb#show` (L4-63)

**処理フロー**:
1. チームのシーズンを取得（未初期化ならエラー）
2. `season.current_date` を `target_date` として使用
3. 全 `team_memberships` を preload（`season_rosters`, `player_absences`, `player` のコスト・タイプ含む）
4. 各選手について、`target_date` 以前の最新の `SeasonRoster` エントリを取得
   - 存在する場合: `latest_roster_entry.squad`
   - 存在しない場合: `team_membership.squad`（初期値）
5. クールダウン情報を計算（後述 `calculate_cooldown_info`）— 同日免除情報も含む
6. 離脱情報（`absence_info_for`）を算出して各選手データに含める
7. 外の世界枠フラグ（`is_outside_world`）を算出

**レスポンスJSON**:
```json
{
  "season_id": 123,
  "current_date": "2024-05-15",
  "season_start_date": "2024-05-01",
  "key_player_id": 456,
  "roster": [
    {
      "team_membership_id": 789,
      "player_id": 12,
      "number": "10",
      "player_name": "霊夢",
      "throwing_hand": "right",
      "batting_hand": "right",
      "squad": "first",
      "position": "投手",
      "player_types": ["先発", "リリーフ"],
      "selected_cost_type": "average_cost",
      "cost": 5,
      "cooldown_until": null,
      "same_day_exempt": false,
      "is_outside_world": false,
      "is_absent": false,
      "absence_info": null
    }
  ]
}
```

**エラーハンドリング**:
- `status: :not_found` — チーム/シーズン未存在
- `status: :bad_request` — 日付フォーマット不正

---

### POST /teams/:team_id/roster

**コントローラー**: `app/controllers/api/v1/team_rosters_controller.rb#create` (L65-142)

**リクエストボディ**:
```json
{
  "roster_updates": [
    { "team_membership_id": 789, "squad": "first" },
    { "team_membership_id": 790, "squad": "second" }
  ],
  "target_date": "2024-05-15"
}
```

**処理フロー（3フェーズ）**:

トランザクション内で全更新を実行:

**Phase 1: 個別選手の昇格/降格を適用**
1. `roster_updates` 配列をループ
2. 各選手について:
   - **一軍→二軍**: 常に許可。`team_membership.squad` を更新し `SeasonRoster` レコード作成
   - **二軍→一軍**:
     - 再調整中チェック: `absence_type == 'reconditioning'` なら昇格拒否
     - クールダウンチェック（`calculate_cooldown_info`）: **同日免除（`same_day_exempt`）** の場合はクールダウンを適用しない
     - 問題なければ `team_membership.squad` を更新し `SeasonRoster` レコード作成

**Phase 2: 一軍制約の最終チェック**
- 全変更適用後の一軍メンバーで `validate_first_squad_constraints` を実行

**Phase 3: 外の世界枠制約チェック**
- `team.validate_outside_world_limit` — 外の世界枠選手の一軍登録上限（4人）
- `team.validate_outside_world_balance` — 外の世界枠のバランス制約

**トランザクション後**:
- 離脱中選手が一軍に昇格された場合、警告メッセージを収集（`collect_absence_warnings`）

**レスポンスJSON**:
```json
{ "message": "Roster updated successfully", "warnings": [] }
```

**警告（warnings）の例**:
```json
{
  "warnings": [
    {
      "type": "player_absent",
      "player_id": 12,
      "player_name": "霊夢",
      "message": "霊夢は現在離脱中です（負傷）"
    }
  ]
}
```

**エラーハンドリング**:
- `status: :not_found` — チーム/選手未存在
- `status: :unprocessable_entity` — クールダウン違反、一軍制約違反、外の世界枠違反、再調整中昇格など

---

## データモデル

### season_rosters テーブル

**スキーマ**: `db/schema.rb:280-289`

```ruby
create_table "season_rosters", force: :cascade do |t|
  t.bigint "season_id", null: false
  t.bigint "team_membership_id", null: false
  t.string "squad", null: false
  t.date "registered_on", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["season_id"], name: "index_season_rosters_on_season_id"
  t.index ["team_membership_id"], name: "index_season_rosters_on_team_membership_id"
end
```

**カラム説明**:

| カラム | 型 | NULL | 説明 |
|-------|---|------|------|
| season_id | bigint | NO | シーズンID（外部キー） |
| team_membership_id | bigint | NO | チームメンバーシップID（外部キー） |
| squad | string | NO | `'first'`（一軍）または `'second'`（二軍） |
| registered_on | date | NO | この変更が有効になる日付 |
| created_at | datetime | NO | レコード作成日時 |
| updated_at | datetime | NO | レコード更新日時 |

**インデックス**:
- `season_id` — シーズン単位での検索
- `team_membership_id` — 選手ごとの履歴検索

---

### SeasonRoster モデル

**パス**: `app/models/season_roster.rb`

```ruby
class SeasonRoster < ApplicationRecord
  belongs_to :season
  belongs_to :team_membership

  validates :squad, presence: true
  validates :registered_on, presence: true
end
```

**リレーション**:
- `season`: シーズンに所属
- `team_membership`: チームメンバーシップに所属

**バリデーション**:
- `squad`: 必須（`'first'` または `'second'`）
- `registered_on`: 必須（適用日）

---

### RosterPlayerSerializer

**パス**: `app/serializers/roster_player_serializer.rb`

**シリアライズ対象**: `TeamMembership` オブジェクト

**出力属性**:
```ruby
attributes :team_membership_id, :player_id, :number, :player_name, :squad,
           :cooldown_until, :same_day_exempt, :cost, :selected_cost_type,
           :throwing_hand, :batting_hand
```

**カスタムメソッド**:

| メソッド | ソース | 説明 |
|---------|-------|------|
| `number` | `object.player.number` | 背番号 |
| `player_name` | `object.player.name` | 選手名 |
| `throwing_hand` | `object.player.throwing_hand` | 投球腕 |
| `batting_hand` | `object.player.batting_hand` | 打撃腕 |
| `cost` | `Cost.current_cost` + `object.selected_cost_type` | 現在コストリストから計算 |
| `selected_cost_type` | `object.selected_cost_type` | コストタイプ |
| `cooldown_until` | `cooldown_data[:cooldown_until]` | 一軍→二軍移動後10日間のクールダウン期限日（文字列） |
| `same_day_exempt` | `cooldown_data[:same_day_exempt]` | 同日昇格＋降格でクールダウン免除かどうか |

**クールダウン計算ロジック（`compute_cooldown_data` private メソッド）**:
1. 最新の二軍降格エントリ（`squad: 'second'`）を取得
2. その前の一軍昇格エントリ（`squad: 'first'`）を取得（同日の `created_at` 比較で順序判定）
3. `cooldown_end = 二軍降格日 + 10日`
4. `same_day_exempt = 昇格日 == 降格日` かどうかを判定
5. 結果を `{ cooldown_until, same_day_exempt }` として返す

**注意**: このシリアライザーは現在、`show` アクション内のインラインJSON構築に直接使われていない（コントローラーが直接ハッシュを構築している）。ただし同じクールダウンロジックが両方に存在する。

---

## ビジネスロジック

### 昇格・降格ルール

**実装箇所**: `team_rosters_controller.rb#create` (L80-132)

| 操作 | ルール | 実装 |
|-----|-------|------|
| 一軍 → 二軍 | 常に許可 | `team_membership.squad` 更新 + `SeasonRoster` 作成 |
| 二軍 → 一軍 | 再調整中チェック + クールダウンチェック（同日免除対応）+ 一軍制約チェック + 外の世界枠チェック | 以下参照 |

---

### クールダウン計算（同日免除対応）

**メソッド**: `calculate_cooldown_info(team_membership, current_date)` (L163-188)

**戻り値**: `{ cooldown_until: Date|nil, same_day_exempt: boolean }`

**ロジック**:
1. `team_membership.season_rosters` から `squad: 'second'` の最新エントリを取得（`registered_on DESC, created_at DESC`）
2. その前の一軍昇格エントリ（`squad: 'first'`）を取得。同日エントリは `created_at` で順序を判定
3. `cooldown_end_date = 二軍移動日 + 10.days`
4. `current_date < cooldown_end_date` でなければ `{ cooldown_until: nil, same_day_exempt: false }`
5. **同日免除判定**: 昇格日（`previous_promotion.registered_on`）と降格日（`last_demotion.registered_on`）が同じ日なら `same_day_exempt: true`

**クールダウン期間**: **10日間**

**同日免除ルール**: 同じ日に昇格と降格が行われた場合（例: 間違えて昇格→即日降格）、クールダウンは免除される。`same_day_exempt` が `true` の場合、フロントエンドはクールダウン表示を出すが昇格ボタンは有効のまま。

**エラーメッセージ**（同日免除でない場合のみ発生）:
```ruby
raise "Player #{team_membership.player.name} is on cooldown until #{cooldown_info[:cooldown_until]}"
```

---

### 一軍制約ルール

**メソッド**: `validate_first_squad_constraints(first_squad_memberships, target_date, season, season_start_date)` (L237-267)

**実行タイミング**: Phase 2（全選手の昇格/降格を適用した**後**に最終状態をチェック）

#### 基本ルール

| 制約 | 通常時 | 試合日 |
|-----|-------|--------|
| 最大人数 | 29人 | 29人 |
| 最小人数 | なし | **25人**（ただしシーズン初試合日の初期登録時は除外） |
| コスト上限 | 人数別段階制（設定ファイル駆動） | 同左 |

#### コスト上限（人数別段階制）

**実装**: `Team.first_squad_cost_limit_for_count(count)` — `config/cost_limits.yml` から読み込み

```ruby
# config/cost_limits.yml の first_squad_tiers に対応
# バックエンド: Team.first_squad_cost_limit_for_count(player_count)
# フロントエンド: COST_LIMIT_TIERS 定数
{ minPlayers: 28, maxCost: 120 }
{ minPlayers: 27, maxCost: 119 }
{ minPlayers: 26, maxCost: 117 }
{ minPlayers: 25, maxCost: 114 }
# 25人未満: null（登録禁止 — フロントエンドでエラー表示）
```

**背景**: 少人数編成でのコスト節約を防ぐため、25人編成時は最大114に制限。人数不足時は `null` を返し、コスト上限なしではなく登録不可を示す。

#### シーズン初試合日の特別処理

```ruby
is_first_game_day_of_season = is_game_day && (target_date == season_start_date)

if is_first_game_day_of_season && player_count < minimum_players
  # 初期登録中は最小人数チェックを免除
end
```

**理由**: シーズン開始直後のロースター構築中は、25人未満でも許可。

#### 外の世界枠制約（Phase 3）

**実装**: `team.validate_outside_world_limit` + `team.validate_outside_world_balance`

| 制約 | 値 | 説明 |
|-----|---|------|
| 外の世界枠上限 | 4人 | `Team::OUTSIDE_WORLD_LIMIT = 4` |
| 外の世界枠バランス | - | 4人登録時に二刀流選手比率をチェック |

---

### 一軍選手の取得（日付指定）

**メソッド**: `get_current_squad_for_date(team, squad_name, date)` (L130-142)

**ロジック**:
1. 全 `team_memberships` をループ
2. 各選手について `season_rosters` から `registered_on <= date` の最新エントリを取得
3. `latest_roster_entry.squad == squad_name` なら配列に追加
4. エントリがなければ `nil`

**用途**: `create` アクション内で、二軍→一軍昇格時に「現在の一軍メンバー + 昇格予定選手」の制約チェックに使用。

---

## フロントエンド実装詳細

### コンポーネント構成

```
ActiveRoster.vue (メインビュー)
├── TeamNavigation.vue (チーム共通ナビゲーション)
├── AbsenceInfo.vue (欠場情報 — 別仕様)
├── PromotionCooldownInfo.vue (クールダウン情報、同日免除対応)
├── v-alert (離脱終了間近通知)
├── v-alert ×3 (一軍制限サマリー: コスト超過/人数不足/外の世界枠超過)
├── v-data-table (一軍リスト: v-chip操作列、行背景色)
├── v-data-table (二軍リスト: v-chip凡例、v-chip操作列、行背景色)
└── v-dialog (離脱中選手の昇格確認ダイアログ)
```

---

### 型定義

**パス**: `thbigmatome-front/src/types/rosterPlayer.ts`

```typescript
export interface AbsenceInfo {
  absence_type: 'injury' | 'suspension' | 'reconditioning'
  reason: string | null
  effective_end_date: string | null
  remaining_days: number | null
  duration_unit: 'days' | 'games'
}

export interface RosterPlayer {
  team_membership_id: number
  player_id: number
  number: string
  player_name: string
  squad: 'first' | 'second'
  cost: number
  selected_cost_type: string
  position: string
  throwing_hand: string
  batting_hand: string
  player_types: string[]
  cooldown_until?: string
  same_day_exempt?: boolean
  is_outside_world?: boolean
  is_absent?: boolean
  absence_info?: AbsenceInfo | null
}
```

**フィールド説明**:
- `squad`: `'first'` または `'second'` のリテラル型
- `player_types`: 選手タイプの配列（`['先発', 'リリーフ']` など）
- `cooldown_until`: ISO8601文字列（例: `"2024-05-25"`）、クールダウンなしなら `undefined`
- `same_day_exempt`: 同日昇格＋降格でクールダウン免除の場合 `true`
- `is_outside_world`: 外の世界枠選手の場合 `true`
- `is_absent`: 現在離脱中の場合 `true`
- `absence_info`: 離脱詳細（種別、理由、終了日、残日数、期間単位）

---

### API呼び出しフロー

#### 初期化時 (onMounted)

```typescript
// ActiveRoster.vue:232-250
const fetchRoster = async () => {
  const response = await axios.get(`/teams/${teamId}/roster`);
  rosterPlayers.value = response.data.roster;
  seasonId.value = response.data.season_id;
  currentDate.value = new Date(response.data.current_date);
  seasonStartDate.value = new Date(response.data.season_start_date);
  selectedKeyPlayerId.value = response.data.key_player_id;
}
```

#### ロースター保存時

```typescript
const saveRoster = async () => {
  try {
    const updates = rosterPlayers.value.map(player => ({
      team_membership_id: player.team_membership_id,
      squad: player.squad,
    }))
    await axios.post(`/teams/${teamId}/roster`, {
      roster_updates: updates,
      target_date: currentDate.value.toISOString().split('T')[0],
    })
    alert(t('activeRoster.saveSuccess'))
    fetchRoster() // 再取得でクールダウン更新
  } catch (error: unknown) {
    const axiosError = error as { response?: { data?: { error?: string } }; message?: string }
    alert(`${t('activeRoster.saveFailed')}: ${axiosError.response?.data?.error || axiosError.message}`)
  }
}
```

**注意**:
- 保存成功後に `fetchRoster()` を再実行することで、サーバー側で計算された最新のクールダウン情報を取得
- **保存失敗時にサーバーのエラーメッセージを表示**（コスト超過、クールダウン違反など）

---

### 国際化キー

```typescript
// ActiveRoster.vue で使用されている i18n キー（抜粋）
t('activeRoster.title')
t('activeRoster.keyPlayerSelection')
t('activeRoster.saveKeyPlayer')
t('activeRoster.selectKeyPlayer')
t('activeRoster.selectKeyPlayerHint')
t('activeRoster.firstSquad')
t('activeRoster.secondSquad')
t('activeRoster.firstSquadCount')
t('activeRoster.firstSquadCost')
t('activeRoster.saveRoster')
t('activeRoster.saveSuccess')
t('activeRoster.saveFailed')
t('activeRoster.keyPlayerSaveSuccess')
t('activeRoster.keyPlayerSaveFailed')
t('activeRoster.headers.number')
t('activeRoster.headers.name')
t('activeRoster.headers.player_types')
t('activeRoster.headers.position')
t('activeRoster.headers.throws')
t('activeRoster.headers.bats')
t('activeRoster.headers.cost_type')
t('activeRoster.headers.cost')
t('activeRoster.headers.actions')
t('activeRoster.demoteButton')
t('activeRoster.promoteButton')
t('activeRoster.keyPlayerLocked')
t('activeRoster.chip.special')
t('activeRoster.chip.cooldown')
t('activeRoster.chip.reconditioning')
t('activeRoster.reconditioningBlocked')
t('activeRoster.legend.cooldown')
t('activeRoster.legend.injury')
t('activeRoster.legend.suspension')
t('activeRoster.legend.reconditioning')
t('activeRoster.cooldownInfo')
t('activeRoster.noCooldownInfo')
t('activeRoster.cooldownUntil', { date })
t('activeRoster.cooldownSameDayExempt', { date })
t('activeRoster.cooldownTooltip', { date })
t('activeRoster.absenceEndingSoon')
t('activeRoster.remainingDays', { days })
t('activeRoster.absenceDaysTooltip', { type, reason, days })
t('activeRoster.absenceGamesTooltip', { type, reason, days })
t('activeRoster.costLimitExceeded', { cost, limit })
t('activeRoster.belowMinimumPlayers', { min })
t('activeRoster.outsideWorldLimitExceeded', { count, limit })
t('activeRoster.outsideWorldCount', { count, max })
t('activeRoster.absenceWarning.title')
t('activeRoster.absenceWarning.message', { name, type, remaining })
t('activeRoster.absenceWarning.remaining', { days })
t('activeRoster.absenceWarning.unknownEnd')
t('seasonPortal.currentDate')
t('enums.player_absence.absence_type.{type}')
t('baseball.shortPositions.{position}')
t('baseball.throwingHands.{throwing_hand}')
t('baseball.battingHands.{batting_hand}')
t('baseball.construction.{selected_cost_type}')
t('actions.cancel')
t('actions.ok')
```

---

## 補足

### キー選手設定

**エンドポイント**: `POST /teams/:teamId/key_player`（別仕様）

**制約**: シーズン開始日（`isSeasonStartDate`）のみ設定可能。一軍選手から選択。

**UI**: キー選手は一軍テーブルで特別表示:
- 名前の横に `mdi-star` アイコン（`deep-purple`）
- 操作列に `v-chip`（`deep-purple`、`mdi-lock` アイコン）で降格不可を表示
- 行背景色 `bg-deep-purple-lighten-5`

---

### 選手タイプ集計

```typescript
const firstSquadPlayerTypeCounts = computed(() => {
  const counts: { [key: string]: number } = {}
  firstSquadPlayers.value.forEach(player => {
    player.player_types.forEach(type => {
      counts[type] = (counts[type] || 0) + 1
    })
  })
  return counts
})
```

**用途**: 一軍の選手構成（「先発: 5人、リリーフ: 3人」など）をUI上部に表示。外の世界枠カウント（`outsideWorldFirstSquadCount`）も並べて表示される。

---

### 離脱中選手の昇格確認ダイアログ

離脱中（`is_absent === true`）の二軍選手を昇格しようとすると、確認ダイアログ（`v-dialog`）が表示される。

**表示内容**:
- 選手名、離脱種別、残日数（または終了日不明の旨）
- キャンセルボタン / OKボタン

**実装**:
- `handlePromotePlayer(player)`: 離脱中なら `absenceConfirmDialog = true` でダイアログ表示
- `confirmPromoteAbsentPlayer()`: OKクリック時に `movePlayer()` で実際に昇格

**注意**: 再調整中（`reconditioning`）の選手は二軍テーブルで `v-chip` 表示となり、昇格ボタン自体が表示されない（バックエンドでも拒否される）。

---

### ボタンスタイリング

```css
.promote-btn, .demote-btn {
  transition: box-shadow 0.2s ease;
}
.promote-btn:hover:not(:disabled),
.demote-btn:hover:not(:disabled) {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3) !important;
}
```

昇格・降格ボタンは `variant="elevated"` + `rounded` で統一。ホバー時にシャドウが強くなるエフェクト付き。

---

### バックエンドの離脱関連メソッド

**`absence_info_for(team_membership, target_date)` (L191-215)**:
- `team_membership.player_absences` から `target_date` 時点でアクティブな離脱を検索
- 期間判定: `start_date <= target_date < effective_end_date`（`effective_end_date` が `nil` の場合は無期限離脱中）
- 戻り値: `{ is_absent: bool, absence_info: { absence_type, reason, effective_end_date, remaining_days, duration_unit } }`

**`collect_absence_warnings(team, target_date, roster_updates)` (L218-234)**:
- 一軍に昇格される選手のうち離脱中の選手を検出し、警告メッセージを生成
- レスポンスの `warnings` 配列に含まれる

---

## 参考: 関連仕様書

- `01_authentication.md` — 認証（ユーザー・ログイン）
- `03_team_management.md` — チーム管理（team_memberships）
- `08_season_management.md` — シーズン管理（season, season_schedules）
- `11_player_absence.md` — 選手欠場管理（AbsenceInfo コンポーネント）
