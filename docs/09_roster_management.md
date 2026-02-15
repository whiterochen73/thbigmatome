# 09. ロースター管理（一軍/二軍入れ替え）

最終更新: 2026-02-14

## 概要

シーズン中の**一軍/二軍ロースター（Active Roster）管理**機能。選手の昇格・降格を記録し、昇格クールダウンルールを適用することで、戦略的なロースター運用を実現する。

### 主要機能
- **一軍/二軍振り分け**: 選手を `first`（一軍）/ `second`（二軍）に分類
- **昇格クールダウン**: 一軍→二軍降格後、10日間は再昇格不可
- **一軍制約ルール**: 人数上限（最大29人）、コスト上限（最大120）、試合日の最小人数（25人）
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
| ツールバー | シーズンポータル・欠場履歴へのナビゲーション、現在日表示 |
| キー選手選択 | シーズン開始日のみ有効。一軍選手から1名を選択（`selectedKeyPlayerId`） |
| 欠場情報 | `AbsenceInfo` コンポーネント（別仕様: 11_player_absence.md） |
| クールダウン情報 | `PromotionCooldownInfo` コンポーネント（後述） |
| 一軍リスト | 左カラム。人数・コスト・選手タイプ集計、右矢印ボタン（→二軍降格） |
| 二軍リスト | 右カラム。左矢印ボタン（→一軍昇格） |
| 保存ボタン | ロースター変更をPOST送信 |

**一軍リスト表示項目**:
```typescript
// firstHeaders (ActiveRoster.vue:222-225)
[
  { title: '背番号', key: 'number' },
  { title: '名前', key: 'player_name' },
  { title: '選手タイプ', key: 'player_types' }, // v-chip配列
  { title: '守備', key: 'position' }, // i18n: baseball.shortPositions
  { title: '投', key: 'throwing_hand' },
  { title: '打', key: 'batting_hand' },
  { title: 'コストタイプ', value: 'selected_cost_type' },
  { title: 'コスト', key: 'cost' },
  { title: '操作', sortable: false, key: 'actions' }
]
```

**主要コンピューテッド**:

```typescript
// ActiveRoster.vue:252-283
firstSquadPlayers = rosterPlayers.filter(p => p.squad === 'first')
secondSquadPlayers = rosterPlayers.filter(p => p.squad === 'second')
cooldownPlayers = rosterPlayers.filter(p => now < new Date(p.cooldown_until))
firstSquadTotalCost = firstSquadPlayers.reduce((sum, player) => sum + player.cost, 0)
firstSquadPlayerTypeCounts = { [type]: count } // 一軍の選手タイプごとの人数
isSeasonStartDate = currentDate === seasonStartDate // キー選手設定可否
```

**主要メソッド**:

| メソッド | 説明 |
|---------|------|
| `fetchRoster()` | `GET /teams/:teamId/roster` — ロースターデータ取得（初期化時） |
| `movePlayer(player, targetSquad)` | ローカル配列の `squad` フィールド更新（画面上の操作のみ） |
| `isPlayerOnCooldown(player)` | `cooldown_until` が現在日より未来ならボタン無効化 |
| `saveRoster()` | `POST /teams/:teamId/roster` — 全選手の状態を送信 |
| `saveKeyPlayer()` | `POST /teams/:teamId/key_player` — キー選手ID送信（別API） |

---

### PromotionCooldownInfo.vue

**パス**: `thbigmatome-front/src/components/PromotionCooldownInfo.vue`

**役割**: クールダウン中選手をアラート形式で表示

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

**コントローラー**: `app/controllers/api/v1/team_rosters_controller.rb#show` (L4-58)

**処理フロー**:
1. チームのシーズンを取得（未初期化ならエラー）
2. `season.current_date` を `target_date` として使用
3. 全 `team_memberships` を preload（`season_rosters`, `player` のコスト・タイプ含む）
4. 各選手について、`target_date` 以前の最新の `SeasonRoster` エントリを取得
   - 存在する場合: `latest_roster_entry.squad`
   - 存在しない場合: `team_membership.squad`（初期値）
5. クールダウン日を計算（後述 `calculate_cooldown`）

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
      "cooldown_until": null
    }
  ]
}
```

**エラーハンドリング**:
- `status: :not_found` — チーム/シーズン未存在
- `status: :bad_request` — 日付フォーマット不正

---

### POST /teams/:team_id/roster

**コントローラー**: `app/controllers/api/v1/team_rosters_controller.rb#create` (L60-125)

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

**処理フロー**:
1. チームのシーズンを取得（未初期化ならエラー）
2. `roster_updates` 配列をループ
3. 各選手について:
   - **一軍→二軍**: 常に許可。`SeasonRoster` レコード作成
   - **二軍→一軍**:
     - クールダウンチェック（`calculate_cooldown`）
     - 一軍制約チェック（`validate_first_squad_constraints`）
     - 問題なければ `SeasonRoster` レコード作成
4. トランザクション内で全更新を実行

**レスポンスJSON**:
```json
{ "message": "Roster updated successfully" }
```

**エラーハンドリング**:
- `status: :not_found` — チーム/選手未存在
- `status: :unprocessable_entity` — クールダウン違反、一軍制約違反など

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
           :cooldown_until, :cost, :selected_cost_type,
           :throwing_hand, :batting_hand
```

**カスタムメソッド**:

| メソッド | ソース | 説明 |
|---------|-------|------|
| `number` | `object.player.number` | 背番号 |
| `player_name` | `object.player.name` | 選手名（※重複定義あり: L9は `short_name`, L25は `name`） |
| `throwing_hand` | `object.player.throwing_hand` | 投球腕 |
| `batting_hand` | `object.player.batting_hand` | 打撃腕 |
| `cost` | 現在コストリストから計算 | `object.player.cost_players` + `selected_cost_type` |
| `cooldown_until` | クールダウン計算（L38-57） | 一軍→二軍移動後10日間のクールダウン期限日（文字列） |

---

## ビジネスロジック

### 昇格・降格ルール

**実装箇所**: `team_rosters_controller.rb#create` (L81-116)

| 操作 | ルール | 実装 |
|-----|-------|------|
| 一軍 → 二軍 | 常に許可 | `SeasonRoster` 作成のみ |
| 二軍 → 一軍 | クールダウンチェック + 一軍制約チェック | 以下参照 |

---

### クールダウン計算

**メソッド**: `calculate_cooldown(team_membership, current_date)` (L145-163)

**ロジック**:
1. `team_membership.season_rosters` から `squad: 'second'` の最新エントリを取得
2. その1つ前のエントリが `squad: 'first'` であることを確認（一軍→二軍の移動）
3. `cooldown_end_date = 二軍移動日 + 10.days`
4. `current_date < cooldown_end_date` ならクールダウン期限日を返す
5. それ以外は `nil`

**クールダウン期間**: **10日間**

**エラーメッセージ**:
```ruby
raise "Player #{team_membership.player.name} is on cooldown until #{cooldown_until.to_s}"
```

---

### 一軍制約ルール

**メソッド**: `validate_first_squad_constraints(first_squad_memberships, target_date, season, season_start_date)` (L166-207)

#### 基本ルール

| 制約 | 通常時 | 試合日 |
|-----|-------|--------|
| 最大人数 | 29人 | 29人 |
| 最小人数 | なし | **25人**（ただしシーズン初試合日の初期登録時は除外） |
| コスト上限 | 120 | 人数に応じて変動 |

#### 試合日のコスト上限（特殊ルール）

**実装**: `team_rosters_controller.rb:192-197`

```ruby
max_cost = case player_count
           when 25 then 114
           when 26 then 117
           when 27 then 119
           else         120 # For 28, 29 players
           end
```

**背景**: 少人数編成でのコスト節約を防ぐため、25人編成時は最大114に制限。

#### シーズン初試合日の特別処理

**実装**: `team_rosters_controller.rb:177-186`

```ruby
is_first_game_day_of_season = is_game_day && (target_date == season_start_date)

if is_first_game_day_of_season && player_count < 25
  # 初期登録中は最小人数チェックを免除
end
```

**理由**: シーズン開始直後のロースター構築中は、25人未満でも許可。

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
├── AbsenceInfo.vue (欠場情報 — 別仕様)
├── PromotionCooldownInfo.vue (クールダウン情報)
└── (Vuetify v-data-table × 2)
```

---

### 型定義

**パス**: `thbigmatome-front/src/types/rosterPlayer.ts`

```typescript
export interface RosterPlayer {
  team_membership_id: number;
  player_id: number;
  number: string;
  player_name: string;
  squad: 'first' | 'second';
  cost: number;
  selected_cost_type: string;
  position: string;
  throwing_hand: string;
  batting_hand: string;
  player_types: string[];
  cooldown_until?: string;
}
```

**フィールド説明**:
- `squad`: `'first'` または `'second'` のリテラル型
- `player_types`: 選手タイプの配列（`['先発', 'リリーフ']` など）
- `cooldown_until`: ISO8601文字列（例: `"2024-05-25"`）、クールダウンなしなら `undefined`

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
// ActiveRoster.vue:309-325
const saveRoster = async () => {
  const updates = rosterPlayers.value.map(player => ({
    team_membership_id: player.team_membership_id,
    squad: player.squad
  }));
  await axios.post(`/teams/${teamId}/roster`, {
    roster_updates: updates,
    target_date: currentDate.value.toISOString().split('T')[0]
  });
  alert(t('activeRoster.saveSuccess'));
  fetchRoster(); // 再取得でクールダウン更新
}
```

**注意**: 保存成功後に `fetchRoster()` を再実行することで、サーバー側で計算された最新のクールダウン情報を取得。

---

### 国際化キー

```typescript
// ActiveRoster.vue で使用されている i18n キー（抜粋）
t('activeRoster.title')
t('activeRoster.keyPlayerSelection')
t('activeRoster.saveKeyPlayer')
t('activeRoster.firstSquad')
t('activeRoster.secondSquad')
t('activeRoster.saveRoster')
t('activeRoster.cooldownInfo')
t('activeRoster.noCooldownInfo')
t('activeRoster.cooldownUntil', { date: formattedCooldownDate })
t('baseball.shortPositions.{position}')
t('baseball.throwingHands.{throwing_hand}')
t('baseball.battingHands.{batting_hand}')
t('baseball.construction.{selected_cost_type}')
```

---

## 補足

### キー選手設定

**実装箇所**: `ActiveRoster.vue:327-337`

**エンドポイント**: `POST /teams/:teamId/key_player`（別仕様）

**制約**: シーズン開始日（`isSeasonStartDate`）のみ設定可能。一軍選手から選択。

---

### 選手タイプ集計

**実装箇所**: `ActiveRoster.vue:275-283`

```typescript
const firstSquadPlayerTypeCounts = computed(() => {
  const counts: { [key: string]: number } = {};
  firstSquadPlayers.value.forEach(player => {
    player.player_types.forEach(type => {
      counts[type] = (counts[type] || 0) + 1;
    });
  });
  return counts;
});
```

**用途**: 一軍の選手構成（「先発: 5人、リリーフ: 3人」など）をUI上部に表示。

---

### 既知の重複定義

**RosterPlayerSerializer**: `number` メソッドがL4とL12で重複定義、`player_name` メソッドがL8とL24で重複定義（`short_name` vs `name`）。現在の実装では後者（`name`）が有効。

---

## 参考: 関連仕様書

- `01_authentication.md` — 認証（ユーザー・ログイン）
- `03_team_management.md` — チーム管理（team_memberships）
- `08_season_management.md` — シーズン管理（season, season_schedules）
- `11_player_absence.md` — 選手欠場管理（AbsenceInfo コンポーネント）
