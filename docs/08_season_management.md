# シーズン管理

## 概要

シーズン管理は、チームごとの年間シーズン進行を管理する機能である。日程表（Schedule）を元にシーズンを初期化し、カレンダーUI上で日々の進行（current_date の更新）、日程種別の変更、試合結果の確認、キープレイヤーの設定を行う。

1チームにつき1シーズンのみ存在可能（`team_id` に uniqueness バリデーション）。シーズン作成時に日程表テンプレート（`Schedule` + `ScheduleDetail`）から `SeasonSchedule` レコードを一括生成し、以降はシーズン固有のデータとして独立管理する。

シーズンには関連機能として、ロスター管理（09_roster_management）、試合管理（10_game_management）、選手離脱（11_player_absence）が紐づく。

## 画面構成（フロントエンド）

### シーズンポータル画面（SeasonPortal）

- **パス**: `/teams/:teamId/season`（推定: ルーター設定に基づく）
- **コンポーネント**: `src/views/SeasonPortal.vue`
- **API呼び出し**: `GET /teams/:teamId/season`（シーズン詳細取得）

#### ツールバー

| 要素 | 色 | 動作 | 条件 |
|------|-----|------|------|
| シーズン名（h1） | — | 表示のみ | `season.name` |
| 試合結果入力ボタン | primary | `GameResult` 画面へ遷移 | 当日が試合日（`game_day`, `interleague_game_day`, `playoff_day`, `no_game`）の場合のみ有効 |
| 登録選手ボタン | secondary | `/teams/:teamId/roster` へ遷移 | 常時有効 |
| 離脱登録ボタン | red | `PlayerAbsenceFormDialog` を開く | 常時有効 |
| 離脱履歴ボタン | red-darken-4 | `PlayerAbsenceHistory` 画面へ遷移 | 常時有効 |
| ◀ / ▶（日付移動） | — | `prevDay()` / `nextDay()` で `current_date` を±1日更新 | 開始日以前 / 終了日以降は disabled |
| 現在日付表示 | — | `ja-JP` ロケールで「○月○日」形式 | — |

#### カレンダー表示

- **グリッド**: 7列（月曜始まり）× 動的行数
- **曜日ヘッダー**: `Intl.DateTimeFormat('ja-JP', { weekday: 'short' })` で生成
- **セルの色分け**:
  - 土曜: `#e0f2f7`（水色）
  - 日曜: `#ffebee`（薄赤）
  - 当日（current_date）: `#FFFDE7`（薄黄）+ 黄色ボーダー
  - 当月外: `#f9f9f9`（グレー）

#### 日程種別ボタンと変更

各日のセルに日程種別ボタンが表示され、クリックすると `v-menu` で種別変更が可能。

| 日程種別 | 表示色 | 試合結果入力リンク |
|----------|--------|-------------------|
| `game_day` | blue | あり |
| `interleague_game_day` | deep-purple | あり |
| `playoff_day` | pink | あり |
| `travel_day` | grey | なし |
| `reserve_day` | blue-grey | なし |
| `interleague_reserve_day` | brown | なし |
| `no_game_day` | red | なし |
| `postponed` | indigo | なし |
| `no_game` | indigo | あり |

- `current_date` より前の日付のボタンは `disabled`（変更不可）
- 日程種別変更時: `PATCH /teams/:teamId/season/season_schedules/:id` を呼び出し、ローカルの `season_schedules` 配列も即時更新

#### 試合結果表示（カレンダーセル内）

試合日（`game_day`, `interleague_game_day`, `playoff_day`）のセルには追加情報を表示:

- **試合結果あり**: `vs. {opponent_short_name} {score}` + 勝敗チップ（win=success/○, lose=error/×, draw=grey/△）
- **試合結果なし・先発予告あり**: `先発予告: {announced_starter.name}`

#### 月移動

- ◀ / ▶ ボタンで `currentDate` の月を±1切り替え
- カレンダーグリッドは `currentDate` の月を基準に再計算

#### 離脱情報

- `AbsenceInfo` コンポーネント（`ref="absenceInfo"`）がカレンダー上部に表示
- 離脱登録ダイアログ保存後、`absenceInfo.fetchPlayerAbsences()` を呼び出して再取得

### シーズン初期化ダイアログ（SeasonInitializationDialog）

- **コンポーネント**: `src/components/SeasonInitializationDialog.vue`
- **表示トリガー**: 親コンポーネントから `isVisible` prop で制御

#### フォームフィールド

| フィールド | v-model | 入力形式 | 説明 |
|-----------|---------|---------|------|
| シーズン名 | `seasonName` | `v-text-field` | 必須。シーズンの表示名 |
| 日程表選択 | `selectedSchedule` | `v-select`（`item-title="name"`, `item-value="id"`） | 必須。`ScheduleList[]` から選択 |

#### Props

| Prop | 型 | 説明 |
|------|-----|------|
| `isVisible` | `boolean` | ダイアログ表示状態 |
| `schedules` | `ScheduleList[]` | 選択可能な日程表一覧 |
| `selectedTeam` | `Team \| null` | シーズンを初期化するチーム |

#### 動作フロー

1. ユーザーがシーズン名を入力し、日程表を選択
2. 「初期化」ボタンクリック → `POST /seasons` に `{ team_id, schedule_id, name }` を送信
3. 成功時: フォームリセット + `emit('save')` で親に通知 + ダイアログ閉じる
4. ダイアログ非表示時: `watch` でフォーム値を自動リセット

## APIエンドポイント

### シーズン作成

```
POST /api/v1/seasons
```

**コントローラー**: `Api::V1::SeasonsController#create`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `team_id` | integer | ○ | チームID |
| `schedule_id` | integer | ○ | 日程表テンプレートID |
| `name` | string | ○ | シーズン名 |

**処理フロー**（トランザクション内）:

1. `Team.find(params[:team_id])` でチーム取得
2. `Schedule.find(params[:schedule_id])` で日程表テンプレート取得
3. `Season.create!` で新シーズン作成（`current_date` は `schedule.start_date` で初期化）
4. `schedule.schedule_details` を全件ループし、各 `ScheduleDetail` から `SeasonSchedule.create!` を実行
   - `date` → `detail.date`
   - `date_type` → `detail.date_type`

**レスポンス**:

| ステータス | 条件 | Body |
|-----------|------|------|
| `201 Created` | 成功 | `{ season: Season, schedule_count: Integer }` |
| `404 Not Found` | チームまたは日程表が存在しない | `{ error: message }` |
| `422 Unprocessable Entity` | バリデーションエラー（チーム重複等） | `{ error: message }` |

### シーズン詳細取得

```
GET /api/v1/teams/:team_id/season
```

**コントローラー**: `Api::V1::TeamSeasonsController#show`

**処理**: `team.season` を取得し、`SeasonDetailSerializer` でシリアライズ

**レスポンス**:

| ステータス | 条件 | Body |
|-----------|------|------|
| `200 OK` | シーズンあり | `SeasonDetailSerializer` の出力（後述） |
| `404 Not Found` | チームにシーズンなし | `{ error: 'Season not found for this team' }` |

### シーズン現在日付更新

```
PATCH /api/v1/teams/:team_id/season
```

**コントローラー**: `Api::V1::TeamSeasonsController#update`

**パラメータ**: `season[current_date]`（date 形式）

**Strong Parameters**: `params.require(:season).permit(:current_date)`

**レスポンス**:

| ステータス | 条件 | Body |
|-----------|------|------|
| `200 OK` | 成功 | `{ season: Season }` |
| `404 Not Found` | チームが存在しない | `{ error: message }` |
| `422 Unprocessable Entity` | 更新失敗 | `{ errors: [messages] }` |

### シーズン日程種別更新

```
PATCH /api/v1/teams/:team_id/season/season_schedules/:id
```

**コントローラー**: `Api::V1::TeamSeasonsController#update_season_schedule`

**パラメータ**: `season_schedule[date_type]`（string）

**Strong Parameters**: `params.require(:season_schedule).permit(:date_type)`

**レスポンス**:

| ステータス | 条件 | Body |
|-----------|------|------|
| `200 OK` | 成功 | `SeasonSchedule` のJSON |
| `422 Unprocessable Entity` | 更新失敗 | バリデーションエラー |

### キープレイヤー設定

```
POST /api/v1/teams/:team_id/key_player
```

**コントローラー**: `Api::V1::TeamKeyPlayersController#create`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `key_player_id` | integer / null | — | `TeamMembership` のID。null で未設定 |

**ビジネスルール**: シーズン初日（`season_schedules` の最小日付）にのみ設定可能。`current_date != start_date` の場合はエラー。

**レスポンス**:

| ステータス | 条件 | Body |
|-----------|------|------|
| `200 OK` | 成功 | `{ message: 'Key player set successfully' }` |
| `400 Bad Request` | シーズン未初期化 | `{ error: 'Season not initialized for this team' }` |
| `400 Bad Request` | シーズン初日でない | `{ error: 'キープレイヤーはシーズン初日のみ設定可能です。' }` |
| `404 Not Found` | チームが存在しない | `{ error: message }` |
| `422 Unprocessable Entity` | 更新失敗 | `{ error: message }` |

## ルーティング定義

```ruby
# config/routes.rb（抜粋）
resources :teams, only: [...] do
  resource :season, only: [:show, :update], controller: 'team_seasons' do
    patch 'season_schedules/:id', to: 'team_seasons#update_season_schedule'
  end
  resource :key_player, only: [:create], controller: 'team_key_players'
end

resources :seasons, only: [:create]
```

**ポイント**:
- `season` は `resource`（単数リソース）— チームに対して1つしか存在しないため
- `season_schedules/:id` は `season` のネスト内でカスタムルート
- `key_player` も `resource`（単数リソース）で `teams` のネスト内
- `seasons`（複数リソース）の `create` は独立ルートとして定義（チームネスト外）

## データモデル

### seasons テーブル

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `id` | bigint | NO | (auto) | 主キー |
| `team_id` | bigint | NO | — | 所属チーム（FK → teams） |
| `name` | string | NO | — | シーズン名（例: 「2025年シーズン」） |
| `current_date` | date | NO | — | 現在進行中の日付（シーズン作成時は `schedule.start_date`） |
| `key_player_id` | bigint | YES | — | キープレイヤー（FK → team_memberships） |
| `team_type` | string | YES | — | チーム種別（用途未使用） |
| `created_at` | datetime | NO | — | 作成日時 |
| `updated_at` | datetime | NO | — | 更新日時 |

**インデックス**:
- `index_seasons_on_team_id` (`team_id`)
- `index_seasons_on_key_player_id` (`key_player_id`)

**外部キー制約**:
- `team_id` → `teams.id`
- `key_player_id` → `team_memberships.id`

### season_schedules テーブル

| カラム | 型 | NULL | デフォルト | 説明 |
|--------|-----|------|-----------|------|
| `id` | bigint | NO | (auto) | 主キー |
| `season_id` | bigint | NO | — | 所属シーズン（FK → seasons） |
| `date` | date | NO | — | 日付 |
| `date_type` | string | YES | — | 日程種別（後述） |
| `announced_starter_id` | bigint | YES | — | 先発予告投手（FK → team_memberships） |
| `oppnent_team_id` | bigint | YES | — | 対戦相手チーム（FK → teams）※カラム名 typo |
| `game_number` | integer | YES | — | 試合番号 |
| `stadium` | string | YES | — | 球場名 |
| `home_away` | string | YES | — | ホーム/アウェイ |
| `designated_hitter_enabled` | boolean | YES | — | DH制有無 |
| `score` | integer | YES | — | 自チームスコア |
| `oppnent_score` | integer | YES | — | 相手チームスコア ※カラム名 typo |
| `winning_pitcher_id` | bigint | YES | — | 勝利投手（FK → players） |
| `losing_pitcher_id` | bigint | YES | — | 敗戦投手（FK → players） |
| `save_pitcher_id` | bigint | YES | — | セーブ投手（FK → players） |
| `scoreboard` | jsonb | YES | — | スコアボード（イニング別得点等） |
| `starting_lineup` | jsonb | YES | — | 自チームスターティングラインナップ |
| `opponent_starting_lineup` | jsonb | YES | — | 相手チームスターティングラインナップ |
| `created_at` | datetime | NO | — | 作成日時 |
| `updated_at` | datetime | NO | — | 更新日時 |

**インデックス**:
- `index_season_schedules_on_season_id`
- `index_season_schedules_on_announced_starter_id`
- `index_season_schedules_on_oppnent_team_id`
- `index_season_schedules_on_winning_pitcher_id`
- `index_season_schedules_on_losing_pitcher_id`
- `index_season_schedules_on_save_pitcher_id`

**外部キー制約**:
- `season_id` → `seasons.id`
- `announced_starter_id` → `team_memberships.id`
- `oppnent_team_id` → `teams.id`
- `winning_pitcher_id` → `players.id`
- `losing_pitcher_id` → `players.id`
- `save_pitcher_id` → `players.id`

### date_type の値一覧

| 値 | 意味 |
|----|------|
| `game_day` | 通常試合日 |
| `interleague_game_day` | 交流戦試合日 |
| `playoff_day` | プレーオフ試合日 |
| `travel_day` | 移動日 |
| `reserve_day` | 予備日 |
| `interleague_reserve_day` | 交流戦予備日 |
| `no_game_day` | 試合なし日 |
| `postponed` | 延期 |
| `no_game` | ノーゲーム（中止等。試合結果入力画面へのリンクあり） |

### リレーション

```
Season
  belongs_to :team                    # 1チームに1シーズン
  belongs_to :key_player              # class_name: 'TeamMembership', optional: true
  has_many   :season_schedules        # dependent: :destroy
  has_many   :player_absences         # dependent: :destroy

SeasonSchedule
  belongs_to :season
  belongs_to :announced_starter       # class_name: 'TeamMembership', optional: true
  belongs_to :opponent_team           # class_name: 'Team', foreign_key: 'oppnent_team_id', optional: true
  belongs_to :winning_pitcher         # class_name: 'Player', optional: true
  belongs_to :losing_pitcher          # class_name: 'Player', optional: true
  belongs_to :save_pitcher            # class_name: 'Player', optional: true

Team
  has_one :season                     # dependent: :restrict_with_error
```

### バリデーション

**Season**:
- `name`: presence（必須）
- `team_id`: uniqueness（1チーム1シーズン。メッセージ: 「は既にシーズンが開始されています。」）

**SeasonSchedule**:
- モデルレベルのバリデーションなし（DB制約として `season_id`, `date` が NOT NULL）

## シリアライザー

### SeasonDetailSerializer

```ruby
class SeasonDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :current_date, :start_date, :end_date
  has_many :season_schedules, serializer: SeasonScheduleSerializer
end
```

**計算属性**:
- `start_date`: `season_schedules.minimum(:date)` — シーズンスケジュールの最小日付
- `end_date`: `season_schedules.maximum(:date)` — シーズンスケジュールの最大日付

**出力例**:
```json
{
  "id": 1,
  "name": "2025年シーズン",
  "current_date": "2025-04-01",
  "start_date": "2025-03-28",
  "end_date": "2025-10-15",
  "season_schedules": [...]
}
```

### SeasonScheduleSerializer

```ruby
class SeasonScheduleSerializer < ActiveModel::Serializer
  attributes :id, :date, :date_type, :announced_starter, :game_result
end
```

**計算属性**:

- `announced_starter`: `announced_starter_id` が設定されている場合、関連する `TeamMembership` → `Player` から `{ id, name }` を返す。未設定時は `nil`。
- `game_result`: `score` と `oppnent_score` が両方存在する場合のみ生成。
  ```json
  {
    "opponent_short_name": "チームA",
    "score": "5 - 3",
    "result": "win"  // "win" | "lose" | "draw"
  }
  ```
  - `result` の判定: `score > oppnent_score` → `"win"`, `score < oppnent_score` → `"lose"`, 同点 → `"draw"`

## ビジネスロジック

### シーズン初期化

1. 既に `team_id` に紐づくシーズンが存在する場合、uniqueness バリデーションにより作成失敗（422）
2. `Schedule` の `start_date` が `Season.current_date` の初期値となる
3. `ScheduleDetail` の全レコードが `SeasonSchedule` にコピーされる（`date`, `date_type` のみ。試合結果系カラムは NULL）

### 日付進行

- フロントエンドの ◀ / ▶ ボタンで `current_date` を1日ずつ増減
- `PATCH /teams/:team_id/season` で `current_date` をサーバーに永続化
- `start_date`（スケジュール最小日付）以前・`end_date`（最大日付）以降への移動は UI で disabled

### キープレイヤー設定

- **設定可能条件**: `season.current_date == season_schedules.minimum(:date)`（シーズン初日のみ）
- **対象**: `TeamMembership` のID（チーム所属選手）。`null` 送信でキープレイヤー解除
- **保存先**: `seasons.key_player_id`
- **制約**: シーズン初日を過ぎると変更不可

### 日程種別変更

- `current_date` 以降の日程のみ変更可能（フロントエンドで制御。`isDateBeforeCurrent()` で判定）
- バックエンド側には日付制限のバリデーションなし（フロントエンドのみで制御）

## フロントエンド実装詳細

### コンポーネント構成

| コンポーネント | パス | 役割 |
|---------------|------|------|
| `SeasonPortal` | `src/views/SeasonPortal.vue` | シーズンメイン画面。カレンダー表示・日付進行・日程変更 |
| `SeasonInitializationDialog` | `src/components/SeasonInitializationDialog.vue` | シーズン初期化ダイアログ |
| `AbsenceInfo` | `src/components/AbsenceInfo.vue` | 現在日付の離脱選手情報表示 |
| `PlayerAbsenceFormDialog` | `src/components/PlayerAbsenceFormDialog.vue` | 離脱登録フォームダイアログ |

### 型定義

#### SeasonDetail (`src/types/seasonDetail.ts`)

```typescript
import type { SeasonSchedule } from './seasonSchedule';

export interface SeasonDetail {
  id: number;
  name: string;
  current_date: string;   // "YYYY-MM-DD"
  start_date: string;     // "YYYY-MM-DD"（サーバー計算値）
  end_date: string;       // "YYYY-MM-DD"（サーバー計算値）
  season_schedules: SeasonSchedule[];
}
```

#### SeasonSchedule (`src/types/seasonSchedule.ts`)

```typescript
export interface SeasonSchedule {
  id: number;
  date: string;           // "YYYY-MM-DD"
  date_type: string;      // date_type の値一覧参照
  announced_starter?: { id: number; name: string };
  game_result?: {
    opponent_short_name: string;
    score: string;         // "5 - 3" 形式
    result: 'win' | 'lose' | 'draw';
  };
}
```

### API呼び出し一覧

| 操作 | HTTP | URL | タイミング |
|------|------|-----|-----------|
| シーズン詳細取得 | GET | `/teams/:teamId/season` | `onMounted` |
| 現在日付更新 | PATCH | `/teams/:teamId/season` | ◀ / ▶ ボタン押下時 |
| 日程種別変更 | PATCH | `/teams/:teamId/season/season_schedules/:id` | 日程種別メニュー選択時 |
| シーズン初期化 | POST | `/seasons` | SeasonInitializationDialog で初期化実行時 |
| キープレイヤー設定 | POST | `/teams/:teamId/key_player` | キープレイヤー設定時 |

### 状態管理

- `season`: `ref<SeasonDetail | null>` — サーバーから取得したシーズン詳細
- `currentDate`: `ref<Date>` — カレンダー表示・日付進行の基準日
- `formattedCurrentDate`: `computed` — `currentDate` を `YYYY-MM-DD` 形式に変換
- `isDialogOpen`: `ref<boolean>` — 離脱登録ダイアログの開閉状態

状態はコンポーネントローカルで管理され、Vuex/Pinia 等のグローバルストアは使用しない。`fetchSeason()` でサーバーから再取得することでデータの一貫性を保つ。
