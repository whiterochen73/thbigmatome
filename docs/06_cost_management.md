# コスト管理

## 概要

コスト管理は、選手の獲得・維持にかかるコスト基準の定義と、各選手へのコスト値割当を行う機能である。以下の2つのサブ機能から構成される。

1. **コスト表管理** — コスト基準（期間・名称）の作成・編集・複製・削除を行う（Settings画面内の `CostSettings` コンポーネント）
2. **コスト割当管理** — コスト表に対して各選手のコスト値を設定する（`CostAssignment` 専用画面）

コスト表は期間（開始日・終了日）で管理され、`end_date` が `null` のコスト表が現在有効なコスト基準として扱われる（`Cost.current_cost` メソッド）。選手には役割（投手・野手・二刀流など）に応じて最大5種類のコスト値を設定でき、チーム所属時に `team_memberships.selected_cost_type` でどのコスト種別を適用するかを選択する。

コスト値はチーム編成の制約条件として使用され、一軍ロースターの合計コストには人数に応じた上限が設けられている。

---

## 画面構成（フロントエンド）

### コスト表管理（Settings > CostSettings）

- **パス**: `/settings`（Settings画面内のタブまたはセクション）
- **コンポーネント**: `src/components/settings/CostSettings.vue`
- **親コンポーネント**: `src/views/Settings.vue` から `<CostSettings />` として組み込み

#### 画面要素

| 要素 | 説明 |
|------|------|
| コスト表一覧テーブル（`v-data-table`） | `name`、`start_date`、`end_date`、操作ボタンを表示 |
| 新規追加ボタン | `CostDialog` を新規作成モード（`cost: null`）で開く |
| 編集アイコン（`mdi-pencil`） | `CostDialog` を編集モード（`cost: {...item}`）で開く |
| 複製アイコン（`mdi-content-copy`） | `confirm()` ダイアログ後、`POST /costs/:id/duplicate` を呼び出す |
| 削除アイコン（`mdi-delete`） | `confirm()` ダイアログ後、`DELETE /costs/:id` を呼び出す |

テーブルヘッダー: `name`, `start_date`, `end_date`, `actions`（i18nキー: `settings.cost.headers.*`）

#### 状態管理

| 変数 | 型 | 初期値 | 説明 |
|-----|-----|-------|------|
| `costs` | `ref<CostList[]>` | `[]` | コスト表一覧 |
| `dialogOpen` | `ref<boolean>` | `false` | ダイアログ開閉状態 |
| `selectedCost` | `ref<CostList \| null>` | `null` | 編集対象（`null` なら新規作成） |

#### ライフサイクル

- `onMounted` で `fetchCosts()` を呼び出し、`GET /api/v1/costs` でコスト表一覧を取得

#### saveCost 処理フロー

1. `selectedCost` が存在する場合（編集）: `axios.patch('/costs/${id}', costData)`
2. `selectedCost` が `null` の場合（新規）: `axios.post('/costs', costData)`
3. 保存後、`fetchCosts()` で一覧を再取得し、ダイアログを閉じる

**備考**: フロントエンドは `costData`（`{ name, start_date, end_date }`）をルートレベルで送信するが、コントローラーは `params.require(:cost)` でパラメータを取得する。Railsの `ParamsWrapper` ミドルウェアがコントローラー名（`CostsController`）に基づいて自動的に `cost` キーでラップするため、正常に動作する。

#### duplicateCost 処理フロー

1. `confirm()` で「{コスト表名} を複製しますか？」を表示
2. 確認後、`axios.post('/costs/${id}/duplicate')` を呼び出す
3. 成功時、`fetchCosts()` で一覧を再取得
4. 失敗時、`console.error` でログ出力（ユーザー向けエラー表示なし）

#### deleteItem 処理フロー

1. `confirm()` で `t('settings.cost.confirmDelete')` を表示
2. 確認後、`axios.delete('/costs/${id}')` を呼び出す
3. 成功時、`fetchCosts()` で一覧を再取得

---

### CostDialog（モーダルダイアログ）

- **コンポーネント**: `src/components/settings/CostDialog.vue`
- **最大幅**: 500px（`max-width="500px"`）

#### Props

| Prop | 型 | 説明 |
|------|-----|------|
| `modelValue` | `boolean` | ダイアログの開閉状態（v-model） |
| `cost` | `{ name: string; start_date: string \| null; end_date: string \| null } \| null` | 編集対象（`null` なら新規作成モード） |

#### Emits

| Event | Payload | 説明 |
|-------|---------|------|
| `update:modelValue` | `boolean` | ダイアログ開閉の制御 |
| `save` | `{ name, start_date, end_date }` | 保存時に親コンポーネントへ送信 |

#### フォームフィールド

| フィールド | v-model | type | 必須 | i18nキー | 説明 |
|-----------|---------|------|------|---------|------|
| コスト表名 | `editedCost.name` | `text` | はい | `settings.cost.dialog.form.name` | コスト表の名称 |
| 開始日 | `editedCost.start_date` | `date` | はい | `settings.cost.dialog.form.start_date` | 適用開始日 |
| 終了日 | `editedCost.end_date` | `date` | いいえ | `settings.cost.dialog.form.end_date` | 適用終了日 |

#### バリデーション

- `name` と `start_date` の両方が入力されている場合のみ保存ボタンが有効（`isFormValid` computed）
- 個別フィールドバリデーション: `rules.required` — 空値の場合 `t('validation.required')` を返す

#### ダイアログ開閉制御

- `dialog` は `computed` の get/set パターンで `modelValue` と双方向バインディング
- `props.cost` の変更を `watch` で監視し、`editedCost` を更新（ダイアログが開くたびに値がリセットされる）
- タイトル: 新規作成時 `settings.cost.dialog.title.add`、編集時 `settings.cost.dialog.title.edit`

---

### コスト割当画面（CostAssignment.vue）

- **パス**: `/cost_assignment`
- **コンポーネント**: `src/views/CostAssignment.vue`
- **ルート設定**: `meta: { requiresAuth: true }`（DefaultLayout配下）

#### 画面レイアウト

```
+-------------------------------------------+
| コスト登録                                |
|                                           |
| [CostListSelect ドロップダウン ▼]         |
|                                           |
| +-------+--------+------+-----+-----+... |
| | 背番号 | 選手名 | タイプ| コスト|中継ぎ|... |
| +-------+--------+------+-----+-----+... |
| |  1    | 選手A  | 投手 | [500]|     |... |
| |  2    | 選手B  | 野手 | [400]|     |... |
| +-------+--------+------+-----+-----+... |
|                                           |
|                          [ 保存 ]         |
+-------------------------------------------+
```

#### 画面要素

| 要素 | 説明 |
|------|------|
| `CostListSelect` | コスト表のドロップダウン選択（共通コンポーネント） |
| 選手一覧テーブル（`v-data-table`） | 背番号、選手名、選手タイプ、5種類のコスト入力欄を表示 |
| 保存ボタン | 全選手のコスト割当を一括保存。`loading` 中は `disabled` |

テーブル設定: `items-per-page="-1"`（全件表示）、`density="compact"`

#### テーブルヘッダー

| ヘッダー | key | i18nキー | sortable |
|---------|-----|---------|----------|
| 背番号 | `number` | `costAssignment.headers.number` | true |
| 選手名 | `name` | `costAssignment.headers.name` | true |
| 選手タイプ | `player_types` | `costAssignment.headers.player_types` | true |
| コスト | `cost` | `costAssignment.headers.cost` | false |
| 中継ぎ契約コスト | `relief_only_cost` | `costAssignment.headers.relief_only_cost` | false |
| 投手専念コスト | `pitcher_only_cost` | `costAssignment.headers.pitcher_only_cost` | false |
| 野手専念コスト | `fielder_only_cost` | `costAssignment.headers.fielder_only_cost` | false |
| 二刀流コスト | `two_way_cost` | `costAssignment.headers.two_way_cost` | false |

#### コスト入力欄の有効/無効制御

各コスト入力欄は選手の `player_types` に基づいて有効/無効が制御される。

```typescript
const costDefinitions = [
  { key: 'cost', model: 'normal_cost', requiredPlayerTypeId: null },
  { key: 'relief_only_cost', model: 'relief_only_cost', requiredPlayerTypeId: 9 },
  { key: 'pitcher_only_cost', model: 'pitcher_only_cost', requiredPlayerTypeId: 8 },
  { key: 'fielder_only_cost', model: 'fielder_only_cost', requiredPlayerTypeId: 8 },
  { key: 'two_way_cost', model: 'two_way_cost', requiredPlayerTypeId: 2 },
];
```

| コスト種別 | フィールド名 | 必要な player_type_id | 説明 |
|------------|--------------|----------------------|------|
| 通常コスト | `normal_cost` | `null`（全選手対象） | 基本コスト |
| リリーフ専コスト | `relief_only_cost` | 9 | リリーフ専門の場合のコスト |
| 投手専コスト | `pitcher_only_cost` | 8 | 投手専門の場合のコスト |
| 野手専コスト | `fielder_only_cost` | 8 | 野手専門の場合のコスト |
| 二刀流コスト | `two_way_cost` | 2 | 二刀流の場合のコスト |

`requiredPlayerTypeId` が `null` でない場合、選手の `player_types` 配列に該当IDが含まれていなければ入力欄は `disabled` となる。`normal_cost` は `requiredPlayerTypeId` が `null` であるため、全選手で入力可能。

**注意**: この制御はフロントエンド側のみであり、バックエンドでは選手タイプによるバリデーションは行われない。

#### 入力バリデーション（フロントエンド）

```typescript
const rules = {
  positiveInteger: (value: number | null) => {
    if (value === null || value === undefined) return true;
    if (!Number.isInteger(value)) return '整数を入力してください';
    if (value < 0) return '0以上の整数を入力してください';
    return true;
  },
};
```

- 未入力（`null` / `undefined`）は許容
- 入力がある場合は整数であること
- 入力がある場合は0以上であること
- 入力欄の幅: `80px`、`v-text-field` で `type="number"` `min="0"`

#### 状態管理

| 変数 | 型 | 初期値 | 説明 |
|-----|-----|-------|------|
| `players` | `ref<CostPlayer[]>` | `[]` | 選手一覧（コスト値付き） |
| `selectedCost` | `ref<CostList \| null>` | `null` | 選択中のコスト表 |
| `loading` | `ref<boolean>` | `false` | ローディング状態 |

#### コスト選択変更時の挙動

- `watch(selectedCost, ...)` でコスト表の変更を監視（`{ immediate: true }`）
- 有効なコスト表が選択された場合: `fetchPlayers()` を実行
- 選択が解除された場合: `players` を空配列にリセット

#### fetchPlayers 処理フロー

1. `GET /api/v1/cost_assignments?cost_id=${selectedCost.id}` でデータ取得
2. レスポンスの各選手データについて、コスト値が falsy の場合は `null` に正規化
3. エラー時: `useSnackbar` で「選手情報の取得に失敗しました。」を表示

#### saveAssignments 処理フロー

1. `selectedCost` が未選択の場合、警告スナックバーを表示して終了
2. `players` を `{ player_id, normal_cost, relief_only_cost, pitcher_only_cost, fielder_only_cost, two_way_cost }` の配列に変換
3. `POST /api/v1/cost_assignments` に `{ assignments: { cost_id, players: [...] } }` を送信
4. 成功時: 「コスト一覧を保存しました」を表示
5. 失敗時: 「コスト一覧の保存に失敗しました」を表示

---

### CostListSelect（共通コンポーネント）

- **コンポーネント**: `src/components/shared/CostListSelect.vue`
- **用途**: コスト表選択用の共通ドロップダウン。複数の画面で再利用される

#### 使用箇所

| 画面 | 目的 |
|------|------|
| `CostAssignment.vue` | コスト割当対象のコスト表を選択 |
| `TeamMembers.vue` | チーム所属選手のコスト参照に使用するコスト表を選択 |

#### 機能

- `GET /api/v1/costs` でコスト表一覧を取得
- `v-select` で表示（`item-title="name"`, `return-object` で選択時にオブジェクト全体を返却）
- v-model: `defineModel<CostList | null>()` により親コンポーネントと双方向バインディング

#### 初期値の自動選択ロジック

`onMounted` で以下の処理を実行:

1. `fetchCostLists()` でコスト表一覧を取得
2. 外部から初期値が設定されていない場合（`!costList.value`）のみ実行:
   - 現在日時が `start_date` 以降かつ `end_date` 以前（または `end_date` が未設定）のコスト表を検索
   - 該当するコスト表があればそれを選択
   - 該当しない場合は一覧の先頭を選択

---

## APIエンドポイント

### 共通事項

- **ベースURL**: `/api/v1`
- **コントローラー継承**: `Api::V1::CostsController < ApplicationController`、`Api::V1::CostAssignmentsController < ApplicationController`
- **認証**: `ApplicationController` 経由の認証が適用される

### コスト表 CRUD

#### GET /api/v1/costs

全コスト表の一覧を取得する。

- **コントローラー**: `Api::V1::CostsController#index`
- **シリアライザー**: `CostSerializer`（`id`, `name`, `start_date`, `end_date`）
- **レスポンス (200 OK)**:

```json
[
  {
    "id": 1,
    "name": "2025年度前期コスト",
    "start_date": "2025-04-01",
    "end_date": "2025-09-30"
  },
  {
    "id": 2,
    "name": "2025年度後期コスト",
    "start_date": "2025-10-01",
    "end_date": null
  }
]
```

---

#### POST /api/v1/costs

新規コスト表を作成する。

- **コントローラー**: `Api::V1::CostsController#create`
- **許可パラメータ**: `params.require(:cost).permit(:name, :start_date, :end_date)`
- **リクエストボディ**:

```json
{
  "cost": {
    "name": "2026年度コスト",
    "start_date": "2026-04-01",
    "end_date": null
  }
}
```

- **成功レスポンス (201 Created)**: 作成されたコスト表のJSON（デフォルトのRails JSON出力）
- **失敗レスポンス (422 Unprocessable Entity)**: バリデーションエラーのJSON

---

#### PATCH /api/v1/costs/:id

指定コスト表を更新する。

- **コントローラー**: `Api::V1::CostsController#update`
- **before_action**: `set_cost` で `Cost.find(params[:id])` を取得
- **リクエストボディ**: `POST` と同様（更新したいフィールドのみ）
- **成功レスポンス (200 OK)**: 更新されたコスト表のJSON
- **失敗レスポンス (422 Unprocessable Entity)**: バリデーションエラーのJSON

---

#### DELETE /api/v1/costs/:id

指定コスト表を削除する。紐づく `cost_players` も `dependent: :destroy` により連鎖削除される。

- **コントローラー**: `Api::V1::CostsController#destroy`
- **before_action**: `set_cost`
- **成功レスポンス (204 No Content)**: レスポンスボディなし

---

#### POST /api/v1/costs/:id/duplicate

指定コスト表と紐づく全 `cost_players` を複製する。

- **コントローラー**: `Api::V1::CostsController#duplicate`
- **ルーティング**: `post :duplicate, on: :member`（`/api/v1/costs/:id/duplicate`）
- **before_action**: `set_cost`
- **トランザクション**: `ActiveRecord::Base.transaction` で一括処理
- **複製ロジック**:
  1. 元のコスト表を `dup` で複製（IDは採番されない）
  2. 名前の末尾に `" (コピー)"` を付与（例: `"2025年度コスト"` → `"2025年度コスト (コピー)"`）
  3. `start_date` が存在する場合、1年後（`next_year`）に設定
  4. `end_date` が存在する場合、1年後（`next_year`）に設定
  5. 複製コスト表を `save!` で保存
  6. 元コスト表の全 `cost_players` を `dup` で複製し、新コスト表に紐付けて `save!`
- **成功レスポンス (201 Created)**: 複製されたコスト表のJSON
- **失敗レスポンス (422 Unprocessable Entity)**: `ActiveRecord::RecordInvalid` をキャッチし、バリデーションエラーメッセージを返却。トランザクション全体がロールバックされる

---

### コスト割当

#### GET /api/v1/cost_assignments

指定コスト表に対する全選手のコスト割当情報を取得する。

- **コントローラー**: `Api::V1::CostAssignmentsController#index`
- **ルーティング**: `resources :cost_assignments, only: [:index, :create]`
- **クエリパラメータ**: `cost_id`（必須） — 対象コスト表のID
- **処理内容**:
  1. `Player.order(:id).includes(:player_types).preload(:cost_players)` で全選手を取得
  2. 各選手を `as_json(include: { player_types: { only: [:id, :name] } }, except: [:created_at, :updated_at])` でシリアライズ
  3. 指定 `cost_id` に対応する `cost_player` レコードから5種類のコスト値を付加
  4. 対応する `cost_player` レコードが存在しない場合、各コスト値は `nil`
- **レスポンス (200 OK)**:

```json
[
  {
    "id": 1,
    "number": "1",
    "name": "選手A",
    "position": "pitcher",
    "throwing_hand": "右",
    "batting_hand": "右",
    "player_types": [
      { "id": 8, "name": "投手" }
    ],
    "normal_cost": 500,
    "relief_only_cost": null,
    "pitcher_only_cost": 450,
    "fielder_only_cost": null,
    "two_way_cost": null
  }
]
```

**備考**: このエンドポイントは `CostPlayerSerializer` を使用せず、`Player` の `as_json` に手動でコスト値を付加するカスタムレスポンスを構築している。選手情報（背番号、名前、選手タイプ等）とコスト値を1つのレスポンスにまとめるためである。レスポンスには `players` テーブルの各カラム（`created_at`, `updated_at` を除く）が含まれる。

---

#### POST /api/v1/cost_assignments

コスト割当を一括保存する。`find_or_initialize_by` により、既存レコードは更新、新規は作成される（upsert相当）。

- **コントローラー**: `Api::V1::CostAssignmentsController#create`
- **許可パラメータ**: `params.require(:assignments).permit(:cost_id, players: [:player_id, :normal_cost, :relief_only_cost, :pitcher_only_cost, :fielder_only_cost, :two_way_cost])`
- **リクエストボディ**:

```json
{
  "assignments": {
    "cost_id": 1,
    "players": [
      {
        "player_id": 1,
        "normal_cost": 500,
        "relief_only_cost": null,
        "pitcher_only_cost": 450,
        "fielder_only_cost": null,
        "two_way_cost": null
      },
      {
        "player_id": 2,
        "normal_cost": 400,
        "relief_only_cost": null,
        "pitcher_only_cost": null,
        "fielder_only_cost": 380,
        "two_way_cost": null
      }
    ]
  }
}
```

- **処理内容**:
  1. `Cost.find(cost_assignment_params[:cost_id])` で `Cost` レコードを取得
  2. `players` 配列を反復処理
  3. 各選手について `cost.cost_players.find_or_initialize_by(player_id:)` で既存の `cost_player` を検索、なければ新規作成
  4. 5種類のコスト値を設定（直接ハッシュアクセス: `cost_player[:normal_cost] = ...`）
  5. `save!` で保存
- **成功レスポンス**: デフォルト（暗黙の200、レスポンスボディなし）
- **注意**: トランザクション制御が明示的にないため、途中で `save!` が失敗した場合、それ以前の保存は確定済みとなり部分的な保存状態になる可能性がある

---

## データモデル

### costs テーブル

コスト基準の期間と名称を管理するマスタテーブル。

| カラム名 | 型 | NOT NULL | デフォルト | 説明 |
|----------|------|----------|-----------|------|
| id | bigint | はい | 自動採番 | 主キー |
| name | string | いいえ（※） | - | コスト表名 |
| start_date | date | いいえ（※） | - | 適用開始日 |
| end_date | date | いいえ | null | 適用終了日（nullの場合は現在有効） |
| created_at | datetime | はい | 自動 | 作成日時 |
| updated_at | datetime | はい | 自動 | 更新日時 |

※ DB定義上は NOT NULL 制約なし。モデルバリデーションで必須を担保。

#### モデル定義（`app/models/cost.rb`）

```ruby
class Cost < ApplicationRecord
  has_many :cost_players, dependent: :destroy
  has_many :players, through: :cost_players

  validates :name, presence: true
  validates :start_date, presence: true

  def self.current_cost
    Cost.where(end_date: nil).first
  end
end
```

- **アソシエーション**: `has_many :cost_players`（`dependent: :destroy` で連鎖削除）、`has_many :players, through: :cost_players`
- **バリデーション**: `name` 必須、`start_date` 必須
- **クラスメソッド**: `current_cost` — `end_date` が `null` のコスト表を1件返す

---

### cost_players テーブル

コスト表と選手の中間テーブル。各選手に対して5種類のコスト値を保持する。

| カラム名 | 型 | NOT NULL | デフォルト | 説明 |
|----------|------|----------|-----------|------|
| id | bigint | はい | 自動採番 | 主キー |
| cost_id | bigint | はい | - | costs テーブルへの外部キー |
| player_id | bigint | はい | - | players テーブルへの外部キー |
| normal_cost | integer | いいえ | null | 通常コスト |
| relief_only_cost | integer | いいえ | null | リリーフ専門コスト |
| pitcher_only_cost | integer | いいえ | null | 投手専門コスト |
| fielder_only_cost | integer | いいえ | null | 野手専門コスト |
| two_way_cost | integer | いいえ | null | 二刀流コスト |
| created_at | datetime | はい | 自動 | 作成日時 |
| updated_at | datetime | はい | 自動 | 更新日時 |

**インデックス**:
- `index_cost_players_on_cost_id_and_player_id` — (cost_id, player_id) 複合インデックス
- `index_cost_players_on_cost_id` — cost_id 単体インデックス
- `index_cost_players_on_player_id` — player_id 単体インデックス

**外部キー**: `cost_id` → `costs.id`、`player_id` → `players.id`

#### モデル定義（`app/models/cost_player.rb`）

```ruby
class CostPlayer < ApplicationRecord
  belongs_to :cost
  belongs_to :player

  validates :normal_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :relief_only_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :pitcher_only_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :fielder_only_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :two_way_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
end
```

- **アソシエーション**: `belongs_to :cost`、`belongs_to :player`
- **バリデーション**: 全コスト値は入力がある場合のみ検証、1以上の整数（`allow_blank: true`）

---

### team_memberships テーブル（コスト関連カラム）

チームと選手の所属関係を管理するテーブル。コスト管理に直接関連するカラムを以下に示す。

| カラム名 | 型 | NOT NULL | デフォルト | 説明 |
|----------|------|----------|-----------|------|
| selected_cost_type | string | はい | `"normal_cost"` | 適用するコスト種別名 |

**有効な値**: `normal_cost`, `relief_only_cost`, `pitcher_only_cost`, `fielder_only_cost`, `two_way_cost`

#### モデル定義抜粋（`app/models/team_membership.rb`）

```ruby
class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :player
  has_many :season_rosters
  has_many :player_absences, dependent: :restrict_with_error

  validates :squad, inclusion: { in: %w(first second) }
  validates :selected_cost_type, presence: true
end
```

- `selected_cost_type` は `presence: true` で必須。ただし、有効な値のリスト（`inclusion`）による制約はモデルレベルでは未定義。

---

### 5種類のコストタイプ

| コスト種別 | カラム名 | UI表示名（i18n） | 説明 |
|------------|----------|-----------------|------|
| 通常コスト | `normal_cost` | コスト | 全選手に適用される基本コスト |
| リリーフ専コスト | `relief_only_cost` | 中継ぎ契約コスト | リリーフ投手として起用する場合のコスト |
| 投手専コスト | `pitcher_only_cost` | 投手専念コスト | 投手専門として起用する場合のコスト |
| 野手専コスト | `fielder_only_cost` | 野手専念コスト | 野手専門として起用する場合のコスト |
| 二刀流コスト | `two_way_cost` | 二刀流コスト | 二刀流（投手兼野手）として起用する場合のコスト |

---

### リレーション図

```
costs (1) ──────< cost_players (N) >────── players (1)
                        │
                        │ 5種類のコスト値を保持
                        │
                        ▼
              team_memberships
              (selected_cost_type で
               どのコスト値を使うか選択)
```

---

## ビジネスロジック

### Cost.current_cost クラスメソッド

現在有効なコスト表を取得するクラスメソッド。

```ruby
def self.current_cost
  Cost.where(end_date: nil).first
end
```

`end_date` が `null` のコスト表を現在有効なコスト基準として返す。該当レコードが複数存在する場合は `first` により取得されるレコードはID昇順であることが多いが保証されない。運用上、`end_date` が `null` のコスト表は1件のみに制限すべきである。

このメソッドは以下の箇所で使用される:
- `RosterPlayerSerializer#cost` — ロースター表示時の個別選手コスト算出
- `TeamRostersController#show` — ロースター一覧の表示
- `TeamRostersController#create` — ロースター変更時の一軍コスト制約チェック

---

### コスト表複製ロジック

`duplicate` アクションによるコスト表の複製処理。トランザクション内で実行される。

**処理フロー**:

1. トランザクション開始（`ActiveRecord::Base.transaction`）
2. 元のコスト表を `dup` で複製（IDは新規採番）
3. 名前の末尾に `" (コピー)"` を付与
4. `start_date` が存在する場合、1年後（`next_year`）に変更
5. `end_date` が存在する場合、1年後（`next_year`）に変更
6. 複製コスト表を `save!` で保存
7. 元コスト表の全 `cost_players` を反復:
   - 各 `cost_player` を `dup` で複製
   - 複製したコスト表に紐付け（`new_cost_player.cost = duplicated_cost`）
   - `save!` で保存
8. トランザクション完了
9. 複製コスト表をレスポンスとして返却（201 Created）

**失敗時**:
- `ActiveRecord::RecordInvalid` 例外をキャッチ
- トランザクション全体が自動ロールバック
- 422エラーとして `e.record.errors.full_messages` を返却

---

### コスト割当保存ロジック

`CostAssignmentsController#create` による一括保存処理。

**処理フロー**:

1. `cost_id` から `Cost` レコードを検索（`Cost.find`）
2. リクエスト内の `players` 配列を反復処理
3. 各選手について `cost.cost_players.find_or_initialize_by(player_id:)` で既存の `cost_player` を検索、なければ新規初期化
4. 5種類のコスト値を直接代入（`cost_player[:normal_cost] = player_params[:normal_cost]` 等）
5. `save!` で保存

**特徴**:
- 既存レコードがある場合は更新、ない場合は新規作成（upsert動作）
- 全選手分を一括送信・保存する設計
- **トランザクション未使用**: 途中で失敗した場合、部分保存状態になるリスクがある

---

### コスト種別選択（team_memberships.selected_cost_type）

チーム所属選手がどのコスト種別で契約するかを `team_memberships` テーブルの `selected_cost_type` カラムで管理する。これはコスト管理機能の出力を消費する側の仕組みである。

#### 使用箇所

| 箇所 | ファイル | 用途 |
|------|---------|------|
| チーム所属登録 | `TeamPlayersController#create` | `selected_cost_type` を保存 |
| チーム選手表示 | `TeamPlayerSerializer` | `selected_cost_type` と対応するコスト値をシリアライズ |
| ロースター表示 | `TeamRostersController#show` | 各選手の `selected_cost_type` で指定されたコスト値を取得 |
| ロースター変更 | `TeamRostersController#create` | 一軍合計コスト制約のチェック |
| ロースターシリアライザー | `RosterPlayerSerializer` | `selected_cost_type` でコスト値を算出 |
| チーム所属画面 | `TeamMembers.vue` | コスト種別ドロップダウン選択UI |
| 出場登録画面 | `ActiveRoster.vue` | コスト種別の表示 |

#### TeamPlayerSerializer によるコスト出力

```ruby
class TeamPlayerSerializer < PlayerSerializer
  attributes :selected_cost_type, :current_cost

  def selected_cost_type
    object.team_memberships.find_by(team_id: @instance_options[:team].id).selected_cost_type
  end

  def current_cost
    cost_type = object.team_memberships.find_by(team_id: @instance_options[:team].id).selected_cost_type
    cost_player_record = object.cost_players.find_by(cost_id: @instance_options[:cost_list_id])
    cost_player_record&.send(cost_type)
  end
end
```

- `PlayerSerializer` を継承し、`selected_cost_type` と `current_cost` を追加出力
- `current_cost` は `cost_players` テーブルから、対象コスト表の `selected_cost_type` に対応する値を動的に取得（`send` メソッドを使用）

#### RosterPlayerSerializer によるコスト出力

```ruby
def cost
  @current_cost ||= Cost.current_cost
  object.player.cost_players.find{|cp| cp.cost_id == @current_cost.id }.send(object.selected_cost_type)
end
```

- `Cost.current_cost` で現在有効なコスト表を取得（インスタンス変数でキャッシュ）
- `team_membership` の `selected_cost_type` を使って動的にコスト値を取得

#### コスト計算の全体フロー

1. **コスト割当画面**で選手ごとに5種類のコスト値を設定（本機能）
2. **チーム所属時**に `selected_cost_type` で適用するコスト種別を選択（`TeamMembers.vue` → `TeamPlayersController#create`）
3. **ロースター表示時**に `Cost.current_cost` で現在有効なコスト表を取得し、`selected_cost_type` で指定された種別のコスト値を表示
4. **一軍ロースター変更時**に合計コスト制約をチェック

---

### 一軍ロースターのコスト制約

`TeamRostersController#create` の `validate_first_squad_constraints` メソッドで、一軍ロースターの人数・合計コスト制約をチェックする。

#### 基本制約

| 制約 | 値 |
|------|-----|
| 一軍最大人数 | 29人 |
| 一軍最大コスト（非試合日） | 120 |

#### 試合日の動的コスト上限

試合日（`date_type: 'game_day'`）には、一軍人数に応じてコスト上限が変動する。

| 一軍人数 | コスト上限 |
|----------|-----------|
| 25人 | 114 |
| 26人 | 117 |
| 27人 | 119 |
| 28〜29人 | 120 |

試合日には一軍に最低25人の登録が必要（シーズン初日の初期登録中を除く）。

#### 合計コスト計算ロジック

```ruby
total_cost = first_squad_memberships.sum { |tm|
  tm.player.cost_players.find { |pc| pc.cost_id == @current_cost_list.id }.send(tm.selected_cost_type)
}
```

各一軍選手について:
1. `Cost.current_cost` で取得した現在有効コスト表に対応する `cost_player` レコードを検索
2. `tm.selected_cost_type`（`normal_cost`, `relief_only_cost` 等）を `send` で動的呼び出しし、コスト値を取得
3. 全一軍選手のコスト値を合算

#### チーム所属画面（TeamMembers.vue）のコスト制約

`TeamMembers.vue` ではチーム編成時に以下の制約を表示・チェックする:

| 制約 | 値 | 定数名 |
|------|-----|--------|
| チーム最大人数 | 50人 | `MAX_PLAYERS` |
| チーム最大合計コスト | 200 | `TOTAL_TEAM_MAX_COST` |

超過時はスナックバーで警告を表示するが、保存自体はブロックしない（フロントエンドのみの警告）。

---

### コスト種別選択の決定ロジック（TeamMembers.vue）

`TeamMembers.vue` の `fetchTeamPlayers` では、各選手の `selected_cost_type` を以下の優先順位で決定する:

1. **バックエンドの `selected_cost_type`**: 有効なオプションに含まれ、かつそのコスト値が非nullの場合に採用
2. **`normal_cost`**: 上記が該当しない場合、`normal_cost` が非nullなら採用
3. **最初の利用可能オプション**: `normal_cost` も無い場合、`getAvailableCostTypes` の先頭を採用
4. **デフォルト**: いずれもない場合、`normal_cost` をデフォルトとして設定（値がnullでも）

#### getAvailableCostTypes 関数

選手のプレイヤータイプに基づいて、選択可能なコスト種別を返す。

```typescript
const getAvailableCostTypes = (player: Player) => {
  const options: { value: CostType, text: string }[] = [];
  const costPlayerForSelectedList = player.cost_players.find(cp => cp.cost_id === selectedCostListId.value);

  if (!costPlayerForSelectedList) return [];

  // normal_cost: 全選手に表示（値がnon-nullの場合のみ）
  // relief_only_cost: player_type_id 9 を持つ選手にのみ表示
  // pitcher_only_cost: player_type_id 8 を持つ選手にのみ表示
  // fielder_only_cost: player_type_id 8 を持つ選手にのみ表示
  // two_way_cost: player_type_id 2 を持つ選手にのみ表示
};
```

表示テキストはコスト値を括弧書きで付加: `"投手専念コスト (450)"`

#### チーム合計コスト計算

```typescript
const totalTeamCost = computed(() => {
  return teamPlayers.value.reduce((sum, p) => {
    const costPlayerForSelectedList = p.cost_players.find(cp => cp.cost_id === selectedCostListId.value);
    const costValue = costPlayerForSelectedList
      ? ((costPlayerForSelectedList as Record<CostType, number | null>)[p.selected_cost_type] ?? 0)
      : 0;
    return sum + costValue;
  }, 0);
});
```

選択中のコスト表に対して、各選手の `selected_cost_type` に対応するコスト値を合算する。

---

## フロントエンド実装詳細

### TypeScript型定義

#### Cost（`src/types/cost.ts`）

コスト情報を含む型。選手のコスト割当情報に使用される。

```typescript
export interface Cost {
  id: number;
  name: string;
  start_date: string;
  end_date: string;
  normal_cost: number | null;
  relief_only_cost: number | null;
  pitcher_only_cost: number | null;
  fielder_only_cost: number | null;
  two_way_cost: number | null;
}
```

---

#### CostList（`src/types/costList.ts`）

コスト表の一覧・選択に使用する型。

```typescript
export interface CostList {
  id: number;
  name: string;
  start_date: string | null;
  end_date: string | null;
  effective_date: string | null;
}
```

**備考**: `effective_date` フィールドは型定義に含まれるが、`CostSerializer` は `id`, `name`, `start_date`, `end_date` のみを出力するため、APIレスポンスにはこの値は含まれない。

---

#### CostPlayer（`src/types/costPlayer.ts`）

コスト割当画面のテーブル行データ型。選手情報とコスト値を結合した構造。

```typescript
export interface CostPlayer {
  id: number;
  number: string | null;
  name: string;
  player_types: { id: number; name: string }[];
  normal_cost: number | null;
  relief_only_cost: number | null;
  pitcher_only_cost: number | null;
  fielder_only_cost: number | null;
  two_way_cost: number | null;
  [key: string]: any;  // 動的プロパティアクセス用（costDefinitions のループ処理で使用）
}
```

---

#### PlayerCost（`src/types/playerCost.ts`）

`cost_players` テーブルのレコードに対応する型。

```typescript
export interface PlayerCost {
  id: number;
  cost_id: number;
  player_id: number;
  normal_cost: number | null;
  relief_only_cost: number | null;
  pitcher_only_cost: number | null;
  fielder_only_cost: number | null;
  two_way_cost: number | null;
}
```

---

### シリアライザー

#### CostSerializer（`app/serializers/cost_serializer.rb`）

コスト表のJSON出力に使用。

```ruby
class CostSerializer < ActiveModel::Serializer
  attributes :id, :name, :start_date, :end_date
end
```

---

#### CostPlayerSerializer（`app/serializers/cost_player_serializer.rb`）

コスト割当レコードのJSON出力に使用。

```ruby
class CostPlayerSerializer < ActiveModel::Serializer
  attributes :id, :cost_id, :player_id, :normal_cost, :relief_only_cost,
             :pitcher_only_cost, :fielder_only_cost, :two_way_cost
end
```

**備考**: `CostAssignmentsController#index` ではこのシリアライザーを使用せず、`Player` の `as_json` に手動でコスト値を付加するカスタムレスポンスを構築している。これは選手情報（背番号、名前、選手タイプ等）とコスト値を1つのレスポンスにまとめるためである。

---

#### TeamMembershipSerializer（`app/serializers/team_membership_serializer.rb`）

チーム所属情報のJSON出力。コスト関連として `selected_cost_type` を含む。

```ruby
class TeamMembershipSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :player_id, :squad, :selected_cost_type

  belongs_to :player
end
```

---

### ルーティング（`config/routes.rb` 抜粋）

```ruby
resources :costs, only: [:index, :show, :create, :update, :destroy] do
  post :duplicate, on: :member
end
resources :cost_assignments, only: [:index, :create]
```

| HTTPメソッド | パス | アクション |
|-------------|------|-----------|
| GET | `/api/v1/costs` | `costs#index` |
| GET | `/api/v1/costs/:id` | `costs#show` |
| POST | `/api/v1/costs` | `costs#create` |
| PATCH/PUT | `/api/v1/costs/:id` | `costs#update` |
| DELETE | `/api/v1/costs/:id` | `costs#destroy` |
| POST | `/api/v1/costs/:id/duplicate` | `costs#duplicate` |
| GET | `/api/v1/cost_assignments` | `cost_assignments#index` |
| POST | `/api/v1/cost_assignments` | `cost_assignments#create` |

**備考**: `costs` には `:show` ルートが定義されているが、`CostsController` に `show` アクションは実装されていない。リクエストすると `AbstractController::ActionNotFound` エラーとなる。

---

### i18nキー（コスト関連）

```json
{
  "costAssignment": {
    "title": "コスト登録",
    "costList": "コスト一覧",
    "save": "保存",
    "headers": {
      "number": "背番号",
      "name": "選手名",
      "player_types": "選手タイプ",
      "cost": "コスト",
      "relief_only_cost": "中継ぎ契約コスト",
      "pitcher_only_cost": "投手専念コスト",
      "fielder_only_cost": "野手専念コスト",
      "two_way_cost": "二刀流コスト"
    }
  }
}
```

---

## 既知の制約・注意事項

1. **バックエンドとフロントエンドのバリデーション差異**: バックエンドではコスト値の最小値は `1`（`greater_than_or_equal_to: 1`）だが、フロントエンドのバリデーションでは `0以上` を許容している。この差異により、フロントエンドで `0` を入力した場合、バックエンドでバリデーションエラーとなる可能性がある。

2. **トランザクション制御の非対称性**: `duplicate` アクションはトランザクションで保護されているが、`cost_assignments#create` の一括保存にはトランザクション制御がない。途中で `save!` が失敗した場合、それ以前の保存は確定済みとなり部分的な保存状態になる可能性がある。

3. **current_cost の制約**: `end_date` が `null` のレコードが複数存在した場合、`first` により取得されるレコードは不定。運用上、`end_date` が `null` のコスト表は1件のみに制限すべきである。

4. **CostList.effective_date の不整合**: フロントエンドの `CostList` 型に `effective_date` フィールドが定義されているが、バックエンドの `costs` テーブルにこのカラムは存在せず、`CostSerializer` も出力しない。常に `undefined` となる未使用フィールドである。

5. **costs#show の未実装**: ルーティングに `:show` が含まれるが、コントローラーに `show` アクションがないため、呼び出すとエラーになる。

6. **CostListSelect のエッジケース**: コスト表が0件の場合、`costLists.value[0]` は `undefined` となり、`costList.value` に `undefined` が設定される。

7. **selected_cost_type の整合性バリデーション不足**: `TeamMembership` モデルは `selected_cost_type` に `presence: true` のみを要求し、`inclusion` バリデーションがない。無効な値（例: `"invalid_type"`）が保存された場合、`send` メソッドで `NoMethodError` が発生するリスクがある。

8. **RosterPlayerSerializer の cost 計算エラーリスク**: `Cost.current_cost` が `nil` を返す場合（`end_date` が `null` のコスト表が存在しない場合）、`NoMethodError` が発生する。また、選手に `cost_player` レコードが存在しない場合も同様のエラーが発生する。
