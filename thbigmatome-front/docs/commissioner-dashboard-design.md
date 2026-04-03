# コミッショナー横断管理ダッシュボード 設計書

## 概要

全チーム横断でコミッショナーが管理すべき情報を一画面に集約するダッシュボードを設計する。
3セクション構成: 離脱者一覧 / コスト使用状況 / クールダウン・負傷中選手。

**ルート**: `/commissioner/dashboard`
**メタ**: `{ requiresAuth: true, requiresCommissioner: true, title: 'ダッシュボード' }`

---

## セクション1: 離脱者一覧（全チーム横断）

### 表示情報

| カラム | ソース | 備考 |
|--------|--------|------|
| チーム名 | `teams.name` via `team_memberships.team_id` | |
| 選手名 | `players.name` via `team_memberships.player_id` | |
| 離脱種別 | `player_absences.absence_type` | injury/suspension/reconditioning |
| 離脱理由 | `player_absences.reason` | |
| 離脱開始日 | `player_absences.start_date` | ゲーム内日付 |
| 復帰予定日 | `PlayerAbsence#effective_end_date` | モデル側で計算済み |
| 残り日数/試合数 | 計算値（後述） | ゲーム内日程基準 |

### ゲーム内日程基準での復帰日数計算（重要）

既存の `PlayerAbsence#effective_end_date` が復帰日を返す。これをベースに残り日数を計算する。

#### duration_unit = "days" の場合

```
remaining_days = effective_end_date - season.current_date
```

カレンダー日数の差分。`season.current_date`（ゲーム内の現在日）を基準にする。

#### duration_unit = "games" の場合

```
remaining_games = season_schedules
  .where(date_type: ['game_day', 'interleague_game_day'])
  .where('date >= ? AND date < ?', season.current_date, effective_end_date)
  .count
```

`season.current_date` から `effective_end_date` までの間にある**試合日の数**が残り試合数。

#### 横断表示での課題

各チームが独立した `season` を持つため、チームごとに `season.current_date` が異なる可能性がある。
APIは各 `player_absence` に紐づく `season.current_date` を含めて返す必要がある。

### 既存コード活用

- `PlayerAbsence` モデルの `effective_end_date` メソッド → そのまま利用可
- `SeasonAbsenceTab.vue` の表示ロジック（色分け・残り日数表示・復帰間近ハイライト）→ 参考にする
- 既存 `GET /player_absences?season_id=N` は単一シーズン用 → 横断用に新エンドポイント必要

---

## セクション2: コスト使用状況（チーム別）

### 表示情報

| カラム | ソース | 備考 |
|--------|--------|------|
| チーム名 | `teams.name` | |
| チーム種別 | `teams.team_type` | normal / hachinai |
| 現在コスト / 上限200 | 計算値 | 全選手合計 |
| 1軍コスト / 段階制上限 | 計算値 | `Team.first_squad_cost_limit_for_count(N)` |
| 1軍人数 | `team_memberships WHERE squad='first'` | |
| コスト除外選手数 | `team_memberships WHERE excluded_from_team_total=true` | |

### コスト計算ロジック

```ruby
# 全体コスト
current_cost = Cost.current_cost  # costs テーブルから end_date IS NULL のレコード
total = team.team_memberships.sum do |tm|
  next 0 if tm.excluded_from_team_total
  cp = tm.player.cost_players.find { |c| c.cost_id == current_cost.id }
  cp&.send(tm.selected_cost_type) || 0
end

# 1軍コスト
first_squad = team.team_memberships.where(squad: 'first')
first_cost = first_squad.sum { ... }  # 同上
first_limit = Team.first_squad_cost_limit_for_count(first_squad.count)
```

### 表示の工夫

- コスト上限に近い（90%超）チームを警告色で表示
- コスト上限超過は赤色（StatusChip: warning / error）
- プログレスバー（v-progress-linear）で視覚化

---

## セクション3: クールダウン・負傷中選手（全チーム横断）

### 3-A: 負傷中選手

セクション1の離脱者一覧のうち `absence_type = 'injury'` のサブセット。
セクション1と統合表示も可能だが、負傷のみをフィルタして見たいニーズがあるためタブ分離。

### 3-B: 投手クールダウン（1軍→2軍降格後10日間）

#### 既存データ構造

クールダウンは **`season_rosters` テーブル** で管理されている:

```
season_rosters:
  - id, season_id, team_membership_id, squad, registered_on
```

**計算ロジック**（`TeamRostersController#calculate_cooldown_info` より）:

1. `season_rosters` から最新の `squad='second'`（降格）レコードを取得
2. その前の `squad='first'`（昇格）レコードを取得
3. `cooldown_end = last_demotion.registered_on + 10.days`
4. 同日昇格・降格の場合は免除（`same_day_exempt = true`）

**重要**: クールダウンは投手に限定されず、全選手に適用される。ただしダッシュボードでは実運用上の重要性から投手を中心に表示する。

#### 表示情報

| カラム | ソース | 備考 |
|--------|--------|------|
| チーム名 | `teams.name` | |
| 選手名 | `players.name` | |
| 降格日 | `season_rosters.registered_on` | 最新のsquad='second' |
| クールダウン終了日 | 降格日 + 10日 | |
| 残り日数 | `cooldown_end - season.current_date` | |
| 同日免除 | `same_day_exempt` | true の場合は表示しない or グレーアウト |

#### 投手登板間隔（将来拡張）

`pitcher_game_states` テーブルに登板記録がある:

```
pitcher_game_states:
  - pitcher_id, game_id, team_id, role (starter/reliever)
  - innings_pitched, schedule_date, fatigue_p_used
```

現状、登板間隔制限のビジネスルールは未実装。`pitcher_game_states` から直近の登板日を取得し、連投状況を表示することは可能だが、**Phase 1では見送り**とし、クールダウン（10日ルール）のみ実装する。

---

## BE API設計

### 新規エンドポイント

すべて `Api::V1::Commissioner::` namespace 配下。`check_commissioner` before_action で権限チェック。

#### 1. `GET /api/v1/commissioner/dashboard/absences`

全チーム横断の現在有効な離脱者一覧。

**レスポンス**:
```json
[
  {
    "id": 1,
    "team_name": "チームA",
    "team_id": 10,
    "player_name": "霧雨魔理沙",
    "player_id": 42,
    "absence_type": "injury",
    "reason": "右肩負傷",
    "start_date": "2026-04-15",
    "duration": 5,
    "duration_unit": "games",
    "effective_end_date": "2026-04-22",
    "remaining_days": 3,
    "remaining_games": 2,
    "season_current_date": "2026-04-19"
  }
]
```

**実装方針**:
```ruby
class Api::V1::Commissioner::DashboardController < Api::V1::Commissioner::BaseController
  def absences
    teams = Team.where(is_active: true).includes(
      team_memberships: [:player, { player_absences: :season }]
    )

    absences = []
    teams.each do |team|
      season = team.season
      next unless season

      team.team_memberships.each do |tm|
        tm.player_absences.each do |pa|
          next unless pa.season_id == season.id
          end_date = pa.effective_end_date
          next if end_date && end_date < season.current_date  # 過去の離脱は除外

          remaining = calculate_remaining(pa, season)
          absences << {
            id: pa.id, team_name: team.name, team_id: team.id,
            player_name: tm.player.name, player_id: tm.player_id,
            absence_type: pa.absence_type, reason: pa.reason,
            start_date: pa.start_date, duration: pa.duration,
            duration_unit: pa.duration_unit,
            effective_end_date: end_date,
            season_current_date: season.current_date,
            **remaining
          }
        end
      end
    end

    render json: absences
  end
end
```

#### 2. `GET /api/v1/commissioner/dashboard/costs`

全チームのコスト使用状況。

**レスポンス**:
```json
[
  {
    "team_id": 10,
    "team_name": "チームA",
    "team_type": "normal",
    "total_cost": 185,
    "total_cost_limit": 200,
    "first_squad_cost": 150,
    "first_squad_cost_limit": 170,
    "first_squad_count": 25,
    "exempt_count": 1,
    "cost_usage_ratio": 0.925
  }
]
```

**実装方針**:
```ruby
def costs
  current_cost = Cost.current_cost
  teams = Team.where(is_active: true).includes(
    team_memberships: { player: :cost_players }
  )

  result = teams.map do |team|
    memberships = team.team_memberships
    first_squad = memberships.select { |tm| tm.squad == 'first' }

    total = memberships.reject(&:excluded_from_team_total).sum do |tm|
      cp = tm.player.cost_players.find { |c| c.cost_id == current_cost.id }
      cp&.send(tm.selected_cost_type) || 0
    end

    first_cost = first_squad.sum do |tm|
      cp = tm.player.cost_players.find { |c| c.cost_id == current_cost.id }
      cp&.send(tm.selected_cost_type) || 0
    end

    first_limit = Team.first_squad_cost_limit_for_count(first_squad.count)
    exempt_count = memberships.count(&:excluded_from_team_total)

    {
      team_id: team.id, team_name: team.name, team_type: team.team_type,
      total_cost: total, total_cost_limit: 200,
      first_squad_cost: first_cost, first_squad_cost_limit: first_limit,
      first_squad_count: first_squad.count,
      exempt_count: exempt_count,
      cost_usage_ratio: total / 200.0
    }
  end

  render json: result
end
```

#### 3. `GET /api/v1/commissioner/dashboard/cooldowns`

クールダウン中の選手一覧。

**レスポンス**:
```json
[
  {
    "team_name": "チームA",
    "team_id": 10,
    "player_name": "博麗霊夢",
    "player_id": 1,
    "demotion_date": "2026-04-15",
    "cooldown_until": "2026-04-25",
    "remaining_days": 6,
    "same_day_exempt": false
  }
]
```

**実装方針**:
```ruby
def cooldowns
  teams = Team.where(is_active: true).includes(
    season: [], team_memberships: [:player, :season_rosters]
  )

  cooldowns = []
  teams.each do |team|
    season = team.season
    next unless season

    team.team_memberships.each do |tm|
      next unless tm.squad == 'second'  # 2軍選手のみ対象

      info = calculate_cooldown_info(tm, season.current_date)
      next unless info[:cooldown_until]

      cooldowns << {
        team_name: team.name, team_id: team.id,
        player_name: tm.player.name, player_id: tm.player_id,
        demotion_date: info[:demotion_date],
        cooldown_until: info[:cooldown_until],
        remaining_days: (info[:cooldown_until].to_date - season.current_date).to_i,
        same_day_exempt: info[:same_day_exempt]
      }
    end
  end

  render json: cooldowns
end
```

### ルーティング

```ruby
# config/routes.rb（commissioner namespace 内に追加）
namespace :commissioner do
  resource :dashboard, only: [], controller: 'dashboard' do
    collection do
      get :absences
      get :costs
      get :cooldowns
    end
  end
end
```

---

## FE画面構成

### レイアウト: タブ構成

LP-1パターン（PageHeader + コンテンツ）。3セクションをタブで切り替え。

```
┌─────────────────────────────────────────────┐
│ PageHeader: "ダッシュボード"                  │
├─────────────────────────────────────────────┤
│ [離脱者一覧] [コスト状況] [クールダウン]       │ ← v-tabs
├─────────────────────────────────────────────┤
│                                             │
│  タブコンテンツ                               │
│  - 各タブ = DataCard + v-data-table          │
│  - FilterBarでフィルタ                        │
│                                             │
└─────────────────────────────────────────────┘
```

### コンポーネント構成

```
views/commissioner/CommissionerDashboardView.vue
├── PageHeader (title="ダッシュボード")
├── v-tabs
│   ├── Tab 1: 離脱者一覧
│   │   ├── FilterBar (#filters: absence_type選択, #search: 選手名検索)
│   │   └── DataCard (title="離脱者一覧")
│   │       └── v-data-table
│   │           └── StatusChip (absence_type表示)
│   │
│   ├── Tab 2: コスト状況
│   │   └── DataCard (title="チーム別コスト使用状況")
│   │       └── v-data-table
│   │           ├── v-progress-linear (コスト使用率)
│   │           └── StatusChip (warning/error)
│   │
│   └── Tab 3: クールダウン
│       ├── FilterBar (#search: 選手名検索)
│       └── DataCard (title="クールダウン中選手")
│           └── v-data-table
│               └── 残り日数チップ (復帰間近=green)
```

### 共通コンポーネント活用

| コンポーネント | 使用箇所 | 用途 |
|---------------|---------|------|
| PageHeader | ダッシュボード全体 | タイトル表示 |
| DataCard | 各タブのコンテンツラッパー | カードタイトル + テーブル |
| FilterBar | 離脱者・クールダウンタブ | フィルタ・検索UI |
| StatusChip | 離脱種別・コスト警告 | 色分けチップ表示 |

### StatusChip 拡張

現在の `statusColorMap` にダッシュボード用マッピングを追加:

```typescript
// 追加が必要なマッピング
injury: 'error',        // 赤 — 既存
suspension: 'warning',  // オレンジ
reconditioning: 'info', // 青グレー
```

→ StatusChipに追加するか、ダッシュボード内でローカルに色マッピングを持つか判断が必要。
  SeasonAbsenceTabと同じ `getAbsenceColor()` パターンを採用する方が一貫性がある。

### ナビゲーション追加

`NavigationDrawer.vue` のコミッショナーメニューに追加:

```vue
<v-list-item
  :to="'/commissioner/dashboard'"
  prepend-icon="mdi-view-dashboard"
>
  <v-list-item-title>ダッシュボード</v-list-item-title>
</v-list-item>
```

管理セクションの**最上部**に配置（他のCRUD画面より優先度が高い）。

---

## フェーズ分割

### Phase 1: 離脱者一覧（MVP・最優先）

**理由**: P要件「負傷状況把握」に直結。既存コード（SeasonAbsenceTab + PlayerAbsence モデル）の活用度が最も高い。

**スコープ**:
- BE: `DashboardController#absences` エンドポイント
- FE: `CommissionerDashboardView.vue` 新規作成（離脱者タブのみ）
- ルーター追加 + ナビゲーション追加
- 復帰間近ハイライト（残り2日/試合以下で緑色）

**見積もり**: BE 1cmd + FE 1cmd

### Phase 2: コスト使用状況

**理由**: P要件「コスト管理」に直結。計算ロジックは `TeamRostersController` に既存。

**スコープ**:
- BE: `DashboardController#costs` エンドポイント
- FE: コストタブ追加（v-data-table + v-progress-linear）
- コスト警告表示（90%超=warning, 100%超=error）

**見積もり**: BE 1cmd + FE 1cmd

### Phase 3: クールダウン

**理由**: 運用上重要だが Phase 1/2 より優先度は低い。

**スコープ**:
- BE: `DashboardController#cooldowns` エンドポイント
- FE: クールダウンタブ追加
- 同日免除のグレーアウト表示

**見積もり**: BE 1cmd + FE 1cmd

### Phase 4（将来拡張）: 投手登板間隔

- `pitcher_game_states` から連投状況を集計
- 登板間隔ルールの定義（ビジネスルール策定が前提）
- Phase 1-3 完了後に要件確認

---

## 既存テーブル活用方針まとめ

| テーブル | 用途 | Phase |
|---------|------|-------|
| `player_absences` | 離脱者一覧のメインデータ | 1 |
| `team_memberships` | 選手→チーム紐付け、squad判定 | 1, 2, 3 |
| `players` | 選手名・背番号 | 1, 2, 3 |
| `teams` | チーム名・種別・アクティブ判定 | 1, 2, 3 |
| `seasons` | ゲーム内現在日（current_date） | 1, 3 |
| `season_schedules` | 残り試合数計算（game_day カウント） | 1 |
| `costs` | 現在有効コスト表（end_date IS NULL） | 2 |
| `cost_players` | 選手別コスト値 | 2 |
| `season_rosters` | クールダウン計算（降格/昇格履歴） | 3 |
| `pitcher_game_states` | 投手登板間隔（将来） | 4 |

**新規テーブル不要** — すべて既存テーブルで対応可能。
