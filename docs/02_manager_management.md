# 監督管理機能仕様書

最終更新: 2026-02-21

## 目次

1. [概要](#概要)
2. [システム構成](#システム構成)
3. [画面仕様（フロントエンド）](#画面仕様フロントエンド)
4. [APIエンドポイント仕様](#apiエンドポイント仕様)
5. [データモデル](#データモデル)
6. [ビジネスロジック](#ビジネスロジック)
7. [フロントエンド実装詳細](#フロントエンド実装詳細)
8. [ルーティング](#ルーティング)
9. [既知の制約・未実装機能](#既知の制約未実装機能)
10. [参考情報](#参考情報)

---

## 概要

### 機能概要

監督管理機能は、野球チームの監督（Manager）情報を管理し、チームとの関係を制御する機能群を提供する。本システムでは、監督とチームの関係を `team_managers` 中間テーブルで管理する：

- **Team Managers**: `team_managers` 中間テーブルにより、監督（director）またはコーチ（coach）として複数のスタッフをチームに割り当て可能

**注意**: 以前の設計では `teams.manager_id` 外部キーによる主監督設定が存在したが、現在の `teams` テーブルには `manager_id` カラムは存在しない。

### 主要機能

- 監督の作成・編集・削除（CRUD操作）
- 監督一覧表示（サーバーサイドページネーション対応）
- チームとの関係管理（`team_managers` を通じた role 付き割り当て）
- リーグ内兼任制約（同一リーグ内の複数チームへの兼任を禁止）

### 役割（Role）の種類

監督とチームの関係には、以下の2種類の役割が定義される（`team_managers.role` enum）：

| role 値 | 表示名 | 説明 |
|---------|--------|------|
| `director` (0) | 監督 | チームの監督。1チームにつき1人まで（team_managers の uniqueness validation による） |
| `coach` (1) | コーチ | チームのコーチ。複数人割り当て可能 |

**注意**: `managers.role` カラムも存在するが、現在のコントローラー・シリアライザーでは使用されていない。主に `team_managers.role` でチームごとの役割を管理している。

---

## システム構成

### 技術スタック

| レイヤー | 技術 | 備考 |
|---------|------|------|
| バックエンド | Ruby on Rails 8.0.2 (API モード) | `/home/morinaga/projects/thbigmatome/` |
| フロントエンド | Vue.js 3 + TypeScript + Composition API | `/home/morinaga/projects/thbigmatome-front/` |
| UI フレームワーク | Vuetify 3 | v-data-table, v-dialog 等を使用 |
| HTTP クライアント | axios | `/api/v1` をベースURLに設定 |
| 国際化 | vue-i18n | `t('managerList.title')` 形式 |
| データベース | PostgreSQL | `managers`, `team_managers`, `teams` テーブル |

### ファイル構成

#### バックエンド

```
thbigmatome/
├── app/
│   ├── controllers/api/v1/
│   │   └── managers_controller.rb    # 監督CRUD操作
│   ├── models/
│   │   ├── manager.rb                # 監督モデル
│   │   └── team_manager.rb           # 中間テーブルモデル（監督-チーム関連）
│   └── serializers/
│       └── manager_serializer.rb     # 監督JSONシリアライザー
├── config/
│   └── routes.rb                     # ルーティング定義（resources :managers）
└── db/
    └── schema.rb                     # DBスキーマ（managers, team_managers テーブル定義）
```

#### フロントエンド

```
thbigmatome-front/
├── src/
│   ├── views/
│   │   └── ManagerList.vue           # 監督一覧画面
│   ├── components/
│   │   ├── ManagerDialog.vue         # 監督編集/作成ダイアログ
│   │   ├── TeamDialog.vue            # チーム編集/作成ダイアログ（監督一覧から呼び出し可能）
│   │   └── ConfirmDialog.vue         # 削除確認ダイアログ
│   ├── types/
│   │   └── manager.ts                # Manager型定義
│   ├── composables/
│   │   └── useSnackbar.ts            # スナックバー通知用コンポーザブル
│   └── plugins/
│       └── axios.ts                  # axiosインスタンス設定
```

---

## 画面仕様（フロントエンド）

### 監督一覧画面

#### 基本情報

- **コンポーネント**: `src/views/ManagerList.vue`
- **パス**: `/managers`
- **ルート設定**: `requiresAuth: true`（認証必須）
- **レイアウト**: `v-container` > `v-card` > `v-data-table` + `ManagerDialog` + `TeamDialog` + `ConfirmDialog`

#### 画面構成

```
+------------------------------------------------------------------+
|  監督一覧                                          [ + 監督追加 ] |
+------------------------------------------------------------------+
| [>] | ID | 名前      | 略称   | IRC名  | ユーザーID | アクション |
+------------------------------------------------------------------+
| [v] | 1  | 霧雨魔理沙 | 魔理沙 | marisa | user_001  | [編集][削除] |
|     +----------------------------------------------------------+  |
|     | 所属チーム:                            [ + チーム追加 ]    |  |
|     |  ・博麗神社                  [有効]          [編集]       |  |
|     |  ・紅魔館                    [無効]          [編集]       |  |
|     +----------------------------------------------------------+  |
| [>] | 2  | 十六夜咲夜 | 咲夜   | sakuya | user_002  | [編集][削除] |
+------------------------------------------------------------------+
```

#### データテーブル（v-data-table）

##### ヘッダー定義

| title | key | sortable | 説明 |
|-------|-----|----------|------|
| （空） | `data-table-expand` | - | 行展開アイコン（チーム一覧表示） |
| ID | `id` | true | 監督ID（自動採番） |
| 名前 | `name` | true | 監督の正式名称 |
| 略称 | `short_name` | true | 監督の略称 |
| IRC名 | `irc_name` | true | IRC上での表示名 |
| ユーザーID | `user_id` | true | 紐づくユーザーID（nullable） |
| アクション | `actions` | false | 編集・削除ボタン |

ヘッダーラベルは `computed(() => [...])` で定義され、`t('managerList.headers.id')` 等の国際化キーから動的に生成される。

##### データバインディング

```typescript
const managers = ref<Manager[]>([]);
const loading = ref(true);
```

- `managers`: APIから取得した監督一覧データ（`Manager[]` 型）
- `loading`: データ取得中の状態（`true` の間はローディング表示）

##### v-data-table 属性

```vue
<v-data-table
  :headers="headers"
  :items="managers"
  :loading="loading"
  :items-length="totalItems"
  :items-per-page="itemsPerPage"
  class="elevation-1"
  item-value="id"
  show-expand
  :no-data-text="t('managerList.noData')"
  @update:options="onOptionsUpdate"
>
```

- `show-expand`: 行展開機能を有効化（チーム一覧を展開表示するため）
- `item-value="id"`: 各行の一意キーとして `id` を使用
- `no-data-text`: データが0件の場合のメッセージ（国際化対応）
- `items-length`: サーバーサイドページネーションの総件数
- `items-per-page`: 1ページあたりの表示件数（デフォルト25）
- `@update:options`: ページ変更時にサーバーへリクエストを送信

#### アクションボタン

##### 監督追加ボタン

```vue
<v-btn color="primary" @click="openDialog()" prepend-icon="mdi-plus">
  {{ t('managerList.addManager') }}
</v-btn>
```

- **配置**: 画面右上（カードタイトル行の右端）
- **動作**: `openDialog()` を引数なしで呼び出し → `editingManager.value = null` → ManagerDialog を新規作成モードで表示

##### 編集アイコン

```vue
<v-icon size="small" class="mr-2" @click="openDialog(item)">
  mdi-pencil
</v-icon>
```

- **配置**: 各行の「アクション」列
- **動作**: `openDialog(item)` を呼び出し → `editingManager.value = { ...item }` → ManagerDialog を編集モードで表示
- **引数**: 該当行の `Manager` オブジェクト全体

##### 削除アイコン

```vue
<v-icon size="small" @click="deleteManager(item.id)">
  mdi-delete
</v-icon>
```

- **配置**: 各行の「アクション」列（編集アイコンの右隣）
- **動作**: `deleteManager(item.id)` を呼び出し → ConfirmDialog で確認 → `DELETE /api/v1/managers/:id` 実行

#### 行展開機能（Expanded Row）

##### 実装コード

```vue
<template v-slot:expanded-row="{ columns, item }">
  <tr>
    <td :colspan="columns.length">
      <div class="pa-4 bg-grey-lighten-5">
        <div class="d-flex align-center mb-2">
          <h4 class="text-subtitle-1">{{ t('managerList.expanded.title') }}</h4>
          <v-spacer></v-spacer>
          <v-btn size="small" color="primary" @click="openTeamDialog(null, item.id)" prepend-icon="mdi-plus">
            {{ t('managerList.expanded.addTeam') }}
          </v-btn>
        </div>

        <div v-if="item.teams && item.teams.length > 0">
          <v-list density="compact" lines="one">
            <v-list-item v-for="team in item.teams" :key="team.id" :title="team.name">
              <template v-slot:append>
                <v-chip :color="team.is_active ? 'success' : 'default'" size="small" variant="tonal" class="mr-4">
                  {{ team.is_active ? t('managerList.expanded.active') : t('managerList.expanded.inactive') }}
                </v-chip>
                <v-icon size="small" @click="openTeamDialog(team, item.id)">mdi-pencil</v-icon>
              </template>
            </v-list-item>
          </v-list>
        </div>
        <div v-else class="py-4 text-center text-grey">
          {{ t('managerList.expanded.noTeams') }}
        </div>
      </div>
    </td>
  </tr>
</template>
```

##### 表示内容

1. **ヘッダー行**:
   - 左側: 「所属チーム:」（`t('managerList.expanded.title')`）
   - 右側: 「+ チーム追加」ボタン（`openTeamDialog(null, item.id)` を呼び出し）

2. **チーム一覧**（`item.teams.length > 0` の場合）:
   - `v-list-item` でチーム名を表示
   - `is_active` が `true` なら緑色の「有効」チップ、`false` なら灰色の「無効」チップ
   - 各チームに編集アイコン（`mdi-pencil`）を配置 → `openTeamDialog(team, item.id)` を呼び出し

3. **チームなしメッセージ**（`item.teams.length === 0` の場合）:
   - 中央揃えで「チームがありません」（`t('managerList.expanded.noTeams')`）

##### データ取得

展開行のデータ（`item.teams`）は、`GET /api/v1/managers` のレスポンスに含まれる `teams` 配列により、監督一覧取得時に一緒に取得される。フロントエンド側で追加のAPI呼び出しは不要。

---

### 監督編集/作成ダイアログ（ManagerDialog）

#### 基本情報

- **コンポーネント**: `src/components/ManagerDialog.vue`
- **タイプ**: モーダルダイアログ（`v-dialog`）
- **最大幅**: `500px`

#### Props

```typescript
interface Props {
  isVisible: boolean;          // ダイアログの表示状態
  manager: Manager | null;     // 編集対象のManagerデータ（新規作成時はnull）
}
```

#### Emits

```typescript
const emit = defineEmits(['update:isVisible', 'save']);
```

- `update:isVisible`: v-model による双方向バインディング（ダイアログ開閉制御）
- `save`: 保存成功時に親へ通知（親側で `fetchManagers()` を再実行）

#### フォームフィールド

| ラベル | v-model | rules | HTML属性 | バリデーション | 説明 |
|--------|---------|-------|---------|--------------|------|
| 名前 | `editedManager.name` | `[rules.required]` | `required` | 必須 | 監督の正式名称 |
| 略称 | `editedManager.short_name` | - | `required` | - | 監督の略称 |
| IRC名 | `editedManager.irc_name` | - | `required` | - | IRC上での表示名 |
| ユーザーID | `editedManager.user_id` | - | - | - | 紐づくユーザーID（任意） |

**注意**: `required` HTML属性は付与されているが、バックエンドのバリデーションは `name` のみ必須（`validates :name, presence: true`）。他のフィールドは nullable。

#### バリデーションルール

```typescript
const rules = {
  required: (value: string) => !!value || t('managerDialog.validation.required'),
};
```

- `rules.required`: 値が空でないことをチェック
- エラーメッセージは国際化対応（`t('managerDialog.validation.required')`）

#### フォーム有効性判定

```typescript
const isFormValid = computed(() => !!editedManager.value.name);
```

- `name` が空でなければ `true`
- 保存ボタンの `disabled` 属性にバインド

#### ダイアログレイアウト

```
+------------------------------------+
|  監督を追加 / 監督を編集            |
+------------------------------------+
|  名前:       [________________]   |
|              （必須）              |
|  略称:       [________________]   |
|                                    |
|  IRC名:      [________________]   |
|                                    |
|  ユーザーID: [________________]   |
|                                    |
|                                    |
|       [ キャンセル ]  [ 保存 ]    |
+------------------------------------+
```

#### ボタン動作

##### キャンセルボタン

```vue
<v-btn color="blue-darken-1" variant="text" @click="close">
  {{ t('actions.cancel') }}
</v-btn>
```

- `close()` メソッドを呼び出し → `internalIsVisible.value = false` → ダイアログを閉じる
- 変更は破棄される（`editedManager` の状態は次回 `watch` で再初期化）

##### 保存ボタン

```vue
<v-btn color="blue-darken-1" variant="text" @click="save" :disabled="!isFormValid">
  {{ t('actions.save') }}
</v-btn>
```

- `save()` メソッドを呼び出し
- `isFormValid` が `false` の場合は `disabled`

#### save メソッドの処理フロー

```typescript
const save = async () => {
  if (!isFormValid.value) return; // バリデーションチェック

  try {
    if (isNew.value) {
      // 新規作成
      await axios.post('/managers', { manager: editedManager.value });
      showSnackbar(t('managerDialog.notifications.addSuccess'), 'success');
    } else {
      // 更新
      await axios.patch(`/managers/${editedManager.value.id}`, { manager: editedManager.value });
      showSnackbar(t('managerDialog.notifications.updateSuccess'), 'success');
    }
    emit('save'); // 親へ通知（一覧再取得のトリガー）
    close();      // ダイアログを閉じる
  } catch (error: any) {
    console.error('Error saving manager:', error);
    // エラーレスポンスがあれば表示
    if (error.response?.data?.errors) {
      const errorMessages = Object.values(error.response.data.errors).flat().join('\n')
      showSnackbar(t('managerDialog.notifications.saveFailedWithErrors', { errors: errorMessages }), 'error')
    } else {
      showSnackbar(t('managerDialog.notifications.saveFailed'), 'error');
    }
  }
};
```

##### 新規作成モード（`isNew === true`）

1. `POST /api/v1/managers` に `{ manager: editedManager.value }` を送信
2. 成功:
   - スナックバーで成功メッセージ表示（`t('managerDialog.notifications.addSuccess')`）
   - `save` イベントを emit → 親で `fetchManagers()` 実行
   - ダイアログを閉じる

##### 更新モード（`isNew === false`）

1. `PATCH /api/v1/managers/:id` に `{ manager: editedManager.value }` を送信
2. 成功:
   - スナックバーで成功メッセージ表示（`t('managerDialog.notifications.updateSuccess')`）
   - `save` イベントを emit
   - ダイアログを閉じる

##### エラーハンドリング

1. `error.response?.data?.errors` が存在する場合:
   - バックエンドのバリデーションエラー（ActiveModel::Errors の形式）
   - 全エラーメッセージを改行で連結して表示
   - 例: `{ "name": ["を入力してください"] }` → 「を入力してください」

2. それ以外のエラー:
   - 汎用エラーメッセージを表示（`t('managerDialog.notifications.saveFailed')`）

#### watch による初期化

```typescript
watch(() => props.isVisible, (newVal) => {
  if (newVal) {
    editedManager.value = props.manager ? { ...props.manager } : { ...defaultManager };
  }
});
```

- ダイアログが開かれた時（`isVisible` が `true` になった時）、`editedManager` を初期化
- `props.manager` が存在すれば編集モード（スプレッド構文でコピーして参照を分離）
- `null` なら新規作成モード（`defaultManager` で初期化）

**重要**: スプレッド構文 `{ ...props.manager }` を使用することで、親コンポーネントの `managers` 配列を直接変更しない（イミュータブルな操作）。

---

## APIエンドポイント仕様

### 共通事項

- **ベースURL**: `/api/v1`
- **コントローラー**: `Api::V1::ManagersController < Api::V1::BaseController`
- **ファイルパス**: `app/controllers/api/v1/managers_controller.rb`
- **認証**: `before_action :authenticate_user!`（`Api::V1::BaseController` で設定。全エンドポイントで認証必須）
- **CSRF保護**: 有効（ApplicationController で設定済み）
- **Content-Type**: `application/json`（リクエスト・レスポンス共通）

---

### GET /api/v1/managers

監督一覧を取得する。サーバーサイドページネーション対応。各監督に紐づくチーム情報も含めて返す。

#### リクエスト

```http
GET /api/v1/managers?page=1&per_page=25 HTTP/1.1
Host: localhost:3000
```

**クエリパラメータ**:

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `page` | integer | 1 | ページ番号（1始まり、1未満は1に補正） |
| `per_page` | integer | 25 | 1ページあたりの件数（1未満または100超は25に補正） |

**リクエストボディ**: なし

#### 実装コード

```ruby
# GET /api/v1/managers
def index
  page = (params[:page] || 1).to_i
  per_page = (params[:per_page] || 25).to_i

  # パラメータのバリデーション
  page = 1 if page < 1
  per_page = 25 if per_page < 1 || per_page > 100

  offset = (page - 1) * per_page

  @managers = Manager.all.includes(teams: :season).order(:id).limit(per_page).offset(offset)
  total_count = Manager.count
  total_pages = (total_count.to_f / per_page).ceil

  render json: {
    data: @managers.as_json(include: { teams: { methods: [ :has_season ] } }),
    meta: {
      total_count: total_count,
      per_page: per_page,
      current_page: page,
      total_pages: total_pages
    }
  }
end
```

#### 処理フロー

1. `page` と `per_page` パラメータを取得・バリデーション
2. `Manager.all.includes(teams: :season)` でN+1問題を回避（eager load、チームのシーズン情報も含む）
3. `.order(:id).limit(per_page).offset(offset)` でID順にソート・ページネーション
4. `Manager.count` で全件数を取得
5. `as_json(include: { teams: { methods: [:has_season] } })` でチーム情報（`has_season` メソッドの結果を含む）をJSONに含める
6. `data` と `meta`（ページネーション情報）を含むレスポンスを返却

#### 成功レスポンス（200 OK）

```json
{
  "data": [
    {
      "id": 1,
      "name": "霧雨魔理沙",
      "short_name": "魔理沙",
      "irc_name": "marisa",
      "user_id": "user_001",
      "role": "director",
      "teams": [
        {
          "id": 10,
          "name": "博麗神社",
          "short_name": "神社",
          "is_active": true,
          "has_season": true
        },
        {
          "id": 11,
          "name": "紅魔館",
          "short_name": "紅魔",
          "is_active": false,
          "has_season": false
        }
      ]
    },
    {
      "id": 2,
      "name": "十六夜咲夜",
      "short_name": "咲夜",
      "irc_name": "sakuya",
      "user_id": null,
      "role": "director",
      "teams": []
    }
  ],
  "meta": {
    "total_count": 50,
    "per_page": 25,
    "current_page": 1,
    "total_pages": 2
  }
}
```

#### レスポンスフィールド詳細

**data 配列の各要素:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | number | 監督ID（自動採番） |
| `name` | string | 監督の正式名称 |
| `short_name` | string \| null | 監督の略称（nullable） |
| `irc_name` | string \| null | IRC上での表示名（nullable） |
| `user_id` | string \| null | 紐づくユーザーID（nullable） |
| `role` | string | 役割（`as_json` により文字列で出力） |
| `teams` | array | 紐づくチーム一覧 |
| `teams[].has_season` | boolean | チームにシーズンが存在するかどうか |

**meta オブジェクト:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `total_count` | number | 監督の総件数 |
| `per_page` | number | 1ページあたりの件数 |
| `current_page` | number | 現在のページ番号 |
| `total_pages` | number | 総ページ数 |

**注意**:
- レスポンス形式は `as_json` による直接シリアライズ（ManagerSerializer は使用しない）
- 監督にチームが紐づいていない場合、`teams` は空配列 `[]`

---

### GET /api/v1/managers/:id

指定IDの監督詳細を取得する。紐づくチーム情報も含む。

#### リクエスト

```http
GET /api/v1/managers/1 HTTP/1.1
Host: localhost:3000
Authorization: Bearer {access_token}
```

#### 実装コード

```ruby
# GET /api/v1/managers/:id
def show
  render json: @manager, include: :teams # Manager詳細時に紐づくTeamも返す
end

private

def set_manager
  @manager = Manager.find(params[:id])
rescue ActiveRecord::RecordNotFound
  render json: { error: 'Manager not found' }, status: :not_found
end
```

`before_action :set_manager` により、アクション実行前に `set_manager` が呼ばれる。

#### 処理フロー

1. `set_manager` で `Manager.find(params[:id])` を実行
2. レコードが存在すれば `@manager` に格納
3. 存在しなければ `ActiveRecord::RecordNotFound` を rescue して 404 エラーを返す
4. 正常時: `render json: @manager, include: :teams` でシリアライズ

#### 成功レスポンス（200 OK）

```json
{
  "id": 1,
  "name": "霧雨魔理沙",
  "short_name": "魔理沙",
  "irc_name": "marisa",
  "user_id": "user_001",
  "teams": [
    {
      "id": 10,
      "name": "博麗神社",
      "short_name": "神社",
      "is_active": true
    }
  ]
}
```

#### 失敗レスポンス（404 Not Found）

```json
{
  "error": "Manager not found"
}
```

**発生条件**: `params[:id]` に対応する Manager レコードが存在しない場合

---

### POST /api/v1/managers

新規監督を作成する。

#### リクエスト

```http
POST /api/v1/managers HTTP/1.1
Host: localhost:3000
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "manager": {
    "name": "アリス・マーガトロイド",
    "short_name": "アリス",
    "irc_name": "alice",
    "user_id": "user_003"
  }
}
```

#### リクエストパラメータ

**Strong Parameters（許可されたパラメータ）**:

```ruby
def manager_params
  params.require(:manager).permit(:name, :short_name, :irc_name, :user_id)
end
```

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `name` | string | ○ | 監督の正式名称（バリデーション: `presence: true`） |
| `short_name` | string | - | 監督の略称（nullable） |
| `irc_name` | string | - | IRC上での表示名（nullable） |
| `user_id` | string | - | 紐づくユーザーID（nullable） |

**注意**: `role` パラメータは許可されていない（現在未使用のため）。

#### 実装コード

```ruby
# POST /api/v1/managers
def create
  @manager = Manager.new(manager_params)
  if @manager.save
    render json: @manager, status: :created
  else
    render json: @manager.errors, status: :unprocessable_entity
  end
end
```

#### 処理フロー

1. `manager_params` で許可されたパラメータを取得
2. `Manager.new(manager_params)` で新規インスタンス生成
3. `@manager.save` でバリデーション + DB保存
4. 成功: 201 Created + 作成された監督のJSONを返す
5. 失敗: 422 Unprocessable Entity + バリデーションエラーを返す

#### 成功レスポンス（201 Created）

```json
{
  "id": 3,
  "name": "アリス・マーガトロイド",
  "short_name": "アリス",
  "irc_name": "alice",
  "user_id": "user_003",
  "teams": []
}
```

- 新規作成された監督の情報を返す
- `teams` は空配列（作成時点ではチーム紐付けなし）

#### 失敗レスポンス（422 Unprocessable Entity）

```json
{
  "name": ["を入力してください"]
}
```

**発生条件**: バリデーションエラー（例: `name` が空の場合）

**エラー形式**: ActiveModel::Errors の JSON 形式
- キー: バリデーション失敗したカラム名
- 値: エラーメッセージの配列

---

### PATCH/PUT /api/v1/managers/:id

既存監督の情報を更新する。

#### リクエスト

```http
PATCH /api/v1/managers/1 HTTP/1.1
Host: localhost:3000
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "manager": {
    "name": "霧雨魔理沙（更新）",
    "short_name": "魔理沙",
    "irc_name": "marisa",
    "user_id": "user_001"
  }
}
```

**HTTP メソッド**: `PATCH` または `PUT` の両方に対応（Rails の `resources` ルーティング仕様）

#### 実装コード

```ruby
# PATCH/PUT /api/v1/managers/:id
def update
  if @manager.update(manager_params)
    render json: @manager
  else
    render json: @manager.errors, status: :unprocessable_entity
  end
end
```

#### 処理フロー

1. `before_action :set_manager` で対象レコードを取得（`@manager`）
2. `@manager.update(manager_params)` で更新
3. 成功: 200 OK + 更新後の監督のJSONを返す
4. 失敗: 422 Unprocessable Entity + バリデーションエラーを返す

#### 成功レスポンス（200 OK）

```json
{
  "id": 1,
  "name": "霧雨魔理沙（更新）",
  "short_name": "魔理沙",
  "irc_name": "marisa",
  "user_id": "user_001",
  "teams": [...]
}
```

- 更新後の監督情報を返す
- `teams` 配列は `include: :teams` 指定がないため、デフォルトでは含まれない可能性がある（ManagerSerializer の定義による）

**注意**: 現在の実装では `render json: @manager` のみで、`include` オプションが指定されていない。ManagerSerializer で `has_many :teams` が定義されているため、シリアライザーの設定により含まれる可能性がある。

#### 失敗レスポンス（422 Unprocessable Entity）

```json
{
  "name": ["を入力してください"]
}
```

**発生条件**: バリデーションエラー（例: `name` を空文字に更新しようとした場合）

---

### DELETE /api/v1/managers/:id

監督を削除する。

#### リクエスト

```http
DELETE /api/v1/managers/1 HTTP/1.1
Host: localhost:3000
Authorization: Bearer {access_token}
```

#### 実装コード

```ruby
# DELETE /api/v1/managers/:id
def destroy
  @manager.destroy
  head :no_content # 成功したが返すコンテンツがない場合
end
```

#### 処理フロー

1. `before_action :set_manager` で対象レコードを取得（`@manager`）
2. `@manager.destroy` で削除（`dependent: :destroy` により紐づく `TeamManager` レコードも削除される）
3. `head :no_content` で 204 No Content を返す（レスポンスボディなし）

#### 成功レスポンス（204 No Content）

**HTTPステータス**: 204

**レスポンスボディ**: なし（空）

**意味**: 削除成功、返すコンテンツなし

#### 失敗レスポンス（404 Not Found）

```json
{
  "error": "Manager not found"
}
```

**発生条件**: 指定IDの監督が存在しない場合（`set_manager` で rescue）

#### 依存関係の削除

```ruby
# Manager モデル
has_many :team_managers, dependent: :destroy
has_many :teams, through: :team_managers
```

- `dependent: :destroy` により、監督削除時に紐づく `TeamManager` レコードも自動的に削除される

---

## データモデル

### ER図

```
+----------------+       +------------------+       +----------------+
|   managers     |       |  team_managers   |       |     teams      |
+----------------+       +------------------+       +----------------+
| id (PK)        |<---+  | id (PK)          |  +--->| id (PK)        |
| name           |    |  | team_id (FK)     |--+    | name           |
| short_name     |    |  | manager_id (FK)  |       | short_name     |
| irc_name       |    +--| role (enum)      |       | is_active      |
| user_id        |       | created_at       |       | created_at     |
| role (enum)    |       | updated_at       |       | updated_at     |
| created_at     |       +------------------+       +----------------+
| updated_at     |
+----------------+
```

**設計の特徴**:
- `team_managers` 中間テーブル: 監督-チーム間の多対多関係を管理（role 付き）
- `teams` テーブルには `manager_id` カラムは存在しない。監督とチームの関係は全て `team_managers` 中間テーブルで管理される

---

### managers テーブル

#### スキーマ定義（db/schema.rb）

```ruby
create_table "managers", force: :cascade do |t|
  t.string "name"
  t.string "short_name"
  t.string "irc_name"
  t.string "user_id"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.integer "role", default: 0, null: false
end
```

#### カラム詳細

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| `id` | bigint | NOT NULL | 自動採番 | 監督ID（主キー） |
| `name` | string | NULL | - | 監督の正式名称 |
| `short_name` | string | NULL | - | 監督の略称 |
| `irc_name` | string | NULL | - | IRC上での表示名 |
| `user_id` | string | NULL | - | 紐づくユーザーID |
| `role` | integer | NOT NULL | 0 | 役割（enum: `director`=0, `coach`=1） |
| `created_at` | datetime | NOT NULL | - | 作成日時（Rails 自動管理） |
| `updated_at` | datetime | NOT NULL | - | 更新日時（Rails 自動管理） |

#### インデックス

スキーマ上、明示的なインデックスは定義されていない（`id` のみ主キーとして自動インデックス）。

**改善提案**: `name` や `user_id` での検索が頻繁な場合、インデックス追加を検討。

---

### team_managers テーブル（中間テーブル）

#### スキーマ定義（db/schema.rb）

```ruby
create_table "team_managers", force: :cascade do |t|
  t.bigint "team_id", null: false
  t.bigint "manager_id", null: false
  t.integer "role", default: 0, null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["manager_id"], name: "index_team_managers_on_manager_id"
  t.index ["team_id"], name: "index_team_managers_on_team_id"
end
```

#### カラム詳細

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| `id` | bigint | NOT NULL | 自動採番 | レコードID（主キー） |
| `team_id` | bigint | NOT NULL | - | チームID（外部キー → `teams.id`） |
| `manager_id` | bigint | NOT NULL | - | 監督ID（外部キー → `managers.id`） |
| `role` | integer | NOT NULL | 0 | 役割（enum: `director`=0, `coach`=1） |
| `created_at` | datetime | NOT NULL | - | 作成日時 |
| `updated_at` | datetime | NOT NULL | - | 更新日時 |

#### インデックス

| インデックス名 | カラム | 説明 |
|--------------|-------|------|
| `index_team_managers_on_team_id` | `team_id` | チームからの逆引き高速化 |
| `index_team_managers_on_manager_id` | `manager_id` | 監督からの逆引き高速化 |

#### 外部キー制約

スキーマ上、明示的な外部キー制約は記述されていないが、モデルレベルで `belongs_to :team`, `belongs_to :manager` により参照整合性を保証。

**改善提案**: DB レベルで外部キー制約を追加することで、参照整合性をより厳密に保証可能。

---

### Manager モデル

#### 実装コード（app/models/manager.rb）

```ruby
class Manager < ApplicationRecord
  has_many :team_managers, dependent: :destroy
  has_many :teams, through: :team_managers
  enum :role, { director: 0, coach: 1 }
  validates :name, presence: true
end
```

#### リレーション

| 定義 | 説明 |
|-----|------|
| `has_many :team_managers, dependent: :destroy` | 監督削除時、紐づく TeamManager レコードも削除 |
| `has_many :teams, through: :team_managers` | 多対多関係でチームを取得（中間テーブル経由） |

**削除時の挙動**:
- `Manager.destroy` → 紐づく `TeamManager` レコードも自動削除（`dependent: :destroy`）

#### enum（列挙型）

```ruby
enum :role, { director: 0, coach: 1 }
```

| 値 | 名前 | 説明 |
|----|------|------|
| 0 | `director` | 監督 |
| 1 | `coach` | コーチ |

**自動生成されるメソッド**:
- `manager.director?` / `manager.coach?` — 真偽値判定
- `manager.director!` / `manager.coach!` — role 更新
- `Manager.directors` / `Manager.coaches` — スコープ（該当 role のレコードを取得）

**注意**: `managers.role` カラムは存在するが、現在のコントローラー・シリアライザーでは使用されていない。主に `team_managers.role` でチームごとの役割を管理している。

#### バリデーション

```ruby
validates :name, presence: true
```

- `name`: 必須（空文字不可）
- 他のカラム（`short_name`, `irc_name`, `user_id`）はバリデーションなし（nullable）

---

### TeamManager モデル

#### 実装コード（app/models/team_manager.rb）

```ruby
class TeamManager < ApplicationRecord
  belongs_to :team
  belongs_to :manager

  enum :role, { director: 0, coach: 1 }

  validates :role, presence: true
  validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: 'には既に監督が設定されています' }
  validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [:create, :update]

  private

  def manager_cannot_be_assigned_to_multiple_teams_in_same_league
    return unless manager_id.present? && team.present?

    # 現在のチームが所属するリーグを取得
    current_league = team.leagues.first # チームは複数のリーグに所属する可能性があるが、コミッショナーモードでは1つのリーグを想定
    return unless current_league.present?

    # 同じリーグに所属する他のチームを取得
    other_teams_in_same_league = current_league.teams.where.not(id: team.id)

    # 同じマネージャーが他のチームに割り当てられているかチェック
    if TeamManager.where(manager_id: manager_id, team_id: other_teams_in_same_league.select(:id)).exists?
      errors.add(:manager_id, 'は同一リーグ内の複数のチームに兼任することはできません')
    end
  end
end
```

#### リレーション

| 定義 | 説明 |
|-----|------|
| `belongs_to :team` | チームへの所属（必須。Rails 5.0 以降は `belongs_to` で自動 presence validation） |
| `belongs_to :manager` | 監督への所属（必須） |

#### enum（列挙型）

```ruby
enum :role, { director: 0, coach: 1 }
```

`managers.role` と同じ定義。`team_manager.director?` 等のメソッドが自動生成される。

#### バリデーション

##### 1. role の必須チェック

```ruby
validates :role, presence: true
```

`role` が `nil` でないことを保証（デフォルト値 `0` があるため、通常は満たされる）。

##### 2. director role の一意性制約

```ruby
validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: 'には既に監督が設定されています' }
```

**条件**:
- `role` が `director` (0) の場合のみ適用
- 同じ `team_id` と `role` の組み合わせが既に存在する場合、エラー

**効果**: 1チームにつき `director` ロールの TeamManager は1件のみ作成可能

**例外**: `coach` ロールには制限なし（複数人可能）

##### 3. リーグ内兼任制約（カスタムバリデーション）

```ruby
validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [:create, :update]
```

**目的**: 同一リーグ内の複数チームに同じ監督を割り当てることを禁止

**処理フロー**:

1. `manager_id` と `team` が存在することを確認
2. `team.leagues.first` で該当チームが所属するリーグを取得
   - **注意**: 複数リーグに所属している場合、最初のリーグのみで判定
3. `current_league.teams.where.not(id: team.id)` で同じリーグの他のチームを取得
4. `TeamManager.where(manager_id: manager_id, team_id: other_teams_in_same_league.select(:id)).exists?` でチェック
5. 該当する場合、エラー「は同一リーグ内の複数のチームに兼任することはできません」を追加

**制約の意図**:
- コミッショナーモードでは、1つのリーグ内で公平な競技運営を保つため、監督の兼任を禁止する
- 別リーグであれば兼任可能（例: リーグA の監督とリーグB の監督を兼任）

**既知の課題**: チームが複数リーグに所属している場合、`leagues.first` を使用しているため、最初のリーグのみでチェックが行われる。複数リーグ対応が必要な場合、実装の拡張が必要（後述の「既知の制約」参照）。

---

### ManagerSerializer

#### 実装コード（app/serializers/manager_serializer.rb）

```ruby
class ManagerSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :irc_name , :user_id

  # Manager詳細取得時に、紐づくTeamもJSONに含める
  has_many :teams
end
```

#### シリアライズ対象属性

| 属性 | 型 | 説明 |
|-----|-----|------|
| `id` | number | 監督ID |
| `name` | string | 監督の正式名称 |
| `short_name` | string \| null | 監督の略称 |
| `irc_name` | string \| null | IRC上での表示名 |
| `user_id` | string \| null | 紐づくユーザーID |

**注意**: `role` カラムはシリアライザーに含まれていない（現在未使用のため）。

#### 関連オブジェクト

```ruby
has_many :teams
```

- `include: :teams` オプション指定時、各監督の `teams` 配列を JSON に含める
- `teams` は `Manager#teams` メソッドで取得（`has_many :teams, through: :team_managers`）
- 各チームは TeamSerializer でシリアライズされる

**フロントエンドでの使用例**:
```typescript
const response = await axios.get<Manager[]>('/managers');
// response.data[0].teams[0].name でチーム名にアクセス可能
```

---

## ビジネスロジック

### 監督とチームの関係管理

#### 中間テーブルによる関係管理

本システムでは、監督とチームの関係を `team_managers` 中間テーブルで管理する：

```ruby
# team_managers テーブル（中間テーブル）
t.bigint "team_id", null: false
t.bigint "manager_id", null: false
t.integer "role", default: 0, null: false  # director=0, coach=1
```

- `team_managers` を通じて、監督（director）またはコーチ（coach）として複数のスタッフを割り当て可能
- `Manager#teams` で紐づくチーム一覧を取得（`has_many :teams, through: :team_managers`）
- `Team#managers` で紐づく監督・コーチ一覧を取得

#### 関係の取得方法

##### 監督から見た所属チーム一覧

```ruby
manager = Manager.find(1)
manager.teams  # => [Team, Team, ...]
```

- `has_many :teams, through: :team_managers` により取得
- `team_managers` テーブルで紐づけられたチームのみ（role 問わず）

##### チームから見た監督・コーチ一覧

```ruby
team = Team.find(10)
team.managers  # => [Manager, Manager, ...]
```

- `has_many :managers, through: :team_managers` により取得
- director と coach の両方を含む

---

### ロール（役割）管理

#### director（監督）

- **用途**: チームの主要な監督役
- **制約**: 1チームにつき1人まで（`validates :team_id, uniqueness: { scope: :role, if: -> { director? } }`）
- **SQL例**:
  ```sql
  -- チームID=10のdirectorを取得
  SELECT managers.* FROM managers
  INNER JOIN team_managers ON team_managers.manager_id = managers.id
  WHERE team_managers.team_id = 10 AND team_managers.role = 0;
  ```

#### coach（コーチ）

- **用途**: チームのコーチ役
- **制約**: 制限なし（複数人割り当て可能）
- **SQL例**:
  ```sql
  -- チームID=10のcoach一覧を取得
  SELECT managers.* FROM managers
  INNER JOIN team_managers ON team_managers.manager_id = managers.id
  WHERE team_managers.team_id = 10 AND team_managers.role = 1;
  ```

#### role の判定メソッド

```ruby
team_manager = TeamManager.first
team_manager.director?  # => true or false
team_manager.coach?     # => true or false
```

enum により自動生成されるメソッドを使用。

---

### リーグ内兼任制約

#### 制約の目的

コミッショナーモードでは、1つのリーグ内で公平な競技運営を保つため、同じ監督が同一リーグ内の複数チームを兼任することを禁止する。

#### 実装詳細（TeamManager モデル）

```ruby
validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [:create, :update]

private

def manager_cannot_be_assigned_to_multiple_teams_in_same_league
  return unless manager_id.present? && team.present?

  # 現在のチームが所属するリーグを取得
  current_league = team.leagues.first # チームは複数のリーグに所属する可能性があるが、コミッショナーモードでは1つのリーグを想定
  return unless current_league.present?

  # 同じリーグに所属する他のチームを取得
  other_teams_in_same_league = current_league.teams.where.not(id: team.id)

  # 同じマネージャーが他のチームに割り当てられているかチェック
  if TeamManager.where(manager_id: manager_id, team_id: other_teams_in_same_league.select(:id)).exists?
    errors.add(:manager_id, 'は同一リーグ内の複数のチームに兼任することはできません')
  end
end
```

#### 処理フロー図

```
TeamManager.create(manager_id: 1, team_id: 10, role: :director)
  ↓
manager_cannot_be_assigned_to_multiple_teams_in_same_league 実行
  ↓
team.leagues.first → League (id: 1)
  ↓
current_league.teams.where.not(id: 10) → [Team(11), Team(12), ...]
  ↓
TeamManager.where(manager_id: 1, team_id: [11, 12, ...]).exists?
  ↓
【YES】 → errors.add(:manager_id, '兼任不可')
【NO】  → バリデーション成功
```

#### 具体例

**シナリオ**: リーグA に所属するチーム1、チーム2 があり、監督A をチーム1 に割り当て済み。

1. **OK**: 監督A をリーグB のチーム3 に割り当て
   - 別リーグなので兼任可能

2. **NG**: 監督A をリーグA のチーム2 に割り当て
   - 同一リーグ内での兼任のため、バリデーションエラー
   - エラーメッセージ: 「は同一リーグ内の複数のチームに兼任することはできません」

#### 既知の制約

```ruby
current_league = team.leagues.first  # 最初のリーグのみ取得
```

- チームが複数リーグに所属している場合、`leagues.first` を使用しているため、**最初のリーグのみで兼任チェック**が行われる
- 2番目以降のリーグでの兼任は検出されない

**改善案**: 全リーグをループしてチェックする実装に変更
```ruby
team.leagues.each do |league|
  # 各リーグごとに兼任チェック
end
```

---

### 監督削除時の依存関係

#### 削除フロー

```ruby
manager = Manager.find(1)
manager.destroy
```

##### 1. TeamManager の自動削除（dependent: :destroy）

```ruby
has_many :team_managers, dependent: :destroy
```

- 監督削除時、紐づく `TeamManager` レコードも自動削除される
- SQL例:
  ```sql
  DELETE FROM team_managers WHERE manager_id = 1;
  DELETE FROM managers WHERE id = 1;
  ```

**注意**: `teams` テーブルには `manager_id` カラムが存在しないため、`TeamManager` レコードの自動削除のみで監督削除が完了する。

---

## フロントエンド実装詳細

### ManagerList.vue コンポーネント

#### ファイル構成

```vue
<template>
  <!-- 画面UI -->
</template>

<script lang="ts" setup>
  // ロジック
</script>

<style scoped>
  /* スタイル */
</style>
```

#### インポート

```typescript
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import { type Manager } from '@/types/manager'
import { type Team } from '@/types/team'
import { type PaginatedResponse } from '@/types/pagination'
import ManagerDialog from '@/components/ManagerDialog.vue'
import TeamDialog from '@/components/TeamDialog.vue'
```

#### リアクティブデータ

| 変数 | 型 | 初期値 | 説明 |
|-----|-----|-------|------|
| `managers` | `ref<Manager[]>` | `[]` | 監督一覧データ |
| `loading` | `ref<boolean>` | `true` | ローディング状態 |
| `totalItems` | `ref<number>` | `0` | 監督の総件数（ページネーション用） |
| `itemsPerPage` | `ref<number>` | `25` | 1ページあたりの件数 |
| `currentPage` | `ref<number>` | `1` | 現在のページ番号 |
| `dialogVisible` | `ref<boolean>` | `false` | ManagerDialog の表示状態 |
| `editingManager` | `ref<Manager \| null>` | `null` | 編集中の監督データ（新規作成時は `null`） |
| `teamDialogVisible` | `ref<boolean>` | `false` | TeamDialog の表示状態 |
| `editingTeam` | `ref<Team \| null>` | `null` | 編集中のチームデータ |
| `defaultManagerIdForTeam` | `ref<number \| null>` | `null` | チーム作成時にデフォルトで設定する監督ID |
| `confirmDialog` | `ref<InstanceType<typeof ConfirmDialog> \| null>` | `null` | ConfirmDialog コンポーネントへの参照 |

#### 算出プロパティ

```typescript
const headers = computed(() => [
  { title: '', key: 'data-table-expand' },
  { title: t('managerList.headers.id'), key: 'id' },
  { title: t('managerList.headers.name'), key: 'name' },
  { title: t('managerList.headers.shortName'), key: 'short_name' },
  { title: t('managerList.headers.ircName'), key: 'irc_name' },
  { title: t('managerList.headers.userId'), key: 'user_id' },
  { title: t('managerList.headers.actions'), key: 'actions', sortable: false },
]);
```

- `computed` により、言語切替時に自動で再計算
- 各ヘッダーラベルは `t()` 関数で国際化キーから取得

#### メソッド

##### fetchManagers(page, perPage)

```typescript
const fetchManagers = async (
  page: number = currentPage.value,
  perPage: number = itemsPerPage.value,
) => {
  loading.value = true
  try {
    const response = await axios.get<PaginatedResponse<Manager>>('/managers', {
      params: { page, per_page: perPage },
    })
    managers.value = response.data.data
    totalItems.value = response.data.meta.total_count
    currentPage.value = response.data.meta.current_page
    itemsPerPage.value = response.data.meta.per_page
  } catch (error) {
    console.error('Error fetching managers:', error)
    showSnackbar(t('managerList.fetchFailed'), 'error')
  } finally {
    loading.value = false
  }
}
```

**処理フロー**:
1. `loading.value = true` でローディング開始
2. `GET /api/v1/managers?page={page}&per_page={perPage}` でデータ取得
3. 成功: `response.data.data` を `managers.value` に格納、メタ情報からページネーション状態を更新
4. 失敗: コンソールエラー出力 + スナックバーでエラーメッセージ表示
5. 最後に `loading.value = false` でローディング終了

**呼び出しタイミング**:
- `onMounted()` 時（画面初期表示、デフォルトのページ・件数で取得）
- 監督追加/編集/削除後（一覧を再取得して最新状態を反映）
- `v-data-table` のページネーション操作時（`onOptionsUpdate` 経由）

##### onOptionsUpdate(options)

```typescript
const onOptionsUpdate = (options: { page: number; itemsPerPage: number }) => {
  fetchManagers(options.page, options.itemsPerPage)
}
```

- `v-data-table` の `@update:options` イベントハンドラー
- ページ変更やページサイズ変更時に、新しいパラメータで `fetchManagers` を呼び出す

##### deleteManager(id: number)

```typescript
const deleteManager = async (id: number) => {
  if (!confirmDialog.value) return;
  const result = await confirmDialog.value.open(
    t('managerList.deleteConfirmTitle'),
    t('managerList.deleteConfirmMessage'),
    { color: 'error' }
  );
  if (!result) {
    return;
  }
  try {
    await axios.delete(`/managers/${id}`);
    showSnackbar(t('managerList.deleteSuccess'), 'success');
    fetchManagers(); // 削除後、一覧を再取得
  } catch (error) {
    console.error('Error deleting manager:', error);
    showSnackbar(t('managerList.deleteFailed'), 'error');
  }
};
```

**処理フロー**:
1. `confirmDialog.value.open()` で確認ダイアログを表示
   - タイトル: `t('managerList.deleteConfirmTitle')`
   - メッセージ: `t('managerList.deleteConfirmMessage')`
   - 色: `error`（赤色）
2. ユーザーがキャンセルした場合（`result === false`）、何もしない
3. 削除承認された場合、`DELETE /api/v1/managers/:id` を実行
4. 成功: 成功メッセージを表示 + `fetchManagers()` で一覧を再取得
5. 失敗: エラーメッセージを表示

##### openDialog(manager: Manager | null = null)

```typescript
const openDialog = (manager: Manager | null = null) => {
  editingManager.value = manager ? { ...manager } : null; // 参照渡しを防ぐためスプレッド構文でコピー
  dialogVisible.value = true;
};
```

**処理フロー**:
1. `manager` 引数が存在する場合:
   - `{ ...manager }` でシャローコピー → `editingManager.value` に格納（編集モード）
2. `manager` が `null` の場合:
   - `editingManager.value = null`（新規作成モード）
3. `dialogVisible.value = true` でダイアログを表示

**重要**: スプレッド構文を使用することで、親の `managers` 配列を直接変更しない（イミュータブルな操作）。

##### openTeamDialog(team: Team | null, managerId: number)

```typescript
const openTeamDialog = (team: Team | null, managerId: number) => {
  editingTeam.value = team ? { ...team } : null;
  defaultManagerIdForTeam.value = managerId;
  teamDialogVisible.value = true;
};
```

**処理フロー**:
1. `team` 引数が存在する場合: 編集モード、`null` の場合: 新規作成モード
2. `defaultManagerIdForTeam.value = managerId` でデフォルト監督IDを設定
   - TeamDialog 側で、新規作成時にこのIDを初期値として使用
3. `teamDialogVisible.value = true` でダイアログを表示

**注意**: TeamDialog 自体の実装詳細は本仕様書の範囲外（チーム管理機能の仕様書を参照）。

##### onMounted()

```typescript
onMounted(() => {
  fetchManagers();
});
```

- コンポーネントがマウントされた時（画面初期表示時）に `fetchManagers()` を実行
- 初回データ取得を行う

---

### ManagerDialog.vue コンポーネント

#### Props 定義

```typescript
interface Props {
  isVisible: boolean;          // ダイアログの表示状態
  manager: Manager | null;     // 編集対象のManagerデータ（新規作成時はnull）
}

const props = defineProps<Props>();
```

#### Emits 定義

```typescript
const emit = defineEmits(['update:isVisible', 'save']);
```

- `update:isVisible`: v-model による双方向バインディング
- `save`: 保存成功時に親へ通知

#### リアクティブデータ

```typescript
const defaultManager: Manager = { id: 0, name: '',  short_name: '',  irc_name: '', user_id: null };
const editedManager = ref<Manager>({ ...defaultManager });
```

- `defaultManager`: 新規作成時の初期値テンプレート
- `editedManager`: 編集中のデータ（フォームフィールドにバインド）

#### 算出プロパティ

##### internalIsVisible

```typescript
const internalIsVisible = computed({
  get: () => props.isVisible,
  set: (value) => emit('update:isVisible', value)
});
```

- `v-model="internalIsVisible"` で v-dialog にバインド
- `get`: 親から受け取った `props.isVisible` を返す
- `set`: ダイアログ閉じる時に `emit('update:isVisible', false)` を発火

##### isNew

```typescript
const isNew = computed(() => !editedManager.value.id);
```

- `id` が存在しない（`0` または `undefined`）場合、新規作成モード
- ダイアログタイトルの切り替えに使用（`isNew ? '追加' : '編集'`）

##### isFormValid

```typescript
const isFormValid = computed(() => !!editedManager.value.name);
```

- `name` が空でなければ `true`
- 保存ボタンの `disabled` 属性にバインド

#### watch による初期化

```typescript
watch(() => props.isVisible, (newVal) => {
  if (newVal) {
    editedManager.value = props.manager ? { ...props.manager } : { ...defaultManager };
  }
});
```

**処理フロー**:
1. `props.isVisible` が `true` になった時（ダイアログが開かれた時）に発火
2. `props.manager` が存在すれば、そのコピーを `editedManager` に設定（編集モード）
3. `null` なら、`defaultManager` のコピーを設定（新規作成モード）

**重要**: スプレッド構文 `{ ...props.manager }` により、親データを直接変更しない。

#### save メソッド

```typescript
const save = async () => {
  if (!isFormValid.value) return; // バリデーションチェック

  try {
    if (isNew.value) {
      // 新規作成
      await axios.post('/managers', { manager: editedManager.value });
      showSnackbar(t('managerDialog.notifications.addSuccess'), 'success');
    } else {
      // 更新
      await axios.patch(`/managers/${editedManager.value.id}`, { manager: editedManager.value });
      showSnackbar(t('managerDialog.notifications.updateSuccess'), 'success');
    }
    emit('save'); // 親コンポーネントに保存が完了したことを通知 (一覧の再取得など)
    close();      // ダイアログを閉じる
  } catch (error: any) {
    console.error('Error saving manager:', error);
    // エラーレスポンスがあれば表示
    if (error.response?.data?.errors) {
      const errorMessages = Object.values(error.response.data.errors).flat().join('\n')
      showSnackbar(t('managerDialog.notifications.saveFailedWithErrors', { errors: errorMessages }), 'error')
    } else {
      showSnackbar(t('managerDialog.notifications.saveFailed'), 'error');
    }
  }
};
```

**エラーハンドリングの詳細**:

1. `error.response?.data?.errors` が存在する場合:
   - バックエンドのバリデーションエラー（ActiveModel::Errors の JSON 形式）
   - 例: `{ "name": ["を入力してください"] }`
   - `Object.values().flat().join('\n')` で全エラーメッセージを改行区切りで連結

2. それ以外のエラー:
   - ネットワークエラー、認証エラー等
   - 汎用エラーメッセージを表示

---

### TypeScript 型定義

#### Manager 型（src/types/manager.ts）

```typescript
import { type Team } from './team';

export interface Manager {
  id: number;
  name: string;
  short_name?: string | null;
  irc_name?: string | null;
  user_id?: string | null;
  teams?: Team[];
  role: 'director' | 'coach';
}
```

#### フィールド詳細

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `id` | `number` | ○ | 監督ID |
| `name` | `string` | ○ | 監督の正式名称 |
| `short_name` | `string \| null` | - | 監督の略称（optional） |
| `irc_name` | `string \| null` | - | IRC上での表示名（optional） |
| `user_id` | `string \| null` | - | 紐づくユーザーID（optional） |
| `teams` | `Team[]` | - | 紐づくチーム一覧（optional。APIレスポンスに含まれる） |
| `role` | `'director' \| 'coach'` | ○ | 役割（enum） |

#### PaginatedResponse 型（src/types/pagination.ts）

```typescript
export interface PaginationMeta {
  total_count: number
  per_page: number
  current_page: number
  total_pages: number
}

export interface PaginatedResponse<T> {
  data: T[]
  meta: PaginationMeta
}
```

監督一覧APIのレスポンスは `PaginatedResponse<Manager>` 型で受け取る。

#### 注意事項

- `role` フィールドは型定義に含まれているが、フロントエンドの ManagerList.vue、ManagerDialog.vue では `role` を表示・編集していない
- `as_json` によるレスポンスでは `role` が文字列として含まれる

---

## ルーティング

### Rails ルーティング（config/routes.rb）

```ruby
namespace :api do
  namespace :v1 do
    resources :managers do
      resources :teams, only: [:index, :create]
    end
  end
end
```

### 生成されるルート一覧

| HTTPメソッド | パス | コントローラー#アクション | 説明 |
|------------|-----|------------------------|------|
| GET | `/api/v1/managers` | `managers#index` | 監督一覧取得 |
| POST | `/api/v1/managers` | `managers#create` | 監督新規作成 |
| GET | `/api/v1/managers/:id` | `managers#show` | 監督詳細取得 |
| PATCH/PUT | `/api/v1/managers/:id` | `managers#update` | 監督更新 |
| DELETE | `/api/v1/managers/:id` | `managers#destroy` | 監督削除 |
| GET | `/api/v1/managers/:manager_id/teams` | `teams#index` | 特定監督に紐づくチーム一覧取得（※未実装） |
| POST | `/api/v1/managers/:manager_id/teams` | `teams#create` | 監督に紐づくチームを作成（※未実装） |

### ネストされたルートについて

```ruby
resources :teams, only: [:index, :create]
```

- `resources :managers` の中に `resources :teams` がネストしているため、`/api/v1/managers/:manager_id/teams` のルートが生成される
- ただし、現在の `TeamsController` ではこれらのアクションは実装されていない可能性がある
- フロントエンドでは `GET /api/v1/managers` の `include: :teams` でチーム情報を取得しており、ネストされたルートは使用していない

### フロントエンドルーティング（推定）

```typescript
// src/router/index.ts (推定)
{
  path: '/managers',
  name: 'ManagerList',
  component: () => import('@/views/ManagerList.vue'),
  meta: { requiresAuth: true }
}
```

- `/managers` パスで ManagerList.vue を表示
- `requiresAuth: true` により認証ガードを有効化

---

## 既知の制約・未実装機能

### ~~1. teams.manager_id の外部キー制約問題~~ （解決済み）

`teams` テーブルから `manager_id` カラムが削除されたため、この問題は解消された。監督とチームの関係は全て `team_managers` 中間テーブルで管理される。

---

### 2. role カラムの未使用

#### 問題

```ruby
# managers テーブル
t.integer "role", default: 0, null: false  # director=0, coach=1
```

- `managers.role` カラムは存在するが、以下の箇所で使用されていない:
  - ManagersController の `manager_params`（更新対象外）
  - ManagerSerializer（出力対象外）
  - フロントエンド（表示・編集なし）

#### 影響範囲

- 監督の役割（director/coach）は `team_managers.role` で管理されており、`managers.role` は冗長
- データの整合性が保証されない（`managers.role` と `team_managers.role` が異なる可能性）

#### 推奨される改善案

##### 案1: managers.role を削除

```ruby
# マイグレーション
remove_column :managers, :role
```

- `team_managers.role` のみで管理する設計に統一

##### 案2: managers.role を有効活用

- 監督のデフォルト役割として使用
- ManagersController、ManagerSerializer、フロントエンドで `role` を表示・編集可能にする

---

### 3. リーグ内兼任制約の複数リーグ対応不足

#### 問題

```ruby
# TeamManager モデル
current_league = team.leagues.first  # 最初のリーグのみ取得
```

- チームが複数リーグに所属している場合、`leagues.first` を使用しているため、最初のリーグのみで兼任チェックが行われる
- 2番目以降のリーグでの兼任は検出されない

#### 影響範囲

- TeamManager の作成・更新時のバリデーション
- 同一監督が複数リーグで兼任できてしまう可能性

#### 推奨される改善案

```ruby
def manager_cannot_be_assigned_to_multiple_teams_in_same_league
  return unless manager_id.present? && team.present?

  team.leagues.each do |league|
    other_teams_in_same_league = league.teams.where.not(id: team.id)
    if TeamManager.where(manager_id: manager_id, team_id: other_teams_in_same_league.select(:id)).exists?
      errors.add(:manager_id, "は#{league.name}内の複数のチームに兼任することはできません")
      return  # エラー追加後は早期リターン
    end
  end
end
```

- 全リーグをループしてチェックする実装に変更
- エラーメッセージにリーグ名を含める

---

### 4. ネストされたルートの未実装

#### 問題

```ruby
# routes.rb
resources :managers do
  resources :teams, only: [:index, :create]
end
```

- `/api/v1/managers/:manager_id/teams` のルートが生成されるが、TeamsController でこれらのアクションは実装されていない可能性がある
- フロントエンドでも使用されていない（`GET /api/v1/managers` の `include: :teams` で代替）

#### 影響範囲

- 現状、機能的な問題はない（代替手段で実現できている）
- ルーティングの複雑性が増している

#### 推奨される改善案

##### 案1: 未使用のネストルートを削除

```ruby
resources :managers
# ネストを削除
```

##### 案2: ネストされたルートを実装

```ruby
# TeamsController
def index
  if params[:manager_id].present?
    @teams = Manager.find(params[:manager_id]).teams
  else
    @teams = Team.all
  end
  render json: @teams
end
```

- `GET /api/v1/managers/:manager_id/teams` で特定監督のチーム一覧を取得
- フロントエンドで必要に応じて使用

---

### 5. バリデーションメッセージの国際化未対応

#### 問題

```ruby
# TeamManager モデル
validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: 'には既に監督が設定されています' }
```

- バリデーションメッセージが日本語ハードコーディング
- 多言語対応が困難

#### 影響範囲

- フロントエンドでエラーメッセージを表示する際、日本語固定
- 国際化（i18n）が不完全

#### 推奨される改善案

```ruby
# config/locales/ja.yml
ja:
  activerecord:
    errors:
      models:
        team_manager:
          attributes:
            team_id:
              already_has_director: "には既に監督が設定されています"
            manager_id:
              cannot_be_assigned_to_multiple_teams: "は同一リーグ内の複数のチームに兼任することはできません"
```

```ruby
# TeamManager モデル
validates :team_id, uniqueness: { scope: :role, if: -> { director? } }
# メッセージはロケールファイルから自動取得

errors.add(:manager_id, :cannot_be_assigned_to_multiple_teams)
# シンボルで指定し、ロケールファイルから解決
```

---

### 6. フロントエンドでの role 表示・編集機能の未実装

#### 問題

- TypeScript の `Manager` 型定義に `role: 'director' | 'coach'` が含まれているが、フロントエンドで表示・編集していない
- バックエンドの ManagerSerializer でも `role` を出力していない

#### 影響範囲

- 監督の役割（director/coach）をフロントエンドで確認・変更できない
- `team_managers.role` のみで管理されているため、監督全体の役割が不明

#### 推奨される改善案

##### 案1: managers.role を削除（データモデルから除外）

- TypeScript の型定義から `role` を削除
- `team_managers.role` のみで管理する設計に統一

##### 案2: role の表示・編集機能を実装

1. ManagerSerializer に `role` を追加
   ```ruby
   attributes :id, :name, :short_name, :irc_name, :user_id, :role
   ```

2. ManagerDialog にロール選択フィールドを追加
   ```vue
   <v-select
     v-model="editedManager.role"
     :items="[{ value: 'director', text: '監督' }, { value: 'coach', text: 'コーチ' }]"
     :label="t('managerDialog.form.role')"
   ></v-select>
   ```

3. ManagersController の `manager_params` に `role` を追加
   ```ruby
   params.require(:manager).permit(:name, :short_name, :irc_name, :user_id, :role)
   ```

---

### ~~7. 監督一覧のページネーション未実装~~ （実装済み）

サーバーサイドページネーションが実装された。バックエンドは `limit`/`offset` ベースのページネーション（gem不使用）、フロントエンドは `v-data-table` のサーバーサイドページネーション機能を使用。詳細は「GET /api/v1/managers」セクションおよび「fetchManagers」メソッドを参照。

---

## 参考情報

### 関連ドキュメント

- **01_authentication.md**: 認証機能の仕様（`before_action :authenticate_user!` の詳細）
- **03_team_management.md**: チーム管理機能の仕様（`teams.manager_id` の管理、TeamDialog の詳細）
- **12_commissioner.md**: コミッショナー機能の仕様（リーグ管理、`team_managers` の高度な使用例）
- **00_project_overview.md**: プロジェクト全体の概要、技術スタック、ディレクトリ構成

### 参考コード

- **ApplicationController**: 認証ロジック、CSRF保護の実装
- **TeamSerializer**: チームのJSON出力形式（`manager_id` を含む）
- **useSnackbar.ts**: スナックバー通知の実装詳細
- **ConfirmDialog.vue**: 確認ダイアログの実装詳細

### データベーススキーマ

```bash
# スキーマ確認
cat db/schema.rb | grep -A 10 "create_table \"managers\""
cat db/schema.rb | grep -A 10 "create_table \"team_managers\""
cat db/schema.rb | grep -A 10 "create_table \"teams\""
```

### テスト実行

```bash
# バックエンドテスト
rails test test/controllers/api/v1/managers_controller_test.rb
rails test test/models/manager_test.rb
rails test test/models/team_manager_test.rb

# フロントエンドテスト
npm run test:unit -- ManagerList.spec.ts
npm run test:unit -- ManagerDialog.spec.ts
```

### API 動作確認

```bash
# 監督一覧取得
curl -X GET http://localhost:3000/api/v1/managers \
  -H "Authorization: Bearer {token}"

# 監督作成
curl -X POST http://localhost:3000/api/v1/managers \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"manager":{"name":"テスト監督","short_name":"テスト","irc_name":"test"}}'

# 監督削除
curl -X DELETE http://localhost:3000/api/v1/managers/1 \
  -H "Authorization: Bearer {token}"
```

---

## 改訂履歴

| 日付 | 版 | 内容 | 作成者 |
|------|-----|------|--------|
| 2026-02-14 | 1.0 | 初版作成。ソースコードに基づき全面書き直し | 足軽2号 |
| 2026-02-21 | 1.1 | ページネーション対応、BaseController継承、teams.manager_id削除を反映 | - |

---

**以上**
