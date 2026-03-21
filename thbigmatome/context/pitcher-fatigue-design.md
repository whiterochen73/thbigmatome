# 投手登板管理機能 設計書

作成日: 2026-03-20
対応タスク: cmd_635 / subtask_635a

---

## 1. 概要

投手の試合登板を記録し、休養ルール（公式Wiki準拠）に基づいて次回登板可否・疲労Pを自動計算する機能。

### 主な機能

1. **投手登板状況一覧（全チーム横断）**: 区分・直近7日登板履歴・累積イニング/中日数・登板可否ステータス
2. **試合登板登録**: 先発(KO/ノーゲーム/長イニング敗戦)/リリーフ/オープナー対応
3. **ステータス自動判定**: 全快/⚡P減少/⚠️負傷CK要/🚫不可/🏥負傷中

---

## 2. DB設計

### 2-1. 既存テーブルの活用方針

`pitcher_game_states` テーブルが投手登板記録として既に存在し、必要なカラムを概ね網羅している。
このテーブルを本機能の登板記録テーブル（`pitcher_appearances`相当）として活用する。

```
pitcher_game_states (既存)
  - game_id          -- 試合FK
  - pitcher_id       -- 投手（players FK）
  - competition_id   -- 大会FK
  - team_id          -- チームFK
  - role             -- starter / reliever / opener
  - innings_pitched  -- 投球回数 (decimal 5,1)
  - cumulative_innings -- 累積イニング（リリーフ用）
  - earned_runs      -- 自責点
  - fatigue_p_used   -- 疲労P消費量
  - decision         -- W/L/S/H
  - result_category  -- normal / ko / no_game / long_loss
  - injury_check     -- safe / injured
  - schedule_date    -- 試合日（文字列）
```

### 2-2. 追加カラム（P承認済み）

以下のカラムを `pitcher_game_states` に追加する（承認済み）。

| カラム名 | 型 | デフォルト | 説明 |
|---------|-----|---------|------|
| `is_opener` | boolean | false | オープナー本人として登板（真の場合、リリーフルール適用） |
| `consecutive_short_rest_count` | integer | 0 | 連続中4日先発カウント（DBカラムとして管理） |
| `pre_injury_days_excluded` | integer | 0 | 負傷離脱で除外した中日数（計算補正用） |

### 2-3. マイグレーション設計（P承認済み）

```ruby
# db/migrate/YYYYMMDD_add_columns_to_pitcher_game_states.rb
add_column :pitcher_game_states, :is_opener, :boolean, default: false, null: false
add_column :pitcher_game_states, :consecutive_short_rest_count, :integer, default: 0, null: false
add_column :pitcher_game_states, :pre_injury_days_excluded, :integer, default: 0, null: false
```

### 2-4. テーブルリレーション図

```
players ─────────────── pitcher_game_states ──── games
   │                          │                    │
   │  player_cards            │                    │
   │  - is_pitcher            │                    │
   │  - is_relief_only        │                    │
   │  - starter_stamina       │                    │
   │  - relief_stamina        ├──── competitions   │
   │                          └──── teams          │
   │
   └── player_absences ── team_memberships ── teams
         - start_date
         - duration / duration_unit
         - absence_type
```

### 2-5. スラッシュ選手ルール参照

スラッシュ選手（先発/リリーフ兼任）の判定ロジックおよび詳細ルールテーブルは **[pitcher-rest-rules-analysis.md Section 4](pitcher-rest-rules-analysis.md) 参照**。

---

## 3. 休養ルール計算ロジック

### 3-1. 中日数の計算

```ruby
# 中日数 = 今日 - 直近登板日 - 1（負傷離脱期間を除外）
def calculate_rest_days(pitcher_id, team_id, target_date)
  last_appearance = PitcherGameState
    .where(pitcher_id: pitcher_id, team_id: team_id)
    .where("schedule_date < ?", target_date)
    .order(schedule_date: :desc)
    .first
  return nil if last_appearance.nil?

  raw_days = (target_date - last_appearance.schedule_date.to_date).to_i - 1

  # 負傷離脱期間を中日数から除外
  absence_days = calculate_absence_days(pitcher_id, team_id,
                   last_appearance.schedule_date.to_date + 1, target_date)
  raw_days - absence_days
end
```

### 3-2. 先発→先発 フローチャート

```
直近登板が先発? → NO → 先発→リリーフ or リリーフ→先発ルールへ
     ↓ YES
中日数算出
     ↓
中2日以内? → YES → 🚫 登板不可
     ↓ NO
result_category を確認
├── ko / no_game  → [KO・ノーゲームブランチ]
├── long_loss     → [長イニング敗戦ブランチ]
└── normal        → [通常ブランチ]

[通常ブランチ]
  中3日? → 疲労P0, ⚠️ 負傷チェック要
  中4日? → 疲労P-3, 連続2回なら⚠️ 負傷チェック要
  中5日? → 疲労P-1
  中6日以上 → カード記載疲労P, ✅ 全快

[KO・ノーゲームブランチ]
  中3日? → 疲労P-3
  中4日以上 → カード記載疲労P, ✅ 全快

[長イニング敗戦ブランチ]
  中3日? → 疲労P0, ⚠️ 負傷チェック要
  中4日? → 疲労P-4
  中5日? → 疲労P-2
  中6日? → 疲労P-1
  中7日以上 → カード記載疲労P, ✅ 全快
```

### 3-3. リリーフ→リリーフ フローチャート

```
累積イニング計算（当日まで減衰を適用）
     ↓
累積0? → カード記載疲労P, ✅ 全快
     ↓ NO
累積1? → 疲労P0
     ↓ NO（累積2以上）
⚡ 疲労状態（＊）: 投球出目が1段下がった状態（疲労P数値計算ではなく状態定義）
負傷チェック対象確認:
  累積3以上? → ⚠️ 負傷チェック要

中日数確認:
  中5日? → 疲労状態解除（累積リセット方向）
  中6日以上? → カード記載疲労P（累積リセット、全快）

登板可否: 累積2以上は疲労状態（＊）で登板可
```

#### 累積イニング減衰計算（疑似コード）

```ruby
def calculate_current_cumulative_innings(pitcher_id, team_id, target_date)
  appearances = PitcherGameState
    .where(pitcher_id: pitcher_id, team_id: team_id, role: ['reliever', 'opener'])
    .where("schedule_date <= ?", target_date)
    .order(schedule_date: :asc)

  cumulative = 0
  prev_date = nil

  appearances.each do |app|
    if prev_date
      rest_days = (app.schedule_date.to_date - prev_date.to_date).to_i - 1
      rest_days.times do
        cumulative = cumulative <= 3 ? [cumulative - 2, 0].max : cumulative - 1
      end
    end
    cumulative += 1  # 1登板 = +1イニング（回跨ぎ含む）
    prev_date = app.schedule_date.to_date
  end

  # 最後の登板から当日までの減衰
  if prev_date && prev_date < target_date
    idle_days = (target_date - prev_date).to_i - 1
    idle_days.times do
      cumulative = cumulative <= 3 ? [cumulative - 2, 0].max : cumulative - 1
    end
  end

  cumulative
end
```

### 3-4. 先発→リリーフ フローチャート

```
前登板が先発
     ↓
result_category確認
├── ko / no_game  → [中2日→P0, 中3日以上→カード値]
├── long_loss     → [中4日→P0, 中5日以上→カード値]
└── normal        → [中3日→P0, 中4日以上→カード値]

スラッシュ選手の場合: [pitcher-rest-rules-analysis.md Section 4 参照]
```

### 3-5. リリーフ→先発 フローチャート

```
前登板がリリーフ（またはオープナー）
     ↓
スラッシュ選手?
├── YES → [pitcher-rest-rules-analysis.md Section 4 参照]
└── NO  → 通常ルール
           中3日 → 疲労P0, ⚠️ 負傷チェック要
           中4日 → 疲労P-3
           中5日 → 疲労P-1
           中6日以上 → カード記載疲労P
```

### 3-6. オープナー起用

```
オープナー本人:
  - リリーフ→リリーフの累積イニングルール適用
  - 負傷チェック発動: 中2日以内の連続 or 前日登板（通常リリーフとして前日登板した翌日のオープナー起用も含む）or 累積1以上

第二先発（後続）:
  - 先発→先発の通常ルール適用
  - role = 'starter' として記録
  - オープナー起用試合であることをメタ情報として保持（is_opener = false）
```

---

## 4. ステータス自動判定ロジック

計算された疲労Pとチェック条件からステータスを決定する。

| ステータス | 記号 | 判定条件 |
|-----------|------|---------|
| 全快 | ✅ | 疲労P = カード記載疲労P かつ 負傷チェック不要 |
| P減少 | ⚡ | 先発系: 疲労P < カード記載疲労P（P=0含む）かつ 負傷チェック不要 |
| 疲労状態（＊1段下がり） | ⚡ | リリーフ累積2以上: 投球出目が1段下がった状態（疲労P数値なし） |
| 負傷CK要 | ⚠️ | 負傷チェック発動条件に該当 |
| 登板不可 | 🚫 | 中2日以内先発、または疲労P計算不可 |
| 負傷中 | 🏥 | player_absences に有効レコードあり（離脱期間内） |

```ruby
def pitching_status(pitcher_id, team_id, target_date, role)
  # 負傷中チェック（最優先）
  return :injured if currently_injured?(pitcher_id, team_id, target_date)

  rest_info = calculate_rest_and_fatigue(pitcher_id, team_id, target_date, role)
  return :unavailable if rest_info[:fatigue_p] == :unavailable

  if rest_info[:injury_check_required]
    :injury_check_required   # ⚠️
  elsif rest_info[:fatigue_p] == rest_info[:base_fatigue_p]
    :full_recovery            # ✅
  else
    :reduced                  # ⚡（P減少、P=0含む）
  end
end
```

---

## 5. REST API設計

### 5-1. エンドポイント一覧

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/pitcher_appearances` | 投手登板状況一覧（全チーム横断） |
| GET | `/pitcher_appearances/:pitcher_id/status` | 特定投手の登板可否ステータス |
| POST | `/pitcher_appearances` | 登板登録 |
| GET | `/pitcher_appearances/:id` | 登板記録詳細 |

### 5-2. GET /pitcher_appearances レスポンス

```json
[
  {
    "pitcher_id": 1,
    "player_name": "霊夢",
    "team_id": 1,
    "team_name": "博麗神社",
    "pitcher_type": "starter",       // starter / reliever / slash
    "is_relief_only": false,
    "status": "full_recovery",       // full_recovery / reduced / injury_check_required / unavailable / injured
    "status_label": "✅ 全快",
    "available_fatigue_p": 5,        // 登板可能な疲労P（null=不可）
    "rest_days": 6,                  // 直近登板からの中日数
    "cumulative_innings": 0,         // 累積イニング（リリーフ用）
    "last_appearance": {
      "schedule_date": "2026-03-14",
      "role": "starter",
      "innings_pitched": 7.0,
      "result_category": "normal"
    },
    "recent_appearances": [          // 直近7日間の登板履歴
      {
        "schedule_date": "2026-03-14",
        "role": "starter",
        "innings_pitched": 7.0
      }
    ]
  }
]
```

**クエリパラメータ:**
- `competition_id` (必須): 大会ID
- `team_id` (任意): チーム絞り込み
- `target_date` (任意, デフォルト: 本日): 判定基準日

### 5-3. POST /pitcher_appearances リクエスト

```json
{
  "pitcher_appearance": {
    "pitcher_id": 1,
    "team_id": 1,
    "competition_id": 1,
    "game_id": 10,
    "role": "starter",
    "innings_pitched": 7.0,
    "result_category": "normal",
    "schedule_date": "2026-03-20",
    "earned_runs": 1,
    "fatigue_p_used": 5,
    "decision": "W",
    "injury_check": "safe",
    "is_opener": false
  }
}
```

**レスポンス:** 201 Created + 登録した登板記録JSON

### 5-4. GET /pitcher_appearances/:pitcher_id/status レスポンス

```json
{
  "pitcher_id": 1,
  "player_name": "霊夢",
  "target_date": "2026-03-20",
  "status": "full_recovery",
  "status_label": "✅ 全快",
  "available_fatigue_p": 5,
  "rest_days": 6,
  "injury_check_required": false,
  "consecutive_short_rest_count": 0,
  "cumulative_innings": 0,
  "next_role_estimated": "starter",
  "rule_applied": "starter_to_starter_normal",
  "rule_detail": "中6日以上: カード記載疲労P"
}
```

---

## 6. 実装コンポーネント

### 6-1. バックエンド（Rails）

```
app/
├── models/
│   └── pitcher_game_state.rb  -- 既存モデルに休養計算メソッド追加
├── services/
│   └── pitcher_rest_calculator.rb  -- 休養ルール計算ロジック
│       ├── StarterToStarterRule
│       ├── ReliefToReliefRule
│       ├── StarterToReliefRule
│       ├── ReliefToStarterRule
│       └── OpenerRule
├── controllers/api/v1/
│   └── pitcher_appearances_controller.rb  -- 新規
└── serializers/
    └── pitcher_appearance_serializer.rb   -- 新規
```

### 6-2. フロントエンド（Vue.js）

```
src/
├── views/
│   └── PitcherAppearancesView.vue   -- 投手登板状況一覧
├── components/pitcher/
│   ├── PitcherStatusBadge.vue       -- ステータスバッジ（✅⚡⚠️🚫🏥）
│   ├── PitcherAppearanceList.vue    -- 一覧テーブル
│   └── PitcherAppearanceForm.vue    -- 登板登録フォーム
└── stores/
    └── pitcherAppearances.ts        -- Pinia store
```

**オープナーUI（事後記録）**: リリーフ登録行に「□ オープナー」「□ 第二先発」チェックボックスのみ追加。動的UI連動不要。シンプルな事後記録として実装する。

---

## 7. 未解決事項・要確認

すべてP確認済みにより設計に反映済み。未解決事項なし。

| # | 項目 | 解決方法 |
|---|------|---------|
| 1 | リリーフ累積2以上の疲労P詳細 | 疲労状態（＊）= 投球出目1段下がりとして定義（Section 3-3, 4参照） |
| 2 | スラッシュ選手の詳細ルールテーブル | 設計書から削除、pitcher-rest-rules-analysis.md Section 4 参照に一本化 |
| 3 | consecutive_short_rest_count の管理方式 | DBカラムとして管理（Section 2-2, 2-3参照） |
| 4 | pitcher_game_statesカラム追加のマイグレーション承認 | P承認済み。Section 2-3にマイグレーション設計追記 |
| 5 | オープナー登録時の第二先発との連携UI仕様 | 事後記録としてシンプルなチェックボックスのみ（Section 6-2参照） |
| 6 | 負傷チェック結果の入力タイミング | スコープ外（本機能には含めない） |

---

## 8. 参考資料

- [投手休養ルール（公式Wiki）](https://thbigbaseball.wiki.fc2.com/wiki/%E6%8A%95%E6%89%8B%E4%BC%91%E9%A4%8A%E3%83%AB%E3%83%BC%E3%83%AB)
- [pitcher-rest-rules-analysis.md](pitcher-rest-rules-analysis.md) — 本設計書のルール調査メモ
- [db-schema.md](../docs/db-schema.md) — DBスキーマ定義
