# 日程管理

## 概要

日程表（スケジュール）マスタの管理機能。シーズン運営に必要な日程表テンプレートを作成・編集し、各日付ごとに「試合日」「移動日」「予備日」等の日程タイプを割り当てる。作成した日程表はシーズン初期化時に適用され、シーズンスケジュール（`season_schedules`）の雛形となる。

日程管理は以下の2階層で構成される:

1. **日程表（Schedule）**: 名前・開始日・終了日・適用日を持つマスタ
2. **日程詳細（ScheduleDetail）**: 日程表に紐づく各日付とその日程タイプ

## 画面構成（フロントエンド）

### 日程管理画面

日程管理は設定画面（Settings）の「チーム運営」タブ内に配置される。

- **パス**: `/settings`（「チーム運営」タブ）
- **親コンポーネント**: `src/views/Settings.vue`
- **コンポーネント**: `src/components/settings/ScheduleSettings.vue`
- **ルート設定**: `meta: { requiresAuth: true, title: '各種設定' }`

#### 画面レイアウト

```
Settings画面
├─ タブ: 選手設定 | チーム運営
│
└─ チーム運営タブ
   ├─ [左列 cols=6] コスト設定（CostSettings）
   └─ [右列 cols=6] 日程表設定（ScheduleSettings）
                ├─ タイトル「日程表」+ [日程表を追加] ボタン
                └─ v-data-table
                   ├─ 名前 | 開始日 | 終了日 | 適用日 | 操作
                   └─ 操作列: [カレンダー編集] [編集] [削除]
```

#### 一覧テーブル

Vuetify `v-data-table` を使用。`GET /api/v1/schedules` で取得したデータを表示する。

| ヘッダー | キー | ソート | 説明 |
|---------|------|--------|------|
| 名前 | `name` | 可 | 日程表の名称 |
| 開始日 | `start_date` | 可 | 日程の開始日 |
| 終了日 | `end_date` | 可 | 日程の終了日 |
| 適用日 | `effective_date` | 可 | シーズンへの適用日 |
| 操作 | `actions` | 不可 | アイコンボタン3つ |

#### 操作アイコン

| アイコン | 動作 |
|---------|------|
| `mdi-calendar-edit` | 日程詳細エディター（`ScheduleDetailEditor`）を開く |
| `mdi-pencil` | 日程表編集ダイアログ（`ScheduleDialog`）を開く |
| `mdi-delete` | 確認ダイアログ（`confirm()`）表示後、`DELETE /api/v1/schedules/:id` で削除 |

#### データ取得

```typescript
const fetchSchedules = async () => {
  const response = await axios.get<ScheduleList[]>('/schedules');
  schedules.value = response.data;
};
```

- マウント時（`onMounted`）に自動取得
- ダイアログでの保存完了時（`@save` イベント）に再取得

---

### 日程表ダイアログ（ScheduleDialog）

- **コンポーネント**: `src/components/settings/ScheduleDialog.vue`
- **用途**: 日程表の新規作成・編集

#### ダイアログレイアウト

```
+----------------------------------+
|  日程表の追加 / 日程表の編集     |
|                                  |
|  名前:    [________________]     |
|  開始日:  [____-__-__]           |
|  終了日:  [____-__-__]           |
|  適用日:  [____-__-__]           |
|                                  |
|          [キャンセル] [保存]      |
+----------------------------------+
```

- ダイアログ幅: `max-width="500px"`

#### フォームフィールド

| フィールド | v-model | type | バリデーション | 説明 |
|-----------|---------|------|-------------|------|
| 名前 | `editableSchedule.name` | text | `required` | 日程表名 |
| 開始日 | `editableSchedule.start_date` | date | `required` | 期間開始日 |
| 終了日 | `editableSchedule.end_date` | date | `required` | 期間終了日 |
| 適用日 | `editableSchedule.effective_date` | date | なし | シーズン適用日（任意） |

- ラベルは `vue-i18n` による国際化対応済み（`t('settings.schedule.dialog.form.*')`）
- バリデーションルール: `(value: string) => !!value || t('validation.required')`

#### 動作フロー

1. **新規作成**（`schedule` prop が `null`）:
   - タイトル: 「日程表の追加」（`t('settings.schedule.dialog.title.add')`）
   - `editableSchedule` を空のデフォルト値で初期化
   - 保存: `POST /api/v1/schedules` に `{ schedule: { name, start_date, end_date, effective_date } }` を送信

2. **編集**（`schedule` prop がオブジェクト）:
   - タイトル: 「日程表の編集」（`t('settings.schedule.dialog.title.edit')`）
   - `editableSchedule` を props のコピーで初期化（`watch` で反応）
   - 保存: `PATCH /api/v1/schedules/:id` に `{ schedule: { name, start_date, end_date, effective_date } }` を送信

3. 保存成功時: `save` イベントを emit → 親が `fetchSchedules()` を再実行

#### 保存ロジック

```typescript
const save = async () => {
  const { id, ...scheduleData } = editableSchedule.value as ScheduleList;
  const payload = { schedule: scheduleData };

  if (props.schedule) {
    await axios.patch(`/schedules/${props.schedule.id}`, payload);
  } else {
    await axios.post('/schedules', payload);
  }
  emit('save');
  closeDialog();
};
```

- `id` を分割代入で除外し、APIリクエストのペイロードに含めない
- `props.schedule` の有無で新規作成（POST）と更新（PATCH）を切り替え

---

### 日程詳細エディター（ScheduleDetailEditor）

- **コンポーネント**: `src/components/settings/ScheduleDetailEditor.vue`
- **用途**: 日程表内の各日付に日程タイプを割り当てる

#### ダイアログレイアウト

```
+------------------------------------------------------+
|  日程詳細の設定                                       |
|                                                      |
|  [左列 cols=4]                [右列 cols=8]           |
|  選択日付の表示               v-date-picker           |
|                              (日付ごとに色分け表示)   |
|  ○ 試合日(青)                                        |
|  ○ 交流戦試合日(紫)                                  |
|  ○ プレーオフ日(ピンク)                               |
|  ○ 移動日(グレー)                                    |
|  ○ 予備日(ブルーグレー)                               |
|  ○ 交流戦予備日(ブラウン)                             |
|  ○ 試合不可日(赤)                                    |
|                                                      |
|                       [キャンセル] [保存]             |
+------------------------------------------------------+
```

- ダイアログ幅: `max-width="600px"`

#### 日程タイプ一覧

| 値 | ラベル | 色 | 説明 |
|---|--------|-----|------|
| `game_day` | 試合日 | blue | 通常の試合が行われる日 |
| `interleague_game_day` | 交流戦試合日 | deep-purple | 交流戦の試合が行われる日 |
| `playoff_day` | プレーオフ日 | pink | プレーオフの試合が行われる日 |
| `travel_day` | 移動日 | grey | チーム移動日（試合なし） |
| `reserve_day` | 予備日 | blue-grey | 通常の予備日（雨天順延等に使用） |
| `interleague_reserve_day` | 交流戦予備日 | brown | 交流戦の予備日 |
| `no_game_day` | 試合不可日 | red | 試合を行わない日 |

翻訳ファイル（`ja.json`）にはさらに `postponed`（雨天中止）と `no_game`（雨天ノーゲーム）の定義があるが、日程詳細エディターのラジオボタン選択肢には含まれていない。これらはシーズン運用中の状態変更で使用される日程タイプである。

#### カレンダー（v-date-picker）

| プロパティ | 値 | 説明 |
|-----------|-----|------|
| `min` | `props.schedule?.start_date` | 日程表の開始日 |
| `max` | `props.schedule?.end_date` | 日程表の終了日 |
| `first-day-of-week` | `1` | 月曜始まり |
| `show-adjacent-months` | `true` | 前後月の日付を表示 |

- 各日付セルはカスタムスロット（`#day`）で描画
- `scheduleDetails` 配列から一致する日付を検索し、対応する `date_type` の色で `v-btn` を表示
- 範囲外の日付は `disabled`

#### 動作フロー

1. ダイアログ表示時: `GET /api/v1/schedules/:id/schedule_details` で既存の日程詳細を取得
2. カレンダーから日付をクリック → `calendarDate` が更新される
3. ラジオボタンで日程タイプを選択 → `selectedDateType` の `watch` が発火:
   - 既に該当日付のデータが `scheduleDetails` にあれば `date_type` を上書き
   - なければ新しい `ScheduleDetail` エントリを配列に追加
4. 保存ボタン: `POST /api/v1/schedules/:id/schedule_details/upsert_all` に全 `scheduleDetails` を一括送信

#### 日付→文字列変換

```typescript
const dateToString = (date: Date) => {
  return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
};
```

`Date` オブジェクトを `"YYYY-MM-DD"` 形式の文字列に変換。APIとのデータ交換およびカレンダー上の日付マッチングに使用。

#### 保存ロジック

```typescript
const save = async () => {
  if (!props.schedule) return;
  const payload = { schedule_details: scheduleDetails.value };
  await axios.post(`/schedules/${props.schedule.id}/schedule_details/upsert_all`, payload);
  emit('save');
  closeDialog();
};
```

- 全日程詳細を一括送信（個別の差分送信ではない）
- バックエンドの `upsert_all` が衝突処理を行うため、新規・更新を区別する必要がない

## APIエンドポイント

### 共通事項

- **ベースURL**: `/api/v1`
- **認証**: `Api::V1::SchedulesController` は `ApplicationController` を直接継承している。ルーティングは `/api/v1` namespace 内に定義されている
- **レスポンス形式**: JSON（日程表は `ScheduleSerializer` によるシリアライズ、日程詳細は `render json:` による直接シリアライズ）

---

### GET /api/v1/schedules

全日程表の一覧を取得する。

#### リクエスト

```
GET /api/v1/schedules
```

#### 成功レスポンス（200 OK）

```json
[
  {
    "id": 1,
    "name": "2026年前期日程",
    "start_date": "2026-04-01",
    "end_date": "2026-09-30",
    "effective_date": "2026-04-01"
  }
]
```

#### 処理フロー

1. `Schedule.all` で全日程表を取得
2. `ScheduleSerializer` でシリアライズして返却

---

### POST /api/v1/schedules

新規日程表を作成する。

#### リクエスト

```
POST /api/v1/schedules
Content-Type: application/json
```

```json
{
  "schedule": {
    "name": "2026年前期日程",
    "start_date": "2026-04-01",
    "end_date": "2026-09-30",
    "effective_date": "2026-04-01"
  }
}
```

#### 許可パラメータ

```ruby
params.require(:schedule).permit(:name, :start_date, :end_date, :effective_date)
```

#### 成功レスポンス（201 Created）

シリアライズされた日程表オブジェクトを返す。

#### 失敗レスポンス（422 Unprocessable Entity）

```json
{
  "name": ["can't be blank"]
}
```

バリデーションエラーのハッシュを返す（`schedule.errors`）。

---

### PATCH /api/v1/schedules/:id

既存の日程表を更新する。

#### リクエスト

```
PATCH /api/v1/schedules/:id
Content-Type: application/json
```

```json
{
  "schedule": {
    "name": "2026年前期日程（改訂版）",
    "effective_date": "2026-04-15"
  }
}
```

#### 許可パラメータ

`POST` と同一。

#### 成功レスポンス（200 OK）

更新後のシリアライズされた日程表オブジェクトを返す。

#### 失敗レスポンス（422 Unprocessable Entity）

バリデーションエラーのハッシュを返す。

#### 処理フロー

1. `before_action :set_schedule` で `Schedule.find(params[:id])` によるレコード取得
2. `@schedule.update(schedule_params)` で更新

---

### DELETE /api/v1/schedules/:id

日程表を削除する。関連する `schedule_details` も `dependent: :destroy` により連鎖削除される。

#### リクエスト

```
DELETE /api/v1/schedules/:id
```

#### 成功レスポンス（204 No Content）

レスポンスボディなし（`head :no_content`）。

#### 処理フロー

1. `before_action :set_schedule` で `Schedule.find(params[:id])` によるレコード取得
2. `@schedule.destroy` でレコード削除（関連する `schedule_details` も連鎖削除）

---

### GET /api/v1/schedules/:schedule_id/schedule_details

指定した日程表の日程詳細を日付順で取得する。

#### リクエスト

```
GET /api/v1/schedules/:schedule_id/schedule_details
```

#### 成功レスポンス（200 OK）

```json
[
  {
    "schedule_id": 1,
    "date": "2026-04-01",
    "date_type": "game_day",
    "priority": null
  },
  {
    "schedule_id": 1,
    "date": "2026-04-02",
    "date_type": "travel_day",
    "priority": null
  }
]
```

#### 処理フロー

1. `before_action :set_schedule` で `Schedule.find(params[:schedule_id])` によるレコード取得
2. `@schedule.schedule_details.order(:date)` で日付昇順に取得

---

### POST /api/v1/schedules/:schedule_id/schedule_details/upsert_all

日程詳細を一括で作成・更新する（upsert）。`schedule_id` と `date` の複合ユニーク制約を基準に、既存データがあれば更新、なければ挿入する。

#### リクエスト

```
POST /api/v1/schedules/:schedule_id/schedule_details/upsert_all
Content-Type: application/json
```

```json
{
  "schedule_details": [
    { "date": "2026-04-01", "date_type": "game_day", "schedule_id": 1 },
    { "date": "2026-04-02", "date_type": "travel_day", "schedule_id": 1 },
    { "date": "2026-04-03", "date_type": "game_day", "schedule_id": 1 }
  ]
}
```

#### 許可パラメータ

各要素に対して:

```ruby
p.permit(:id, :date, :date_type, :schedule_id, :priority)
```

#### 処理フロー

```ruby
schedule_details_params = params.require(:schedule_details).map do |p|
  p.permit(:id, :date, :date_type, :schedule_id, :priority)
end

ScheduleDetail.upsert_all(schedule_details_params, unique_by: [:schedule_id, :date])
```

- `upsert_all` は Rails の `ActiveRecord::Persistence` メソッド
- `unique_by: [:schedule_id, :date]` で複合ユニークインデックスを衝突判定基準に使用
- モデルのバリデーション（`validates`）はスキップされる（`upsert_all` はバリデーション・コールバックを実行しない）

#### 成功レスポンス（200 OK）

レスポンスボディなし（`head :ok`）。

#### ルーティング定義

```ruby
resources :schedules, only: [:index, :create, :update, :destroy] do
  resources :schedule_details, only: [:index] do
    collection do
      post :upsert_all
    end
  end
end
```

## データモデル

### schedulesテーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | 日程表ID |
| name | string | - | 日程表名 |
| start_date | date | - | 期間開始日 |
| end_date | date | - | 期間終了日 |
| effective_date | date | - | シーズンへの適用日 |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

### schedule_detailsテーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | 日程詳細ID |
| schedule_id | bigint | NOT NULL, FK(schedules) | 所属する日程表のID |
| date | date | - | 日付 |
| date_type | string | - | 日程タイプ（`game_day`, `travel_day` 等） |
| priority | integer | - | 優先度 |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

#### インデックス

| インデックス名 | カラム | ユニーク | 説明 |
|--------------|--------|---------|------|
| `index_schedule_details_on_schedule_id` | `schedule_id` | No | FK検索用 |
| `index_schedule_details_on_schedule_id_and_date` | `schedule_id, date` | **Yes** | 同一日程表内で日付の重複を防止。`upsert_all` の `unique_by` 指定先 |

#### 外部キー

```
schedule_details.schedule_id → schedules.id
```

### モデル定義

#### Schedule

```ruby
class Schedule < ApplicationRecord
  has_many :schedule_details, dependent: :destroy
end
```

- `has_many :schedule_details`: 1つの日程表に複数の日程詳細が紐づく
- `dependent: :destroy`: 日程表削除時に全日程詳細を連鎖削除
- モデルレベルのバリデーションは定義されていない。フロントエンド側で `name`、`start_date`、`end_date` を必須としてバリデーション

#### ScheduleDetail

```ruby
class ScheduleDetail < ApplicationRecord
  belongs_to :schedule

  validates :date, presence: true
  validates :date_type, presence: true
end
```

- `belongs_to :schedule`: 必ず1つの日程表に所属（NOT NULL外部キー）
- バリデーション:
  - `date`: 必須
  - `date_type`: 必須
- **注意**: `upsert_all` 使用時にはこれらのバリデーションは実行されない。データ整合性はDBレベルの制約とフロントエンドの入力制御に依存する

### リレーション図

```
schedules (1) ──── (N) schedule_details
    │                      │
    │ id ◄─────────── schedule_id (FK)
    │                      │
    │                      ├── date (UNIQUE with schedule_id)
    │                      ├── date_type
    │                      └── priority
    │
    ├── name
    ├── start_date
    ├── end_date
    └── effective_date
```

### シリアライザー

#### ScheduleSerializer

```ruby
class ScheduleSerializer < ActiveModel::Serializer
  attributes :id, :name, :start_date, :end_date, :effective_date
end
```

- `timestamps`（`created_at`, `updated_at`）はAPIレスポンスに含まれない
- 日程詳細（`schedule_details`）は含まれない（別エンドポイントで取得）

#### ScheduleDetail

`ScheduleDetail` には専用のシリアライザーがなく、`render json: schedule_details` による直接シリアライズ。全カラムが出力される。

## ビジネスロジック

### 日程表の役割

日程表は「シーズンのテンプレート」として機能する。シーズン初期化（`SeasonInitializationDialog`）時に日程表を選択すると、その日程詳細がシーズンスケジュール（`season_schedules`）にコピーされる。これにより、毎シーズン同じ日程パターンを再利用できる。

### 日程タイプ

日程タイプはフロントエンドの `ScheduleDetailEditor` コンポーネント内で文字列定数として定義されている。バックエンドにenum定義はなく、`date_type` カラムは自由文字列。

#### マスタ設定時に使用されるタイプ

| タイプ | 日本語 | 用途 |
|--------|--------|------|
| `game_day` | 試合日 | 通常の試合が行われる日 |
| `interleague_game_day` | 交流戦試合日 | 交流戦の試合が行われる日 |
| `playoff_day` | プレーオフ日 | プレーオフの試合が行われる日 |
| `travel_day` | 移動日 | チーム移動日（試合なし） |
| `reserve_day` | 予備日 | 通常の予備日（雨天順延等に使用） |
| `interleague_reserve_day` | 交流戦予備日 | 交流戦の予備日 |
| `no_game_day` | 試合不可日 | 試合を行わない日 |

#### シーズン運用時に追加されるタイプ

翻訳ファイル（`ja.json`）に定義されているが、日程詳細エディターの選択肢には含まれない:

| タイプ | 日本語 | 用途 |
|--------|--------|------|
| `postponed` | 雨天中止 | 雨天等による試合中止 |
| `no_game` | 雨天ノーゲーム | 試合開始後のノーゲーム |

### 日程詳細の一括更新（upsert）

日程詳細の保存は個別のCRUDではなく、`upsert_all` による一括処理を採用している。

- **理由**: カレンダーUIで複数日付の日程タイプを編集した後、まとめて保存する方がUX上自然
- **衝突処理**: `unique_by: [:schedule_id, :date]` により、同一日程表・同一日付のレコードが既に存在する場合は `date_type` と `priority` を更新し、存在しない場合は新規挿入
- **注意**: `upsert_all` は ActiveRecord のバリデーション（`validates :date, presence: true` 等）およびコールバックをスキップする。データの整合性はDBレベルの制約とフロントエンドの入力制御に依存する
- 個別の日程詳細に対するCRUD APIは提供されていない。1回のAPIコールで全日程詳細を一括送信・保存する設計

### カスケード削除

日程表削除時、`dependent: :destroy` により関連する全日程詳細が自動削除される。`destroy` を使用しているため、日程詳細1件ごとに個別のDELETE SQLが発行される。

### priority カラム

`schedule_details` テーブルに `priority`（integer）カラムが存在し、`upsert_all` の許可パラメータにも含まれるが、現在のフロントエンド実装では使用されていない（型定義にも含まれない）。

## フロントエンド実装詳細

### コンポーネント構成

```
Settings.vue
└─ チーム運営タブ (v-tabs-window-item value="squad")
   └─ ScheduleSettings.vue       ... 日程表一覧
      ├─ ScheduleDialog.vue       ... 日程表の追加/編集ダイアログ
      └─ ScheduleDetailEditor.vue ... 日程詳細のカレンダー編集
```

### 型定義

#### ScheduleList（`src/types/scheduleList.ts`）

```typescript
export interface ScheduleList {
  id: number | null | undefined;
  name: string;
  start_date: Date | null;
  end_date: Date | null;
  effective_date: Date | null;
}
```

- `id`: 新規作成時は `null | undefined`、既存レコードは `number`
- 日付フィールドは `Date | null` 型だが、APIレスポンスでは文字列（`"2026-04-01"`）として返る

#### ScheduleDetail（`src/types/scheduleDetail.ts`）

```typescript
export interface ScheduleDetail {
  schedule_id: number;
  date: string;
  date_type: string;
}
```

- `date`: ISO形式の日付文字列（`"YYYY-MM-DD"`）
- `date_type`: 日程タイプ文字列（`"game_day"` 等）
- `priority` はバックエンドに存在するが、フロントエンドの型定義には含まれていない

### ScheduleSettings コンポーネント

**ファイル**: `src/components/settings/ScheduleSettings.vue`

#### リアクティブデータ

| 変数 | 型 | 説明 |
|-----|-----|------|
| `schedules` | `ref<ScheduleList[]>` | 日程表一覧 |
| `isDialogOpen` | `ref<boolean>` | ScheduleDialog の表示状態 |
| `isDetailEditorOpen` | `ref<boolean>` | ScheduleDetailEditor の表示状態 |
| `selectedSchedule` | `ref<ScheduleList \| null>` | 選択中の日程表 |

#### メソッド

| メソッド | 説明 |
|---------|------|
| `fetchSchedules()` | `GET /schedules` で一覧取得 |
| `openDialog(schedule)` | `null` で新規作成、オブジェクトで編集ダイアログを開く。オブジェクトはスプレッド演算子でコピー |
| `openScheduleDetailDialog(schedule)` | 日程詳細エディターを開く。オブジェクトはスプレッド演算子でコピー |
| `deleteItem(schedule)` | `confirm()` による確認後 `DELETE /schedules/:id` で削除、成功後に一覧を再取得 |

### ScheduleDialog コンポーネント

**ファイル**: `src/components/settings/ScheduleDialog.vue`

#### Props / Events

| 名前 | 型 | 方向 | 説明 |
|-----|-----|------|------|
| `modelValue` | `boolean` | defineModel | ダイアログの開閉状態（`v-model` で双方向バインド） |
| `schedule` | `ScheduleList \| null` | prop | 編集対象（`null` なら新規作成） |
| `save` | `void` | emit | 保存完了を通知 |

#### 内部型

```typescript
type ScheduleListPayload = Omit<ScheduleList, 'id'>
```

`id` を除いた日程表データ型。デフォルト値の定義と編集時のデータ保持に使用。

### ScheduleDetailEditor コンポーネント

**ファイル**: `src/components/settings/ScheduleDetailEditor.vue`

#### Props / Events

| 名前 | 型 | 方向 | 説明 |
|-----|-----|------|------|
| `modelValue` | `boolean` | defineModel | ダイアログの開閉状態 |
| `schedule` | `ScheduleList \| null` | prop | 対象の日程表 |
| `save` | `void` | emit | 保存完了を通知 |

#### リアクティブデータ

| 変数 | 型 | 初期値 | 説明 |
|-----|-----|-------|------|
| `scheduleDetails` | `ref<ScheduleDetail[]>` | `[]` | 日程詳細の配列 |
| `selectedDateType` | `ref<string>` | `'game_day'` | 選択中の日程タイプ |
| `calendarDate` | `ref<Date>` | `new Date()` | カレンダーで選択中の日付 |

#### watch による連動動作

1. **`props.schedule` の変更時**（`immediate: true`）: カレンダーの初期表示を `start_date` に設定し、`fetchScheduleDetails()` で日程詳細をAPIから取得
2. **`isOpen` が `true` に変化時**: `fetchScheduleDetails()` で日程詳細をAPIから再取得
3. **`selectedDateType` の変更時**: 現在選択中の日付（`calendarDate`）に対して:
   - 既存の詳細データが `scheduleDetails` にあれば `date_type` を上書き
   - なければ新しい `ScheduleDetail` を `{ date, date_type, schedule_id }` として配列に追加

### 国際化（i18n）

日程管理関連のラベルは `src/locales/ja.json` の `settings.schedule` 配下で定義:

| キーパス | 日本語値 |
|---------|---------|
| `settings.schedule.title` | 日程表 |
| `settings.schedule.add` | 日程表を追加 |
| `settings.schedule.confirmDelete` | この日程表を削除してもよろしいですか？ |
| `settings.schedule.headers.name` | 名前 |
| `settings.schedule.headers.start_date` | 開始日 |
| `settings.schedule.headers.end_date` | 終了日 |
| `settings.schedule.headers.effective_date` | 適用日 |
| `settings.schedule.headers.actions` | 操作 |
| `settings.schedule.dialog.title.add` | 日程表の追加 |
| `settings.schedule.dialog.title.edit` | 日程表の編集 |
| `settings.schedule.dialog.form.name` | 名前 |
| `settings.schedule.dialog.form.start_date` | 開始日 |
| `settings.schedule.dialog.form.end_date` | 終了日 |
| `settings.schedule.dialog.form.effective_date` | 適用日 |
| `settings.schedule.detail.title` | 日程詳細の設定 |
| `settings.schedule.detail.datePickerTitle` | 日付を選択 |
| `settings.schedule.detail.selectDate` | 日付を選択してください |
| `settings.schedule.dateTypes.*` | 各日程タイプの日本語ラベル |
| `settings.schedule.notifications.*` | 成功/失敗通知メッセージ |
