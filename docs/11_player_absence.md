# 11. 選手離脱管理機能仕様書

## 概要

本システムでは、シーズン中の選手の離脱（怪我、出場停止、調整）を記録・管理する機能を提供する。離脱情報は`PlayerAbsence`モデルで管理され、一般ユーザー向けとコミッショナー向けの2系統のAPIエンドポイントが存在する。

**主要な特徴:**
- 3種類の離脱タイプ（injury: 怪我、suspension: 出場停止、reconditioning: 調整）
- 期間指定は「日数」または「試合数」で選択可能
- シーズン単位で離脱履歴を管理
- 一般ユーザー用API: シーズンIDベースの一覧取得・CRUD操作
- コミッショナー用API: チームメンバーシップIDベースのネストされたリソース操作
- フロントエンド: 離脱者履歴画面、登録/編集ダイアログ、シーズンポータル画面での離脱情報表示

---

## 画面構成（フロントエンド）

### 選手離脱履歴画面

**パス:** `/teams/:teamId/season/player_absences`

**コンポーネント:** `src/views/PlayerAbsenceHistory.vue`

**レイアウト:**
```
┌──────────────────────────────────────────────────┐
│ TeamNavigation (タブナビゲーション)               │
│ [チームメンバー] [出場選手] [シーズンポータル] [離脱者]│
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│ ツールバー (primary)                              │
│ [離脱者履歴]                    [離脱を追加]      │
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│ v-card (variant="outlined")                      │
│ ┌─────┬─────┬─────┬─────┬─────┬─────┬────┐   │
│ │開始 │選手 │種別 │理由 │期間 │単位 │操作│   │
│ │日付 │名   │     │     │     │     │    │   │
│ ├─────┼─────┼─────┼─────┼─────┼─────┼────┤   │
│ │11月 │選手A│怪我 │右肘│  7  │日   │✎🗑 │   │
│ │15日 │     │     │炎症│     │     │    │   │
│ └─────┴─────┴─────┴─────┴─────┴─────┴────┘   │
└──────────────────────────────────────────────────┘
```

**テーブルカラム:**

| カラムキー | ヘッダー（i18nキー） | 表示形式 | ソート可 |
|-----------|---------------------|---------|---------|
| `start_date` | `playerAbsenceHistory.tableHeaders.startDate` | `MM月DD日` (ja-JP locale) | yes |
| `player_name` | `playerAbsenceHistory.tableHeaders.playerName` | 文字列 | yes |
| `absence_type` | `playerAbsenceHistory.tableHeaders.absenceType` | `t('enums.player_absence.absence_type.{value}')` | yes |
| `reason` | `playerAbsenceHistory.tableHeaders.reason` | 文字列 | yes |
| `duration` | `playerAbsenceHistory.tableHeaders.duration` | 数値 | yes |
| `duration_unit` | `playerAbsenceHistory.tableHeaders.durationUnit` | `t('enums.player_absence.duration_unit.{value}')` | yes |
| `actions` | `playerAbsenceHistory.tableHeaders.actions` | アイコンボタン（編集・削除） | no |

**動作フロー:**

1. **画面マウント時:**
   - `GET /api/v1/teams/:teamId/season` でシーズン情報取得
   - シーズンIDを使って `GET /api/v1/player_absences?season_id={id}` で離脱一覧取得

2. **離脱追加ボタン押下:**
   - `editAbsence(null)` 呼び出し → `PlayerAbsenceFormDialog` を開く (新規作成モード)

3. **編集アイコン押下:**
   - `editAbsence(item)` 呼び出し → `PlayerAbsenceFormDialog` を開く (編集モード、既存データ渡す)

4. **削除アイコン押下:**
   - `confirm(t('playerAbsenceHistory.confirmDelete', { playerName: ... }))` で確認ダイアログ表示
   - ユーザー承認 → `DELETE /api/v1/player_absences/:id` 実行
   - 成功後に離脱一覧を再取得

5. **ダイアログ保存完了時 (`@saved` イベント):**
   - ダイアログを閉じる
   - `selectedAbsence` をクリア
   - 離脱一覧を再取得

**国際化（i18n）キー:**
- `playerAbsenceHistory.title`: ページタイトル
- `playerAbsenceHistory.addAbsence`: 「離脱を追加」ボタンラベル
- `playerAbsenceHistory.tableHeaders.*`: 各カラムヘッダー
- `playerAbsenceHistory.confirmDelete`: 削除確認メッセージ (変数: `playerName`)
- `enums.player_absence.absence_type.{injury|suspension|reconditioning}`: 離脱種別の表示名
- `enums.player_absence.duration_unit.{days|games}`: 期間単位の表示名

---

### 離脱登録/編集ダイアログ

**コンポーネント:** `src/components/PlayerAbsenceFormDialog.vue`

**レイアウト:**
```
┌───────────────────────────────────┐
│ [離脱を追加 / 離脱を編集]          │ ← タイトル (id有無で切替)
├───────────────────────────────────┤
│ [選手名]                          │ ← TeamMemberSelect
│ ┌─────────────────────────────┐   │
│ │ (ドロップダウン)             │   │
│ └─────────────────────────────┘   │
│                                   │
│ [離脱種別]                        │
│ ┌─────────────────────────────┐   │
│ │ injury / suspension / ...   │   │
│ └─────────────────────────────┘   │
│                                   │
│ [理由]                            │
│ ┌─────────────────────────────┐   │
│ │ (テキスト入力)               │   │
│ └─────────────────────────────┘   │
│                                   │
│ [開始日]        [期間]            │
│ ┌───────────┐  ┌───────────┐     │
│ │ date型    │  │ number型 │     │
│ └───────────┘  └───────────┘     │
│                                   │
│ [期間単位]                        │
│ ┌─────────────────────────────┐   │
│ │ days / games                │   │
│ └─────────────────────────────┘   │
│                                   │
│           [キャンセル] [保存]     │
└───────────────────────────────────┘
```

**フォームフィールド:**

| フィールド | コンポーネント | バリデーション | デフォルト値 |
|----------|--------------|--------------|------------|
| `team_membership_id` | `TeamMemberSelect` | required | `0` (新規) / 既存値 (編集) |
| `absence_type` | `v-select` | required | `'injury'` (新規) / 既存値 (編集) |
| `reason` | `v-text-field` | required | `''` (新規) / 既存値 (編集) |
| `start_date` | `v-text-field[type=date]` | required | `props.initialStartDate` (新規) / 既存値 (編集) |
| `duration` | `v-text-field[type=number]` | required, > 0 | `1` (新規) / 既存値 (編集) |
| `duration_unit` | `v-select` | required | `'days'` (新規) / 既存値 (編集) |

**動作フロー:**

1. **ダイアログオープン時 (watch `isOpen`):**
   - `props.initialAbsence` が存在 → 編集モード: `newAbsence.value = { ...props.initialAbsence }`
   - `props.initialAbsence` がnull → 新規作成モード: フィールドをデフォルト値でリセット
   - フォームのバリデーションをリセット

2. **保存ボタン押下 (`saveAbsence`):**
   - フォームバリデーション実行 → 不正なら中断
   - `newAbsence.value.season_id = props.seasonId` を設定
   - `newAbsence.value.id` が存在 → `PUT /api/v1/player_absences/:id` (更新)
   - `newAbsence.value.id` が0 → `POST /api/v1/player_absences` (新規作成)
   - 成功時: `@saved` イベントを emit、ダイアログを閉じる
   - 失敗時: `useSnackbar` を使用してスナックバーでエラー通知（`playerAbsenceDialog.notifications.saveFailed`）

**国際化（i18n）キー:**
- `playerAbsenceDialog.title.add`: 新規追加時のタイトル
- `playerAbsenceDialog.title.edit`: 編集時のタイトル
- `playerAbsenceDialog.form.*`: 各フォームフィールドのラベル/バリデーションメッセージ
- `actions.cancel`: キャンセルボタン
- `actions.save`: 保存ボタン

---

### 離脱情報表示コンポーネント

**コンポーネント:** `src/components/AbsenceInfo.vue`

**用途:** シーズンポータル画面等で、指定日における離脱中の選手一覧をアラート形式で表示

**レイアウト:**
```
┌───────────────────────────────────────────┐
│ ⚠ 離脱情報 (11月20日)                     │
│ ──────────────────────────────────────── │
│ 【怪我】選手A: 右肘炎症 (11月15日から7日間) │
│ 【調整】選手B: 疲労 (11月18日から3試合)    │
└───────────────────────────────────────────┘
```
(離脱者がいない場合は `t('seasonPortal.noAbsenceInfo')` を表示、アラート色を `primary` に変更)

**props:**

| プロパティ | 型 | 説明 |
|----------|---|-----|
| `seasonId` | `number \| null` | シーズンID |
| `currentDate` | `string` | 基準日 (ISO8601形式) |

**動作フロー:**

1. **マウント時 & `seasonId` 変更時:**
   - `GET /api/v1/player_absences?season_id={seasonId}` で全離脱データ取得

2. **`filteredAbsences` 計算:**
   - `currentDate` を基準に、離脱期間中の選手をフィルタリング
   - `duration_unit === 'days'` の場合: `start_date` から `start_date + duration` 日の範囲内なら表示
   - `duration_unit === 'games'` の場合: バックエンドが算出した `effective_end_date` を使用してフィルタリング
     - `effective_end_date` が存在する場合: `start_date <= currentDate < effective_end_date` の範囲内なら表示
     - `effective_end_date` が `null` の場合（スケジュール未設定で終了日不明）: `start_date <= currentDate` なら離脱継続中とみなして表示

3. **表示テキスト生成 (`getAbsenceDisplayText`):**
   - `【{離脱種別}】{選手名}: {理由} ({開始日}から{期間}{単位})`

**国際化（i18n）キー:**
- `seasonPortal.absenceInfo`: アラートタイトル
- `seasonPortal.noAbsenceInfo`: 離脱者なしのメッセージ
- `enums.player_absence.absence_type.*`: 離脱種別表示名
- `enums.player_absence.duration_unit.*`: 期間単位表示名

---

## APIエンドポイント（バックエンド）

### 一般ユーザー向けAPI

**コントローラー:** `app/controllers/api/v1/player_absences_controller.rb`

**ベースパス:** `/api/v1/player_absences`

| メソッド | パス | アクション | 説明 | クエリパラメータ/リクエストボディ | レスポンス |
|---------|------|----------|------|---------------------------|----------|
| GET | `/` | `index` | 離脱一覧取得（シーズン単位） | `season_id` (必須) | `PlayerAbsence[]` (JSON配列) |
| POST | `/` | `create` | 新規離脱登録 | `player_absence: { team_membership_id, season_id, absence_type, reason, start_date, duration, duration_unit }` | 作成された `PlayerAbsence` (status: 201) |
| PATCH/PUT | `/:id` | `update` | 離脱情報更新 | `player_absence: { ... }` (許可されたパラメータのみ) | 更新された `PlayerAbsence` |
| DELETE | `/:id` | `destroy` | 離脱情報削除 | (なし) | 204 No Content |

**パラメータ許可リスト (`player_absence_params`):**
```ruby
:team_membership_id, :season_id, :absence_type, :reason, :start_date, :duration, :duration_unit
```

**エラーレスポンス:**
- `season_id` 未指定時 (index): `{ error: 'season_id is required' }` (status: 400)
- バリデーションエラー時 (create/update): `@player_absence.errors` (status: 422)

**関連処理:**
- `index`: `PlayerAbsence.where(season_id: params[:season_id]).includes(team_membership: :player)` でN+1クエリ回避
- `set_player_absence` (before_action): `PlayerAbsence.find(params[:id])` で取得 (update/destroy時)

---

### コミッショナー向けAPI

**コントローラー:** `app/controllers/api/v1/commissioner/player_absences_controller.rb`

**ベースパス:** `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**注:** ネストされたリソース構造。`team_membership_id` を親リソースとして扱う。

| メソッド | パス | アクション | 説明 | レスポンス |
|---------|------|----------|------|----------|
| GET | `/` | `index` | 指定チームメンバーの離脱一覧取得 | `PlayerAbsence[]` |
| GET | `/:id` | `show` | 離脱詳細取得 | `PlayerAbsence` |
| POST | `/` | `create` | 新規離脱登録 | 作成された `PlayerAbsence` (status: 201) |
| PATCH/PUT | `/:id` | `update` | 離脱情報更新 | 更新された `PlayerAbsence` |
| DELETE | `/:id` | `destroy` | 離脱情報削除 | 204 No Content |

**パラメータ許可リスト (`player_absence_params`):**
```ruby
:season_id, :absence_type, :start_date, :duration, :duration_unit
```
※ `team_membership_id`, `reason` は許可リストに含まれない（コミッショナー用は簡易版）

**関連処理:**
- `set_team_membership` (before_action): `TeamMembership.find(params[:team_membership_id])`
- `set_player_absence` (before_action): `@team_membership.player_absences.find(params[:id])` (show/update/destroy時)
- `index`: `@team_membership.player_absences` でメンバーシップに紐づく離脱のみ取得
- `create`: `@team_membership.player_absences.build(...)` でスコープ制約

**一般ユーザー向けAPIとの差異:**

| 項目 | 一般ユーザー | コミッショナー |
|-----|------------|--------------|
| エンドポイント構造 | フラット (`/player_absences`) | ネスト (`/.../team_memberships/:id/player_absences`) |
| 認証レベル | 要認証（コミッショナー権限不要） | コミッショナー権限必須 |
| `show` アクション | **なし** | あり |
| 許可パラメータ | `team_membership_id`, `reason` 含む (7項目) | `reason` 含まない (5項目) |
| `team_membership_id` の扱い | リクエストボディで指定 | URLパスから自動設定 |

---

## データモデル（バックエンド）

### テーブル定義: `player_absences`

**スキーマ:** `db/schema.rb:150-162`

| カラム名 | 型 | NULL | デフォルト | インデックス | 説明 |
|---------|---|------|----------|------------|-----|
| `id` | bigint | NO | (auto) | PRIMARY KEY | 主キー |
| `team_membership_id` | bigint | NO | - | index | チームメンバーシップID (外部キー) |
| `season_id` | bigint | NO | - | index | シーズンID (外部キー) |
| `absence_type` | integer | NO | - | - | 離脱種別 (enum: 0=injury, 1=suspension, 2=reconditioning) |
| `reason` | text | YES | - | - | 離脱理由 (フリーテキスト) |
| `start_date` | date | NO | - | - | 離脱開始日 |
| `duration` | integer | NO | - | - | 離脱期間（数値） |
| `duration_unit` | string | NO | - | - | 期間単位 ("days" または "games") |
| `created_at` | datetime | NO | - | - | 作成日時 |
| `updated_at` | datetime | NO | - | - | 更新日時 |

**外部キー制約:**
```ruby
add_foreign_key "player_absences", "team_memberships"
add_foreign_key "player_absences", "seasons"
```

---

### Railsモデル: `PlayerAbsence`

**ファイル:** `app/models/player_absence.rb`

**リレーション:**
```ruby
belongs_to :team_membership
belongs_to :season
```

**enum定義:**
```ruby
enum :absence_type, { injury: 0, suspension: 1, reconditioning: 2 }
```

**バリデーション:**

| カラム | ルール |
|-------|-------|
| `absence_type` | presence: true |
| `start_date` | presence: true |
| `duration` | presence: true, numericality: { only_integer: true, greater_than: 0 } |
| `duration_unit` | presence: true, inclusion: { in: %w(days games) } |

※ `reason` はオプショナル（NULL許可）

**インスタンスメソッド:**

```ruby
# 離脱期間の終了日（排他的: この日には復帰可能）
def effective_end_date
  if duration_unit == "days"
    start_date + duration.days
  else
    # games: シーズンスケジュールからgame_day/interleague_game_dayの日付を取得し、
    # start_date以降のN試合目の翌日を返す
    game_dates = season.season_schedules
      .where(date_type: %w[game_day interleague_game_day])
      .where("date >= ?", start_date)
      .order(:date)
      .limit(duration)
      .pluck(:date)

    return nil if game_dates.length < duration
    game_dates.last + 1.day
  end
end
```

**戻り値:**
- `days` 単位: `start_date + duration` 日（常に値を返す）
- `games` 単位: シーズンスケジュール上の `duration` 試合消化後の翌日。スケジュールが不足している場合は `nil` を返す（離脱継続中を意味する）

---

### シリアライザー: `PlayerAbsenceSerializer`

**ファイル:** `app/serializers/player_absence_serializer.rb`

**出力属性:**
```ruby
attributes :id, :team_membership_id, :season_id, :absence_type, :reason,
           :start_date, :duration, :duration_unit, :player_name, :effective_end_date
```

**カスタムメソッド:**
```ruby
def player_name
  object.team_membership.player.name
end
```

**注:** `effective_end_date` はモデルの `effective_end_date` メソッドから取得される（後述の「離脱期間の計算」を参照）。

**出力例 (JSON):**
```json
{
  "id": 1,
  "team_membership_id": 42,
  "season_id": 3,
  "absence_type": "injury",
  "reason": "右肘炎症",
  "start_date": "2024-11-15",
  "duration": 7,
  "duration_unit": "days",
  "player_name": "霧雨 魔理沙",
  "effective_end_date": "2024-11-22"
}
```

---

## ビジネスロジック

### 離脱登録フロー

1. **前提条件:**
   - 選手がチームに所属している (`team_membership` レコードが存在)
   - シーズンが存在している (`season` レコードが存在)

2. **登録処理:**
   - ユーザーが離脱フォームで以下を入力:
     - 選手 (team_membership_id)
     - 離脱種別 (injury/suspension/reconditioning)
     - 理由 (任意)
     - 開始日
     - 期間 (正の整数)
     - 期間単位 (days/games)
   - フロントエンドでバリデーション
   - `POST /api/v1/player_absences` でバックエンドに送信
   - バックエンドでモデルバリデーション → DB保存
   - シリアライザーで選手名を付与してレスポンス

3. **復帰処理:**
   - **明示的な「復帰」機能は未実装**
   - 離脱レコードの削除 (`DELETE`) が実質的な復帰操作となる
   - または離脱期間の修正 (`PUT/PATCH`) で期間を短縮

### 離脱期間の計算

**days 単位の場合:**
- 開始日: `start_date`
- 終了日（排他的）: `start_date + duration` 日後
- 例: 11月15日開始、7日間 → `effective_end_date` = 11月22日（11月15日〜21日の7日間離脱、22日から復帰可能）

**games 単位の場合:**
- バックエンド（`PlayerAbsence#effective_end_date`）がシーズンスケジュール（`season_schedules` テーブル）を参照し、`start_date` 以降の `game_day` / `interleague_game_day` 日付を `duration` 件取得
- 最後の試合日の翌日を `effective_end_date` として返す
- スケジュールが不足している場合（未設定等）は `nil` を返す
- フロントエンド（`AbsenceInfo.vue`）は `effective_end_date` を用いてフィルタリングし、`null` の場合は離脱継続中として扱う

### ロースター管理との連携

**現状:**
- `PlayerAbsence` モデルはロースター (`SeasonRoster`) とは独立して管理されている
- 離脱中の選手をロースターに登録しようとした場合、フロントエンド（`ActiveRoster.vue`）で警告表示が行われる（UNIMPL-014対応）
- 離脱情報は `AbsenceInfo.vue` コンポーネントでシーズンポータル画面等に表示される

---

## フロントエンド実装詳細

### TypeScript型定義

**ファイル:** `src/types/playerAbsence.ts`

```typescript
export interface PlayerAbsence {
  id: number
  team_membership_id: number
  season_id: number
  absence_type: 'injury' | 'suspension' | 'reconditioning'
  reason: string | null
  start_date: string // ISO8601 date string
  duration: number
  duration_unit: 'days' | 'games'
  effective_end_date: string | null // バックエンドが算出する終了日（排他的）
  created_at: string
  updated_at: string
  player_name: string // シリアライザーで付与
}
```

### コンポーネント構成

```
PlayerAbsenceHistory.vue (離脱履歴画面)
  ├─ TeamNavigation.vue (チーム関連画面のタブナビゲーション)
  ├─ PlayerAbsenceFormDialog.vue (登録/編集ダイアログ)
  │    └─ TeamMemberSelect.vue (選手選択コンポーネント)
  └─ (v-data-table: Vuetify標準)

AbsenceInfo.vue (離脱情報表示アラート)
  └─ (独立コンポーネント、SeasonPortal等で使用)
  └─ defineExpose: fetchPlayerAbsences (親コンポーネントから再取得を呼び出し可能)
```

### API呼び出しパターン

**一覧取得:**
```typescript
const response = await axios.get('/player_absences', {
  params: { season_id: seasonId }
})
playerAbsences.value = response.data
```

**新規作成:**
```typescript
const response = await axios.post('/player_absences', {
  team_membership_id: ...,
  season_id: ...,
  absence_type: 'injury',
  reason: '...',
  start_date: '2024-11-15',
  duration: 7,
  duration_unit: 'days'
})
```

**更新:**
```typescript
const response = await axios.put(`/player_absences/${id}`, playerAbsenceData)
```

**削除:**
```typescript
await axios.delete(`/player_absences/${id}`)
```

### 状態管理

- **グローバル状態管理なし** (Pinia/Vuex不使用)
- 各コンポーネントで `ref()` を使ったローカル状態管理
- `PlayerAbsenceHistory.vue` → `PlayerAbsenceFormDialog.vue` 間は props/emit パターン:
  - props: `modelValue` (ダイアログ開閉), `initialAbsence` (編集対象データ), `seasonId`, `teamId`, `initialStartDate`
  - emit: `saved` (保存完了通知)

---

## ルーティング設定

**バックエンド:** `config/routes.rb`

**一般ユーザー向け (52行目):**
```ruby
resources :player_absences, only: [:index, :create, :update, :destroy]
```

**コミッショナー向け:**
```ruby
namespace :commissioner do
  resources :leagues do
    resources :teams do
      resources :team_memberships, only: [:index, :update, :destroy] do
        resources :player_absences, only: [:index, :create, :update, :destroy]
      end
    end
  end
end
```

**生成されるルート例:**

一般ユーザー:
- `GET    /api/v1/player_absences`
- `POST   /api/v1/player_absences`
- `PATCH  /api/v1/player_absences/:id`
- `DELETE /api/v1/player_absences/:id`

コミッショナー:
- `GET    /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences`
- `POST   /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences`
- `PATCH  /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences/:id`
- `DELETE /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences/:id`

---

## 未実装機能・今後の課題

1. ~~**games 単位の離脱期間フィルタリング**~~ **実装済み**
   - バックエンド: `PlayerAbsence#effective_end_date` メソッドでシーズンスケジュールを参照し終了日を算出
   - フロントエンド: `AbsenceInfo.vue` が `effective_end_date` を使用してフィルタリング

2. ~~**エラーハンドリングの強化**~~ **実装済み**
   - `PlayerAbsenceFormDialog.vue` で `useSnackbar` を使用し、保存失敗時にスナックバーで通知

3. **ロースター管理との連携**
   - 離脱中の選手をロースターに登録しようとした場合の警告表示は実装済み（UNIMPL-014対応）
   - 離脱期間終了時の自動復帰通知は未実装

4. **コミッショナー向けAPIの `reason` パラメータ**
   - 現在は許可リストに含まれていないが、理由入力が必要な場合は追加検討

---

## 参考情報

- **関連モデル:**
  - `TeamMembership` (選手のチーム所属情報)
  - `Season` (シーズン管理)
  - `Player` (選手マスタ)
  - `SeasonRoster` (シーズン別ロースター)

- **依存コンポーネント:**
  - `TeamMemberSelect.vue` (shared component、チームメンバー選択用ドロップダウン)
  - `TeamNavigation.vue` (チーム関連画面のタブナビゲーション)

- **i18n設定ファイル:** `src/locales/ja.json` (日本語翻訳)

---

**仕様書バージョン:** 1.1
**作成日:** 2026-02-14
**更新日:** 2026-02-21
**ソースコード参照日:** 2026-02-21
