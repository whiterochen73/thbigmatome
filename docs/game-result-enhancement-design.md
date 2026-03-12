# 試合結果入力画面拡張 設計書

## cmd_535 / 作成: 2026-03-11 / 更新: 2026-03-12 (cmd_537) / 作成者: 軍師マキノ

---

## 1. 現状調査

### 1.1 既存の2つのデータフロー

現在、試合データには**2つの並行するフロー**が存在する:

| フロー | 入口 | DB | 用途 |
|--------|------|-----|------|
| **手入力フロー** | GameResult.vue → `PUT /game/:id` | `season_schedules` (JSONB) | スコアボード・基本情報・勝敗投手 |
| **パーサーフロー** | GamesController → `import_log` | `games` + `game_records` + `at_bats` | 打席詳細・打撃/投球成績集計 |

**問題**: `PitcherGameState` は `games` テーブルに紐づく（`belongs_to :game`）が、
手入力フローは `season_schedules` のみを使用しており `games` レコードを作成しない。
→ 投手起用データを記録するには、両フローを統合する必要がある。

### 1.2 既存で使えるもの

| リソース | 状態 | 備考 |
|----------|------|------|
| `PitcherGameState` モデル | **テーブル・モデルあり** | role, innings_pitched, earned_runs, fatigue_p_used, cumulative_innings, decision, injury_check, result_category, schedule_date |
| `Game` モデル | **テーブル・モデルあり** | has_many :pitcher_game_states |
| `GameRecord` モデル | **テーブル・モデルあり** | batting_stats, pitching_stats (JSONB)。confirm時に集計 |
| `PlayerAbsence` モデル | **テーブル・モデル・CRUD APIあり** | injury/suspension/reconditioning, duration + duration_unit |
| `GamesController` | **parse_log / import_log あり** | パーサー連携の入口 |
| `PitchingStatsCalculator` | **サービスあり** | competition単位の投球成績集計 |
| `GameResult.vue` | **基本情報+スコアボード** | 投手起用・負傷入力なし |
| `ScoreSheet.vue` | **スタメン登録+打撃記録枠** | 打撃記録保存未実装 |

### 1.3 不足しているもの

| 不足 | 影響 |
|------|------|
| `PitcherGameStatesController` (API) | 投手起用の CRUD 不可 |
| `season_schedules` → `games` のリンク | 手入力で PitcherGameState を作れない |
| 累積疲労計算サービス | 休養ルールに基づく疲労計算不可 |
| GameResult.vue 投手起用セクション | FE入力UIなし |
| GameResult.vue 負傷セクション | FE負傷記録UIなし |
| confirm フローでの PitcherGameState 生成 | 確定時に投手データが永続化されない |
| `imported_stats` / `pitcher_game_states` FEエンドポイント | FEが呼ぶAPI未実装 |

### 1.4 PitcherGameState 既存フィールド

```
pitcher_game_states テーブル:
├── game_id (FK → games, NOT NULL)
├── pitcher_id (FK → players, NOT NULL)  ※ UNIQUE(game_id, pitcher_id)
├── competition_id (FK → competitions, NOT NULL)
├── team_id (FK → teams, NOT NULL)
├── role (string, NOT NULL)  ← starter | reliever | opener
├── innings_pitched (decimal 5,1)
├── earned_runs (integer, default: 0)
├── fatigue_p_used (integer, default: 0)
├── cumulative_innings (integer, default: 0)
├── decision (string, nullable)  ← W | L | S | H
├── injury_check (string, nullable)  ← safe | injured
├── result_category (string, nullable)  ← normal | ko | no_game | long_loss
└── schedule_date (string)
```

**不足フィールド**（追加が必要）:

| フィールド | 型 | 用途 |
|-----------|-----|------|
| `entry_order` | integer | 投手起用順（1=先発, 2=2番手, ...） |
| `inherited_runners` | integer | 引き継ぎ走者数 |
| `inherited_runners_scored` | integer | 引き継ぎ走者の得点数 |

**投手詳細記録フィールド**（追加が必要）:

| フィールド | 型 | 用途 | 備考 |
|-----------|-----|------|------|
| `strikeouts` | integer, default: 0 | 奪三振 | |
| `walks` | integer, default: 0 | 四球 | |
| `hit_by_pitches` | integer, default: 0 | 死球 | |
| `hits_allowed` | integer, default: 0 | 被安打 | |
| `home_runs_allowed` | integer, default: 0 | 被本塁打 | |
| `wild_pitches` | integer, default: 0 | 暴投 | |
| `balks` | integer, default: 0 | ボーク | |
| `runs_allowed` | integer, default: 0 | 失点 | 既存 `earned_runs`（自責点）とは別 |
| `batters_faced` | integer, default: 0 | 対戦打者数 | ダイスゲームのため投球数は不要。打者数で代替 |

※ `cumulative_innings` は**登板後の累積**を格納する想定（登板前はAPIレスポンスで算出）。

### 1.5 守備記録テーブル設計（新規: FielderGameState）

試合ごとの各選手の守備成績を記録するテーブル。投手起用（PitcherGameState）とは独立。

```
fielder_game_states テーブル（新規作成）:
├── game_id (FK → games, NOT NULL)
├── player_id (FK → players, NOT NULL)
├── competition_id (FK → competitions, NOT NULL)
├── team_id (FK → teams, NOT NULL)
├── position (string, NOT NULL)      ← C / 1B / 2B / 3B / SS / LF / CF / RF / DH / P
├── putouts (integer, default: 0)    ← 刺殺
├── assists (integer, default: 0)    ← 補殺
├── errors (integer, default: 0)     ← 失策
├── schedule_date (string)
├── created_at
└── updated_at
```

**インデックス設計**:
- `UNIQUE(game_id, player_id, position)` — 同一試合・同一選手・同一ポジションの重複防止（守備位置変更で複数レコード可）
- `INDEX(game_id)` — 試合単位取得用
- `INDEX(player_id)` — 選手単位取得用
- `INDEX(competition_id)` — 大会単位集計用

**モデルバリデーション**:
```ruby
class FielderGameState < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :competition
  belongs_to :team

  VALID_POSITIONS = %w[C 1B 2B 3B SS LF CF RF DH P].freeze

  validates :player_id, uniqueness: { scope: [:game_id, :position] }
  validates :position, inclusion: { in: VALID_POSITIONS }
  validates :putouts, :assists, :errors,
            numericality: { greater_than_or_equal_to: 0 }
end
```

**設計判断**:
- 1試合で複数ポジションを守る場合（守備位置変更）は、ポジションごとに別レコードを作成
- DH は守備なし（putouts/assists/errors = 0）だが起用記録として保持
- P（投手）の守備記録もここに記録（PitcherGameState は投球成績、FielderGameState は守備成績と責務分離）

---

## 2. 設計方針: 2フロー統合

### 2.1 統合アプローチ

`season_schedules` に `game_id` カラムを追加し、手入力フローでも `Game` レコードを作成する。

```
season_schedules ←──(game_id)──→ games ──→ pitcher_game_states
                                       ──→ game_records
                                       ──→ at_bats
```

**手入力時のフロー変更**:
1. GameResult.vue で投手起用データを入力
2. 保存時に `Game` レコードを自動作成（`source: "manual"`）
3. `PitcherGameState` を Game に紐づけて保存
4. `season_schedule.game_id` に Game.id を設定

**パーサーフロー**: 変更なし（import_log で Game を作成し、後から season_schedule.game_id に紐づけ）

### 2.2 手入力 vs パーサーの併用方針

| 項目 | 手入力 | パーサー |
|------|--------|---------|
| スコアボード | ✅ 主たる入力方法 | ✅ 自動取得可 |
| 投手起用 | ✅ UIから入力 | ✅ パーサーから自動生成 |
| 打席詳細 | ❌（ScoreSheetに将来委譲） | ✅ 自動取得 |
| 累積疲労 | ✅ 登板履歴から自動計算 | ✅ 同様 |
| 負傷チェック | ✅ UIから記録 | △ パーサーではUP表から検出可能だが確度低い |

**原則**: パーサーで取れるものはパーサー優先、手入力で補正可能。
confirm前はdraft状態で編集可能。

---

## 3. フェーズ分割

### Phase A: 投手起用入力 + API基盤

**目標**: GameResult.vueに投手起用セクションを追加し、PitcherGameStateのCRUDを実装

#### Phase A-1: DB・モデル・API

**マイグレーション**:
```ruby
# season_schedules に game_id を追加
add_reference :season_schedules, :game, foreign_key: true, null: true

# pitcher_game_states にフィールド追加（起用管理）
add_column :pitcher_game_states, :entry_order, :integer
add_column :pitcher_game_states, :inherited_runners, :integer, default: 0
add_column :pitcher_game_states, :inherited_runners_scored, :integer, default: 0

# pitcher_game_states に詳細記録フィールド追加
add_column :pitcher_game_states, :strikeouts, :integer, default: 0
add_column :pitcher_game_states, :walks, :integer, default: 0
add_column :pitcher_game_states, :hit_by_pitches, :integer, default: 0
add_column :pitcher_game_states, :hits_allowed, :integer, default: 0
add_column :pitcher_game_states, :home_runs_allowed, :integer, default: 0
add_column :pitcher_game_states, :wild_pitches, :integer, default: 0
add_column :pitcher_game_states, :balks, :integer, default: 0
add_column :pitcher_game_states, :runs_allowed, :integer, default: 0
add_column :pitcher_game_states, :batters_faced, :integer, default: 0

# fielder_game_states テーブル新規作成（守備記録）
create_table :fielder_game_states do |t|
  t.references :game, null: false, foreign_key: true
  t.references :player, null: false, foreign_key: true
  t.references :competition, null: false, foreign_key: true
  t.references :team, null: false, foreign_key: true
  t.string :position, null: false
  t.integer :putouts, default: 0, null: false
  t.integer :assists, default: 0, null: false
  t.integer :errors, default: 0, null: false
  t.string :schedule_date
  t.timestamps
end
add_index :fielder_game_states, [:game_id, :player_id, :position],
          unique: true, name: "idx_fielder_game_states_unique"
```

**ルーティング**:
```ruby
# config/routes.rb
resources :games do
  resources :pitcher_game_states, only: [:index, :create, :update, :destroy]
  resources :fielder_game_states, only: [:index, :create, :update, :destroy]
  # ...既存
end
```

**PitcherGameStatesController API設計**:

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/v1/games/:game_id/pitcher_game_states` | 試合の全投手起用取得 |
| POST | `/api/v1/games/:game_id/pitcher_game_states` | 投手起用追加 |
| PUT | `/api/v1/games/:game_id/pitcher_game_states/:id` | 投手起用更新 |
| DELETE | `/api/v1/games/:game_id/pitcher_game_states/:id` | 投手起用削除 |

**GET レスポンス（PitcherGameStates）**:
```json
{
  "pitcher_game_states": [
    {
      "id": 1,
      "pitcher_id": 42,
      "pitcher_name": "博麗霊夢",
      "role": "starter",
      "entry_order": 1,
      "innings_pitched": 7.0,
      "earned_runs": 2,
      "runs_allowed": 3,
      "strikeouts": 8,
      "walks": 2,
      "hit_by_pitches": 0,
      "hits_allowed": 5,
      "home_runs_allowed": 1,
      "wild_pitches": 0,
      "balks": 0,
      "batters_faced": 28,
      "fatigue_p_used": 7,
      "cumulative_innings": 0,
      "decision": "W",
      "result_category": "normal",
      "injury_check": null,
      "inherited_runners": 0,
      "inherited_runners_scored": 0,
      "schedule_date": "2026-05-15"
    }
  ]
}
```

**POST リクエスト（PitcherGameState）**:
```json
{
  "pitcher_game_state": {
    "pitcher_id": 42,
    "role": "starter",
    "entry_order": 1,
    "innings_pitched": 7.0,
    "earned_runs": 2,
    "runs_allowed": 3,
    "strikeouts": 8,
    "walks": 2,
    "hit_by_pitches": 0,
    "hits_allowed": 5,
    "home_runs_allowed": 1,
    "wild_pitches": 0,
    "balks": 0,
    "batters_faced": 28,
    "fatigue_p_used": 7,
    "decision": "W",
    "result_category": "normal",
    "schedule_date": "2026-05-15"
  }
}
```

**FielderGameStatesController API設計**:

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/v1/games/:game_id/fielder_game_states` | 試合の全守備記録取得 |
| POST | `/api/v1/games/:game_id/fielder_game_states` | 守備記録追加 |
| PUT | `/api/v1/games/:game_id/fielder_game_states/:id` | 守備記録更新 |
| DELETE | `/api/v1/games/:game_id/fielder_game_states/:id` | 守備記録削除 |

**GET レスポンス（FielderGameStates）**:
```json
{
  "fielder_game_states": [
    {
      "id": 1,
      "player_id": 42,
      "player_name": "博麗霊夢",
      "position": "P",
      "putouts": 0,
      "assists": 3,
      "errors": 0,
      "schedule_date": "2026-05-15"
    },
    {
      "id": 2,
      "player_id": 55,
      "player_name": "紅美鈴",
      "position": "1B",
      "putouts": 9,
      "assists": 1,
      "errors": 0,
      "schedule_date": "2026-05-15"
    }
  ]
}
```

**POST リクエスト（FielderGameState）**:
```json
{
  "fielder_game_state": {
    "player_id": 55,
    "position": "1B",
    "putouts": 9,
    "assists": 1,
    "errors": 0,
    "schedule_date": "2026-05-15"
  }
}
```

#### Phase A-2: FE 投手起用セクション

**GameResult.vue に追加するセクション**:

```
┌─────────────────────────────────────────────────────────────┐
│ 投手起用                                              [＋追加] │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ # │ 投手名   │ 役割   │ 投球回│ 自責点│ 疲労P│ 判定│ 操作│ │
│ │ 1 │ 博麗霊夢 │ 先発   │ 7.0  │  2   │  7  │ ○  │ ✏🗑│ │
│ │ 2 │ 霧雨魔理沙│ 中継ぎ │ 1.0  │  0   │  0  │    │ ✏🗑│ │
│ │ 3 │ 十六夜咲夜│ 中継ぎ │ 1.0  │  0   │  1  │ S  │ ✏🗑│ │
│ └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**UIフロー**:
1. [＋追加] ボタンでダイアログ表示
2. 投手選択（TeamMemberSelect）、役割（starter/reliever/opener）、投球回数、自責点、疲労P使用値、判定（W/L/S/H/なし）を入力
3. result_category は投球回数と判定から自動判別（KO: 4.2以下+L、long_loss: fatigue_p+1超+L）
4. 保存 → `POST /api/v1/games/:game_id/pitcher_game_states`
5. entry_order は自動採番（既存の最大値+1）

**投手詳細記録入力ダイアログ**:

ダイアログを「基本情報」タブと「詳細記録」タブの2タブ構成にする。

```
┌─────────────── 投手起用登録 ───────────────────────┐
│ [基本情報]  [詳細記録]                              │
│                                                    │
│ ── 詳細記録タブ ──                                 │
│ 奪三振 [  8 ]  四球  [  2 ]  死球  [  0 ]         │
│ 被安打 [  5 ]  被本塁打 [ 1 ]                      │
│ 失点   [  3 ]  暴投  [  0 ]  ボーク [  0 ]        │
│ 対戦打者数 [ 28 ]                                  │
│                                                    │
│              [キャンセル]  [保存]                    │
└────────────────────────────────────────────────────┘
```

- 基本情報タブ: 投手選択、役割、投球回、自責点、疲労P、判定（既存設計通り）
- 詳細記録タブ: 奪三振/四球/死球/被安打/被本塁打/失点/暴投/ボーク/対戦打者数
- 詳細記録は全て任意入力（default: 0）。パーサー連携時は自動入力される
- テーブル表示にも詳細記録カラムを追加（横スクロール or 折り畳み対応）

**投手起用テーブル（詳細表示モード）**:
```
┌────────────────────────────────────────────────────────────────────────────────┐
│ 投手起用                                                          [＋追加]    │
│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│ │ # │ 投手名   │ 役割 │ 回 │自責│失点│ K │BB│死│被安│被HR│暴投│打者│判定│操作│ │
│ │ 1 │ 博麗霊夢 │ S    │7.0 │ 2 │ 3 │ 8 │ 2│ 0│  5 │  1 │  0 │ 28│ ○ │✏🗑│ │
│ │ 2 │ 霧雨魔理沙│ R   │1.0 │ 0 │ 0 │ 1 │ 0│ 0│  1 │  0 │  0 │  4│   │✏🗑│ │
│ │ 3 │ 十六夜咲夜│ R   │1.0 │ 0 │ 0 │ 2 │ 1│ 0│  0 │  0 │  0 │  4│ S │✏🗑│ │
│ └────────────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────┘
```

**守備記録セクション（GameResult.vue 新規追加）**:
```
┌────────────────────────────────────────────────────────────────────┐
│ 守備記録                                                 [＋追加] │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ 選手名       │ 守備位置 │ 刺殺 │ 補殺 │ 失策 │ 操作        │   │
│ │ 博麗霊夢     │ P       │   0  │   3  │   0  │ ✏🗑         │   │
│ │ 紅美鈴       │ 1B      │   9  │   1  │   0  │ ✏🗑         │   │
│ │ アリス       │ 2B      │   3  │   4  │   1  │ ✏🗑         │   │
│ │ ...          │         │      │      │      │             │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                          合計: 刺殺 27 / 補殺 12 / 失策 1         │
└────────────────────────────────────────────────────────────────────┘
```

**守備記録UIフロー**:
1. [＋追加] ボタンでダイアログ表示
2. 選手選択（TeamMemberSelect）、守備位置（ドロップダウン: C/1B/2B/3B/SS/LF/CF/RF/DH/P）
3. 刺殺・補殺・失策を入力（数値、default: 0）
4. 保存 → `POST /api/v1/games/:game_id/fielder_game_states`
5. 同一選手が守備位置変更した場合、ポジションごとに別行で表示
6. 合計行でチーム全体の刺殺/補殺/失策を表示（刺殺合計=27でアウト数一致チェック可能）

**Game自動作成フロー（手入力時）**:
- GameResult.vue の保存時に投手起用データがある場合:
  1. `season_schedule.game_id` が null → `POST /api/v1/games` で Game 作成（source: "manual"）
  2. season_schedule.game_id を更新
  3. PitcherGameState を新 Game に紐づけて保存

---

### Phase B: 累積疲労計算 + 登板履歴

**目標**: 投手休養ルールに基づく累積疲労の自動計算、登板履歴表示

#### Phase B-1: CumulativeFatigueCalculator サービス

**入力**:
- pitcher_id
- team_id
- competition_id
- current_schedule_date（今回の試合日）

**処理**:
1. 該当投手の直近の PitcherGameState を時系列で取得
2. PlayerAbsence で負傷期間を取得
3. 前回登板からの中日数を計算（**負傷期間を除外**）
4. 前回登板の種別（先発/リリーフ/オープナー）と結果分類を参照
5. 投手休養ルール4パターンで利用可能な疲労P を算出:

```ruby
class CumulativeFatigueCalculator
  # @param pitcher_id [Integer]
  # @param team_id [Integer]
  # @param competition_id [Integer]
  # @param schedule_date [Date] 今回の試合日
  # @param player_card [PlayerCard] 疲労P情報のソース
  # @return [Hash] {
  #   available_fatigue_p: Integer,     # 利用可能な疲労P
  #   rest_days: Integer,               # 中日数（負傷除外後）
  #   cumulative_innings: Integer,       # 現在の累積イニング（リリーフ用）
  #   last_role: String,                # 前回登板種別
  #   last_result_category: String,     # 前回登板結果分類
  #   injury_check_required: Boolean,   # 負傷チェック必要か
  #   injury_check_reason: String|nil,  # 負傷チェック理由
  #   injury_level: Integer|nil,        # 負傷チェック時の怪我レベル
  #   restrictions: [String],           # 制限事項
  # }
  def calculate
    # ...
  end
end
```

**累積イニング減少ルール**（リリーフ→リリーフ）:
```
累積3以下: 休養1日あたり -2
累積4以上: 休養1日あたり -1
最小値: 0
```

**負傷チェック発動条件**:
| 条件 | 怪我レベル |
|------|----------|
| 連続の先発中4日登板 | 2 |
| 疲労P0で先発登板 | 2 |
| 累積3イニング以上での登板 | 累積4→5, 累積5→4, 累積6→3, 累積7+→2 |
| オープナー負傷条件 | 2 |

#### Phase B-2: 登板履歴API

**エンドポイント**:
```
GET /api/v1/teams/:team_id/pitcher_history?competition_id=X&pitcher_id=Y
```

**レスポンス**:
```json
{
  "pitcher_id": 42,
  "pitcher_name": "博麗霊夢",
  "card_fatigue_p": { "starter": 7, "reliever": 2 },
  "is_slash_player": true,
  "history": [
    {
      "schedule_date": "2026-05-15",
      "role": "starter",
      "innings_pitched": 7.0,
      "result_category": "normal",
      "decision": "W",
      "fatigue_p_used": 7,
      "cumulative_innings_after": 0
    },
    {
      "schedule_date": "2026-05-10",
      "role": "reliever",
      "innings_pitched": 2.0,
      "result_category": null,
      "decision": "H",
      "fatigue_p_used": 0,
      "cumulative_innings_after": 2
    }
  ],
  "current_status": {
    "rest_days": 3,
    "cumulative_innings": 0,
    "available_fatigue_p": 4,
    "injury_check_required": false,
    "restrictions": []
  }
}
```

#### Phase B-3: FE 登板履歴・疲労表示

**GameResult.vue 投手起用セクションに追加**:
- 投手選択時に登板履歴ポップオーバー表示
- 「前回登板: 5/10 リリーフ 2.0回」「中3日」「利用可能疲労P: 4」
- 負傷チェック必要な場合は ⚠️ 警告表示

**SeasonPortal.vue 投手状況ウィジェット（将来）**:
- 各投手の累積イニング・次回登板可能日・疲労P一覧

---

### Phase C: 負傷管理

**目標**: 試合中の負傷記録と PlayerAbsence への連携

#### Phase C-1: 負傷記録セクション（GameResult.vue）

```
┌─────────────────────────────────────────────────────────────┐
│ 負傷・離脱                                            [＋追加] │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ 選手名     │ 種別       │ 日数/試合数│ 原因         │ 操作│ │
│ │ 博麗霊夢   │ 負傷(怪我) │ 5日      │ UP表負傷     │ ✏🗑│ │
│ │ 霧雨魔理沙 │ 負傷(怪我) │ 3試合    │ 負傷チェック │ ✏🗑│ │
│ └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### Phase C-2: 負傷チェック処理

**投手起用セクションとの連携**:
1. PitcherGameState 保存時に CumulativeFatigueCalculator で負傷チェック条件を判定
2. 条件該当時: 「負傷チェックが必要です」アラート表示
3. ユーザーが 1d20 の結果を入力（6以下で負傷）
4. 負傷時:
   - `pitcher_game_state.injury_check = 'injured'` に更新
   - 怪我レベルに応じた PlayerAbsence レコード自動生成
   - 負傷セクションに自動追加

**API**: 既存の `POST /api/v1/player_absences` を使用（追加実装不要）

#### Phase C-3: 負傷チェック自動判定

```ruby
# PitcherGameState 保存後のコールバック
after_save :check_injury_conditions

def check_injury_conditions
  calc = CumulativeFatigueCalculator.new(...)
  result = calc.calculate
  if result[:injury_check_required]
    # FEに injury_check_required: true を返す
    # FEがダイス結果入力UIを表示
  end
end
```

---

### Phase D: パーサー連携

**目標**: import_log フローで PitcherGameState を自動生成

#### Phase D-1: パーサー出力拡張

thbig-irc-parser の `parse_game_full` 出力に投手起用データ・守備記録データを追加:

```json
{
  "pregame_info": { ... },
  "at_bats": { ... },
  "pitcher_usage": [
    {
      "pitcher_name": "博麗霊夢",
      "role": "starter",
      "entry_order": 1,
      "innings_pitched": 7.0,
      "earned_runs": 2,
      "runs_allowed": 3,
      "strikeouts": 8,
      "walks": 2,
      "hit_by_pitches": 0,
      "hits_allowed": 5,
      "home_runs_allowed": 1,
      "wild_pitches": 0,
      "balks": 0,
      "batters_faced": 28,
      "decision": "W"
    }
  ],
  "fielding_stats": [
    {
      "player_name": "博麗霊夢",
      "position": "P",
      "putouts": 0,
      "assists": 3,
      "errors": 0
    },
    {
      "player_name": "紅美鈴",
      "position": "1B",
      "putouts": 9,
      "assists": 1,
      "errors": 0
    }
  ]
}
```

**投手詳細記録のパーサー抽出方針**:
- `strikeouts`: AtBatRecords の結果が三振（見逃し/空振り）のカウント
- `walks`: AtBatRecords の結果が四球のカウント
- `hit_by_pitches`: AtBatRecords の結果が死球のカウント
- `hits_allowed`: AtBatRecords の結果が安打（単打/二塁打/三塁打/本塁打）のカウント
- `home_runs_allowed`: AtBatRecords の結果が本塁打のカウント
- `wild_pitches`: ダイスイベントの暴投カウント（既存パーサーで検出済み）
- `balks`: ダイスイベントのボークカウント
- `runs_allowed`: イニングスコアから各投手の責任失点を逆算
- `batters_faced`: 各投手が対戦した打者の数（途中交代含む）

**守備記録のパーサー抽出方針**:
- `putouts` / `assists` / `errors`: IRC試合ログからの抽出は**精度に課題がある**
  - IRCログにはアウトの詳細（誰が刺殺/補殺か）が記録されないケースが多い
  - 失策はUP表のダイス結果から検出可能だが、守備位置との対応は曖昧
- **推奨方針**: 守備記録はPhase Dでは**手入力を主体**とする
  - パーサーからは `fielding_stats` を出力するが、精度注記付き（`confidence: "low"`）
  - FEではパーサー出力を「参考値」として表示し、手動確認・修正を促す
  - 失策のみUP表から高精度で抽出可能なため、失策だけパーサー値を信頼度高で表示

※ パーサーの `pitcher_usage` 抽出は既存の `pitching_stats` 集計ロジック
（GameRecordsController#calculate_game_stats）を参考に、
AtBatRecords のイニング・投手変遷から算出可能。

#### Phase D-2: import_log での PitcherGameState 自動生成

```ruby
# GamesController#import_log 内 transaction に追加

# 投手起用データ（詳細記録含む）
if result["pitcher_usage"].present?
  result["pitcher_usage"].each do |pu|
    pitcher = Player.find_by(name: pu["pitcher_name"])
    next unless pitcher
    game.pitcher_game_states.create!(
      pitcher: pitcher,
      competition_id: params[:competition_id],
      team_id: params[:home_team_id],  # or visitor
      role: pu["role"],
      entry_order: pu["entry_order"],
      innings_pitched: pu["innings_pitched"],
      earned_runs: pu["earned_runs"] || 0,
      runs_allowed: pu["runs_allowed"] || 0,
      strikeouts: pu["strikeouts"] || 0,
      walks: pu["walks"] || 0,
      hit_by_pitches: pu["hit_by_pitches"] || 0,
      hits_allowed: pu["hits_allowed"] || 0,
      home_runs_allowed: pu["home_runs_allowed"] || 0,
      wild_pitches: pu["wild_pitches"] || 0,
      balks: pu["balks"] || 0,
      batters_faced: pu["batters_faced"] || 0,
      decision: pu["decision"],
      schedule_date: params[:real_date],
      # fatigue_p_used, cumulative_innings は CumulativeFatigueCalculator で後付け
      fatigue_p_used: 0,
      cumulative_innings: 0
    )
  end
end

# 守備記録データ
if result["fielding_stats"].present?
  result["fielding_stats"].each do |fs|
    player = Player.find_by(name: fs["player_name"])
    next unless player
    game.fielder_game_states.create!(
      player: player,
      competition_id: params[:competition_id],
      team_id: params[:home_team_id],  # or visitor
      position: fs["position"],
      putouts: fs["putouts"] || 0,
      assists: fs["assists"] || 0,
      errors: fs["errors"] || 0,
      schedule_date: params[:real_date]
    )
  end
end
```

#### Phase D-3: confirm 時の疲労計算

GameRecordsController#confirm（または GamesController#confirm）で:
1. Game の PitcherGameStates を取得
2. 各投手に対して CumulativeFatigueCalculator を実行
3. `fatigue_p_used`, `cumulative_innings`, `result_category` を更新
4. 負傷チェック条件の自動判定結果を返却

---

## 4. 依存関係とフェーズ順序

```
Phase A-1 (DB・API基盤)
    ↓
Phase A-2 (FE投手起用) ──→ Phase B-1 (疲労計算サービス)
                                  ↓
                            Phase B-2 (登板履歴API)
                                  ↓
                            Phase B-3 (FE疲労表示) ──→ Phase C (負傷管理)
                                                              ↓
                                                        Phase D (パーサー連携)
```

**Phase A は独立して着手可能**。Phase B は Phase A の API に依存。
Phase C は Phase B の疲労計算に依存（負傷チェック条件判定のため）。
Phase D は Phase A の API + Phase B のサービスが前提。

---

## 5. 実装見積もり（サブタスク粒度）

| Phase | サブタスク | Bloom Level |
|-------|----------|-------------|
| A-1 | マイグレーション（PitcherGameState拡張 + FielderGameState新規） + season_schedules.game_id | L3 |
| A-1 | PitcherGameStatesController（詳細記録フィールド含む） | L3 |
| A-1 | FielderGameStatesController | L3 |
| A-1 | Game自動作成ロジック | L3 |
| A-2 | GameResult.vue 投手起用セクション（詳細記録タブ含む） | L4 |
| A-2 | GameResult.vue 守備記録セクション | L4 |
| B-1 | CumulativeFatigueCalculator サービス | L5 |
| B-1 | 投手休養ルール4パターン + オープナー実装 | L5 |
| B-2 | 登板履歴API | L3 |
| B-3 | FE 疲労表示 + 登板履歴ポップオーバー | L4 |
| C-1 | GameResult.vue 負傷セクション | L3 |
| C-2 | 負傷チェック処理 + PlayerAbsence連携 | L4 |
| D-1 | パーサー出力拡張（pitcher_usage詳細記録 + fielding_stats） | L4 |
| D-2 | import_log PitcherGameState自動生成（詳細記録含む） | L3 |
| D-2 | import_log FielderGameState自動生成 | L3 |
| D-3 | confirm時の疲労計算 | L3 |

---

## 6. リスクと考慮事項

### 6.1 2フロー統合のリスク

- `season_schedules.game_id` の後付けにより、既存の season_schedule データ（game_id=null）との整合性
- → マイグレーションで既存データは game_id=null のまま。投手起用を入力した時点で Game を作成し紐づけ

### 6.2 投手休養ルールの複雑性

- 4パターン × 結果分類3種 × スラッシュ選手優遇 × オープナー
- → CumulativeFatigueCalculator のテストケースが多い（推定50+件）
- → context/pitcher-rest-rules-analysis.md をテストケースのソースとして活用

### 6.3 パーサーの投手起用抽出精度

- 現在のパーサー精度: イニング得点一致率80.5%
- 投手交代の検出精度は未検証
- → Phase D はパーサー精度改善と並行で進める必要あり
- → 手入力での補正を常に可能にしておく（draft → 手修正 → confirm）

### 6.4 PlayerCard情報の参照

- 疲労P計算には PlayerCard の `starter_stamina`, `relief_stamina`, `is_relief_only` が必要
- PlayerCard は CardSet（コスト表）に紐づくため、Competition と CardSet の関連を通じて取得
- → 「どのカードセットの能力値を使うか」を competition 設定から解決する必要がある

---

## 7. 推奨着手順序

1. **Phase A-1**: まずAPIを作る。PitcherGameStatesController + マイグレーション
2. **Phase A-2**: FE投手起用セクション。最小限のUIでCRUD動作確認
3. **Phase B-1**: CumulativeFatigueCalculator。投手休養ルールの中核。**ここが最重要かつ最高難度**
4. 以降はB-2→B-3→C→Dの順で漸進的に拡張

Phase A のみで「手動で投手起用を記録できる」最小機能が完成する。
Phase B で疲労計算が入り実用性が大幅に上がる。
Phase C, D は運用しながら段階的に追加できる。
