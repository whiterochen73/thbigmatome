# マスタデータ管理

## 1. 概要

本システムでは、選手の属性を構成する6種類のマスタデータを管理する。対象5種（打撃スタイル、打撃スキル、投球スタイル、投球スキル、選手タイプ）はYAML設定ファイルで管理されており、Settings画面およびAPIは**読み取り専用**となっている。バイオリズムのみDB管理のまま維持され、Settings画面からCRUD操作が可能。選手データとは直接参照または中間テーブルを介した多対多で関連付けられる。

### 1.1 マスタデータ一覧

| # | マスタデータ | 用途 | 選手との関連 |
|---|------------|------|-------------|
| 1 | 打撃スタイル（BattingStyle） | 選手の打撃フォーム分類 | 選手が1つ選択（belongs_to） |
| 2 | 打撃スキル（BattingSkill） | 選手の打撃特殊能力 | 選手が複数保持（多対多） |
| 3 | 投球スタイル（PitchingStyle） | 選手の投球フォーム分類 | 選手が最大3つ選択（belongs_to × 3） |
| 4 | 投球スキル（PitchingSkill） | 選手の投球特殊能力 | 選手が複数保持（多対多） |
| 5 | 選手タイプ（PlayerType） | 選手の役割分類 | 選手が複数保持（多対多） |
| 6 | バイオリズム（Biorhythm） | 選手の調子変動期間 | 選手が複数保持（多対多） |

### 1.2 ER図（マスタデータ関連）

```
BattingStyle ──1:N── Player（batting_style_id）
PitchingStyle ──1:N── Player（pitching_style_id）
PitchingStyle ──1:N── Player（pinch_pitching_style_id）
PitchingStyle ──1:N── Player（catcher_pitching_style_id）

BattingSkill ──M:N── Player（via player_batting_skills）
PitchingSkill ──M:N── Player（via player_pitching_skills）
PlayerType ──M:N── Player（via player_player_types）
Biorhythm ──M:N── Player（via player_biorhythms）
```

スタイル系（BattingStyle, PitchingStyle）はPlayerから直接参照（`belongs_to`）、スキル系・タイプ・バイオリズムは中間テーブル経由の多対多関連。PitchingStyleは1つのマスタデータに対し、Player側に3つの外部キー（通常投球・代打時投球・捕手時投球）がある。

### 1.3 構造パターンによる分類

| パターン | マスタデータ | データ構造 |
|---------|-------------|----------|
| name + description | PlayerType, BattingStyle, PitchingStyle | 基本的な名前と説明のペア |
| name + description + skill_type | BattingSkill, PitchingSkill | スキル分類（positive/negative/neutral）を含む |
| name + start_date + end_date | Biorhythm | 期間情報を持つ（descriptionなし） |

---

## 2. 画面構成（フロントエンド）

### 2.1 Settings画面

- **パス**: `/settings`
- **コンポーネント**: `src/views/Settings.vue`

#### 2.1.1 タブ構成

Settings画面は2つのタブで構成される。マスタデータ管理は「選手」タブに配置されている。

| タブ | v-tab value | 内容 |
|------|------------|------|
| 選手（Player） | `player` | 打撃/投球スタイル、打撃/投球スキル、選手タイプ、バイオリズム |
| 編成（Squad） | `squad` | コスト設定、日程設定（本仕様書の範囲外） |

デフォルトで「選手」タブが選択される（`selectedTab = ref('player')`）。

#### 2.1.2 「選手」タブのレイアウト

2カラム構成（`md="8" lg="6"` の `v-col` × 2）で、6つのマスタデータ管理コンポーネントを配置する。

```
+-------------------------------+-------------------------------+
| PitchingStyleSettings         | BattingStyleSettings          |
|   投球スタイル                |   打撃スタイル                |
+-------------------------------+-------------------------------+
| PitchingSkillSettings         | BattingSkillSettings          |
|   投球スキル                  |   打撃スキル                  |
+-------------------------------+-------------------------------+
| PlayerTypeSettings            | BiorhythmSettings             |
|   選手タイプ                  |   バイオリズム                |
+-------------------------------+-------------------------------+
```

各コンポーネント間は `mt-6` のスペーサーで区切られる。

#### 2.1.3 Settings.vue のインポート構成

```typescript
import PitchingStyleSettings from '@/components/settings/PitchingStyleSettings.vue'
import PitchingSkillSettings from '@/components/settings/PitchingSkillSettings.vue'
import BattingStyleSettings from '@/components/settings/BattingStyleSettings.vue'
import BattingSkillSettings from '@/components/settings/BattingSkillSettings.vue'
import PlayerTypeSettings from '@/components/settings/PlayerTypeSettings.vue'
import BiorhythmSettings from '@/components/settings/BiorhythmSettings.vue'
import CostSettings from '@/components/settings/CostSettings.vue'
import ScheduleSettings from '@/components/settings/ScheduleSettings.vue'
```

### 2.2 共通コンポーネント: GenericMasterSettings

**ファイル**: `src/components/settings/GenericMasterSettings.vue`

6種類のマスタデータ管理UIの共通基盤となるジェネリックコンポーネント。TypeScriptのジェネリクスを使用し、`T extends { id: number; name: string; description?: string | null }` の型制約を持つ。

#### 2.2.1 Props

| Prop | 型 | デフォルト | 説明 |
|------|-----|----------|------|
| `title` | `string` | - | 展開パネルのタイトル |
| `endpoint` | `string` | - | APIエンドポイントパス（例: `/batting-skills`） |
| `i18nKey` | `string` | - | i18n翻訳キーのプレフィックス |
| `dialogComponent` | `Component` | - | 編集/追加用ダイアログコンポーネント |
| `additionalHeaders` | `any[]` | - | テーブルに追加するカラムヘッダー |
| `hasDescriptionColumn` | `boolean` | `true` | 説明カラムの表示有無 |
| `descriptionMaxWidth` | `string` | `'250px'` | 説明カラムの最大幅 |
| `readonly` | `boolean` | `false` | 読み取り専用モード。`true` の場合、追加/編集/削除ボタンとアクションカラムを非表示にし、案内メッセージ（v-alert）を表示 |

#### 2.2.2 UI構造

1. **展開パネル（v-expansion-panels）**: 折りたたみ可能なパネル。タイトル横に「追加」ボタンを配置（`readonly=false` の場合のみ）
2. **案内メッセージ（v-alert）**: `readonly=true` の場合、「この設定は設定ファイルで管理されているため、ここでは閲覧のみ可能です。」を表示
3. **データテーブル（v-data-table）**: `density="compact"` でアイテム一覧を表示。`readonly=false` の場合のみ各行に編集（mdi-pencil）・削除（mdi-delete）アイコンとアクションカラムを配置
4. **ダイアログ**: Props で渡されたダイアログコンポーネントを `v-model` で制御
5. **確認ダイアログ（ConfirmDialog）**: 削除時の確認用

#### 2.2.3 データフロー

1. `onMounted` で `GET {endpoint}` を実行し、アイテム一覧を取得
2. 追加: `openNewDialog()` → `editingItem = null` でダイアログを表示 → ダイアログ内で `POST {endpoint}` → `save` イベントで一覧再読込
3. 編集: `openEditDialog(item)` → `editingItem = { ...item }` でダイアログを表示 → ダイアログ内で `PUT {endpoint}/{id}` → `save` イベントで一覧再読込
4. 削除: `confirmDelete(item)` → ConfirmDialog で確認 → `DELETE {endpoint}/{id}` → 一覧再読込

#### 2.2.4 テーブルヘッダー構成

テーブルカラムは以下の順序で動的に構築される:

1. `name`（常に表示）
2. `additionalHeaders`（Props指定時のみ）
3. `description`（`hasDescriptionColumn` が true の場合）
4. `actions`（`readonly=false` の場合のみ表示、右寄せ）

#### 2.2.5 スロット

| スロット名 | 用途 |
|-----------|------|
| `item.description` | 説明カラムのカスタムレンダリング（デフォルト: ツールチップ付き省略表示） |
| `item.name` | 名前カラムのカスタムレンダリング（スキル系で色付きチップ表示に使用） |
| `item.{key}` | 任意のカラムのカスタムレンダリング（バイオリズムの日付表示に使用） |

### 2.3 個別設定コンポーネント

各マスタデータは `GenericMasterSettings` をラップした薄いコンポーネントとして実装されている。

#### 2.3.1 PitchingStyleSettings

- **ファイル**: `src/components/settings/PitchingStyleSettings.vue`
- **endpoint**: `/pitching-styles`
- **ダイアログ**: `PitchingStyleDialog`
- **descriptionMaxWidth**: `500px`
- **readonly**: `true`（読み取り専用）
- カスタマイズなし（GenericMasterSettingsの標準動作）

#### 2.3.2 BattingStyleSettings

- **ファイル**: `src/components/settings/BattingStyleSettings.vue`
- **endpoint**: `/batting-styles`
- **ダイアログ**: `BattingStyleDialog`
- **descriptionMaxWidth**: `500px`
- **readonly**: `true`（読み取り専用）
- カスタマイズなし

#### 2.3.3 PitchingSkillSettings

- **ファイル**: `src/components/settings/PitchingSkillSettings.vue`
- **endpoint**: `/pitching-skills`
- **ダイアログ**: `PitchingSkillDialog`
- **descriptionMaxWidth**: `400px`
- **readonly**: `true`（読み取り専用）
- **カスタマイズ**: `item.name` スロットで `skill_type` に応じた色付き `v-chip` を表示
  - `positive` → 青（`blue`）
  - `negative` → 赤（`red`）
  - `neutral` → 緑（`green`）
- **SkillType**: `@/types/skill` からインポート

#### 2.3.4 BattingSkillSettings

- **ファイル**: `src/components/settings/BattingSkillSettings.vue`
- **endpoint**: `/batting-skills`
- **ダイアログ**: `BattingSkillDialog`
- **descriptionMaxWidth**: `400px`
- **readonly**: `true`（読み取り専用）
- **カスタマイズ**: PitchingSkillSettingsと同一のスキルタイプ色付きチップ表示
- **SkillType**: `@/types/skill` からインポート

#### 2.3.5 PlayerTypeSettings

- **ファイル**: `src/components/settings/PlayerTypeSettings.vue`
- **endpoint**: `/player-types`
- **ダイアログ**: `PlayerTypeDialog`
- **descriptionMaxWidth**: `500px`
- **readonly**: `true`（読み取り専用）
- カスタマイズなし

#### 2.3.6 BiorhythmSettings

- **ファイル**: `src/components/settings/BiorhythmSettings.vue`
- **endpoint**: `/biorhythms`
- **ダイアログ**: `BiorhythmDialog`
- **hasDescriptionColumn**: `false`（説明カラムなし）
- **additionalHeaders**: `start_date`（開始日）、`end_date`（終了日）カラムを追加
- **カスタマイズ**: `item.start_date` / `item.end_date` スロットで日付を `MM/DD` 形式にフォーマット（`dateString.substring(5).replace('-', '/')`）

### 2.4 ダイアログコンポーネント

全ダイアログは共通のパターンで実装されている: `v-dialog`（persistent, max-width 500px）、v-model制御、保存/キャンセルボタン、バリデーション、axiosによるAPI呼び出し、snackbarによる成功/エラー通知。

#### 2.4.1 スタイル系ダイアログ（PitchingStyleDialog / BattingStyleDialog）

| フィールド | コンポーネント | バリデーション |
|-----------|--------------|--------------|
| name | `v-text-field` | required |
| description | `v-textarea`（3行） | なし |

- **保存時ペイロード**: `{ pitching_style: { name, description } }` / `{ batting_style: { name, description } }`
- **フォーム有効条件**: `name` が空でないこと

#### 2.4.2 スキル系ダイアログ（PitchingSkillDialog / BattingSkillDialog）

| フィールド | コンポーネント | バリデーション |
|-----------|--------------|--------------|
| name | `v-text-field` | required |
| skill_type | `v-select`（positive/negative/neutral） | required |
| description | `v-textarea`（3行） | なし |

- **skill_type選択肢**: positive（青背景 `blue-lighten-5`）、negative（赤背景 `red-lighten-5`）、neutral（緑背景 `green-lighten-5`）
- **保存時ペイロード**: `{ batting_skill: { name, skill_type, description } }` / `{ pitching_skill: { name, skill_type, description } }`
- **フォーム有効条件**: `name` と `skill_type` の両方が空でないこと
- **デフォルト値**: 新規作成時のskill_typeは `'neutral'`

#### 2.4.3 PlayerTypeDialog

| フィールド | コンポーネント | バリデーション |
|-----------|--------------|--------------|
| name | `v-text-field`（autofocus） | required |
| description | `v-textarea`（3行） | なし |

- **保存時ペイロード**: `{ player_type: { name, description } }`
- **フォーム有効条件**: `name` が空でないこと

#### 2.4.4 BiorhythmDialog

| フィールド | コンポーネント | バリデーション |
|-----------|--------------|--------------|
| name | `v-text-field` | required |
| start_date | `v-text-field`（placeholder: YYYY-MM-DD） | required, 日付形式（`/^\d{4}-\d{2}-\d{2}$/`） |
| end_date | `v-text-field`（placeholder: YYYY-MM-DD） | required, 日付形式 |

- **保存時ペイロード**: `{ biorhythm: { name, start_date, end_date } }`
- **フォーム有効条件**: `name` が空でなく、`start_date` と `end_date` が日付形式に合致すること
- start_date / end_date は2カラム横並び（`cols="6"` × 2）

### 2.5 ダイアログ共通パターン

全ダイアログコンポーネントは以下の共通パターンで実装されている:

1. **v-model連携**: `modelValue` prop + `update:modelValue` emit による親コンポーネントとの双方向バインディング
2. **編集/新規判定**: `props.item` が `null` なら新規作成、オブジェクトなら編集
3. **watch によるフォーム初期化**: `props.item` の変更を監視し、`editableItem` を初期化
4. **Payload型**: `Omit<T, 'id'>` で `id` を除外した型をAPIリクエスト用に定義
5. **API呼び出し**: 編集時は `PUT /{endpoint}/{id}`、新規時は `POST /{endpoint}`
6. **エラーハンドリング**: `isAxiosError` でAxiosエラーを判定し、レスポンスの `errors` 配列があれば結合して表示、なければ汎用エラーメッセージ
7. **通知**: `useSnackbar` コンポーザブルで成功/エラーメッセージを表示
8. **国際化**: 全ラベル・メッセージは `vue-i18n` の `t()` 関数で国際化対応

### 2.6 コンポーネント構成図

```
Settings.vue
├── [タブ: player]
│   ├── PitchingStyleSettings.vue
│   │   └── GenericMasterSettings.vue
│   │       ├── PitchingStyleDialog.vue
│   │       └── ConfirmDialog.vue
│   ├── PitchingSkillSettings.vue
│   │   └── GenericMasterSettings.vue
│   │       ├── PitchingSkillDialog.vue
│   │       └── ConfirmDialog.vue
│   ├── PlayerTypeSettings.vue
│   │   └── GenericMasterSettings.vue
│   │       ├── PlayerTypeDialog.vue
│   │       └── ConfirmDialog.vue
│   ├── BattingStyleSettings.vue
│   │   └── GenericMasterSettings.vue
│   │       ├── BattingStyleDialog.vue
│   │       └── ConfirmDialog.vue
│   ├── BattingSkillSettings.vue
│   │   └── GenericMasterSettings.vue
│   │       ├── BattingSkillDialog.vue
│   │       └── ConfirmDialog.vue
│   └── BiorhythmSettings.vue
│       └── GenericMasterSettings.vue
│           ├── BiorhythmDialog.vue
│           └── ConfirmDialog.vue
└── [タブ: squad]
    ├── CostSettings.vue（本仕様書の範囲外）
    └── ScheduleSettings.vue（本仕様書の範囲外）
```

---

## 3. APIエンドポイント

### 3.1 共通事項

- **ベースURL**: `/api/v1`
- **コントローラー継承**: 6種類とも `Api::V1::*Controller < Api::V1::BaseController` を継承
- **認証**: `Api::V1::BaseController` で `before_action :authenticate_user!` が設定されており、全エンドポイントで認証必須
- **レスポンス形式**: `to_json` による直接シリアライズ（専用シリアライザーなし）。`created_at`, `updated_at` もレスポンスに含まれる
- **エラーレスポンス**: バイオリズムのみ `{ errors: ["エラーメッセージ1", ...] }`（422 Unprocessable Entity）。YAML管理対象5種は `{ error: "..." }`（403 Forbidden）
- **ソート**: 全indexアクションで `order(:id)` を適用（Biorhythmのみ `order(:start_date, :name)`）
- **アクション**: 全マスタデータとも `index`, `create`, `update`, `destroy` の4アクション。`show` アクションはなし
- **YAML管理対象の書き込み制限**: 打撃スタイル、打撃スキル、投球スタイル、投球スキル、選手タイプの5種は、`create`/`update`/`destroy` アクションが `403 Forbidden` を返す（`I18n.t("master_data.managed_by_config_file")`）。`index`（読み取り）のみ許可

### 3.2 打撃スキル（BattingSkill）

#### GET /api/v1/batting-skills

全打撃スキルの一覧を取得する。

```
GET /api/v1/batting-skills
```

**レスポンス（200 OK）**:
```json
[
  {
    "id": 1,
    "name": "パワーヒッター",
    "description": "長打力が高い",
    "skill_type": "positive",
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
]
```

#### POST /api/v1/batting-skills（無効化）

YAML設定ファイル管理のため、書き込みは禁止。

- **レスポンス**: 403 Forbidden `{ "error": "(master_data.managed_by_config_fileの翻訳メッセージ)" }`

#### PATCH/PUT /api/v1/batting-skills/:id（無効化）

- **レスポンス**: 403 Forbidden

#### DELETE /api/v1/batting-skills/:id（無効化）

- **レスポンス**: 403 Forbidden

---

### 3.3 打撃スタイル（BattingStyle）

#### GET /api/v1/batting-styles

```
GET /api/v1/batting-styles
```

**レスポンス（200 OK）**:
```json
[
  {
    "id": 1,
    "name": "アッパースイング",
    "description": "打球が上がりやすい",
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
]
```

#### POST /api/v1/batting-styles（無効化）

YAML設定ファイル管理のため、書き込みは禁止。

- **レスポンス**: 403 Forbidden

#### PATCH/PUT /api/v1/batting-styles/:id（無効化）

- **レスポンス**: 403 Forbidden

#### DELETE /api/v1/batting-styles/:id（無効化）

- **レスポンス**: 403 Forbidden

---

### 3.4 投球スキル（PitchingSkill）

#### GET /api/v1/pitching-skills

```
GET /api/v1/pitching-skills
```

**レスポンス**: BattingSkillと同一構造（`id`, `name`, `description`, `skill_type`, `created_at`, `updated_at`）

#### POST /api/v1/pitching-skills（無効化）

YAML設定ファイル管理のため、書き込みは禁止。

- **レスポンス**: 403 Forbidden

#### PATCH/PUT /api/v1/pitching-skills/:id（無効化）

- **レスポンス**: 403 Forbidden

#### DELETE /api/v1/pitching-skills/:id（無効化）

- **レスポンス**: 403 Forbidden

---

### 3.5 投球スタイル（PitchingStyle）

#### GET /api/v1/pitching-styles

```
GET /api/v1/pitching-styles
```

**レスポンス**: BattingStyleと同一構造（`id`, `name`, `description`, `created_at`, `updated_at`）

#### POST /api/v1/pitching-styles（無効化）

YAML設定ファイル管理のため、書き込みは禁止。

- **レスポンス**: 403 Forbidden

#### PATCH/PUT /api/v1/pitching-styles/:id（無効化）

- **レスポンス**: 403 Forbidden

#### DELETE /api/v1/pitching-styles/:id（無効化）

- **レスポンス**: 403 Forbidden

---

### 3.6 選手タイプ（PlayerType）

#### GET /api/v1/player-types

```
GET /api/v1/player-types
```

**レスポンス（200 OK）**:
```json
[
  {
    "id": 1,
    "name": "サブマリン",
    "description": "アンダースロー投手",
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
]
```

#### POST /api/v1/player-types（無効化）

YAML設定ファイル管理のため、書き込みは禁止。

- **レスポンス**: 403 Forbidden

#### PATCH/PUT /api/v1/player-types/:id（無効化）

- **レスポンス**: 403 Forbidden

#### DELETE /api/v1/player-types/:id（無効化）

- **レスポンス**: 403 Forbidden

---

### 3.7 バイオリズム（Biorhythm）

#### GET /api/v1/biorhythms

```
GET /api/v1/biorhythms
```

**レスポンス（200 OK）**:
```json
[
  {
    "id": 1,
    "name": "絶好調期",
    "start_date": "2025-04-01",
    "end_date": "2025-06-30",
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  }
]
```

- **ソート順**: `start_date` 昇順 → `name` 昇順（他のマスタデータは `id` 昇順）

#### POST /api/v1/biorhythms

**リクエストボディ**:
```json
{
  "biorhythm": {
    "name": "絶好調期",
    "start_date": "2025-04-01",
    "end_date": "2025-06-30"
  }
}
```

- **Strong Parameters**: `name`, `start_date`, `end_date`
- **成功**: 201 Created
- **失敗**: 422 Unprocessable Entity

#### PATCH/PUT /api/v1/biorhythms/:id

- **成功**: 200 OK
- **失敗**: 422 Unprocessable Entity

#### DELETE /api/v1/biorhythms/:id

- **成功**: 204 No Content
- **制約**: `dependent: :restrict_with_error` により、選手に紐づいている場合は削除不可

---

### 3.8 ルーティング定義（config/routes.rb）

```ruby
# 各種設定マスタ
resources :player_types, path: 'player-types', only: [:index, :create, :update, :destroy]
resources :pitching_styles, path: 'pitching-styles', only: [:index, :create, :update, :destroy]
resources :pitching_skills, path: 'pitching-skills', only: [:index, :create, :update, :destroy]
resources :batting_styles, path: 'batting-styles', only: [:index, :create, :update, :destroy]
resources :batting_skills, path: 'batting-skills', only: [:index, :create, :update, :destroy]
resources :biorhythms, only: [:index, :create, :update, :destroy]
```

URLパスはケバブケース（`player-types`, `batting-skills` 等）。`biorhythms` のみアンダースコアなしの単語のためパス変換なし。

### 3.9 コントローラ構造

すべてのコントローラは `Api::V1::BaseController` を継承する。YAML管理対象5種とバイオリズムで構造が異なる。

#### 3.9.1 YAML管理対象コントローラ（読み取り専用）

打撃スタイル、打撃スキル、投球スタイル、投球スキル、選手タイプの5種:

```ruby
module Api
  module V1
    class {Resource}Controller < Api::V1::BaseController
      def index    # GET    全件取得（ソート済み、to_jsonで直接レンダリング）
      def create   # POST   403 Forbidden（設定ファイル管理のため）
      def update   # PATCH  403 Forbidden
      def destroy  # DELETE 403 Forbidden
    end
  end
end
```

- `set_*` や `*_params` プライベートメソッドは不要のため削除済み
- `create`/`update`/`destroy` は `render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden` を返す

#### 3.9.2 バイオリズムコントローラ（CRUD有効）

```ruby
module Api
  module V1
    class BiorhythmsController < Api::V1::BaseController
      before_action :set_biorhythm, only: [:update, :destroy]

      def index    # GET    全件取得（start_date, name順）
      def create   # POST   新規作成（成功: 201、失敗: 422）
      def update   # PATCH  更新（成功: 200、失敗: 422）
      def destroy  # DELETE 削除（成功: 204 No Content）

      private
      def set_biorhythm         # params[:id]でレコード検索（find）
      def biorhythm_params      # Strong Parameters: name, start_date, end_date
    end
  end
end
```

#### 3.9.3 コントローラ別Strong Parameters一覧

| コントローラ | 許可パラメータ | 状態 |
|------------|--------------|------|
| BattingSkillsController | - | 読み取り専用（403） |
| BattingStylesController | - | 読み取り専用（403） |
| PitchingSkillsController | - | 読み取り専用（403） |
| PitchingStylesController | - | 読み取り専用（403） |
| PlayerTypesController | - | 読み取り専用（403） |
| BiorhythmsController | `name`, `start_date`, `end_date` | CRUD有効 |

---

## 4. データモデル

### 4.1 batting_skills テーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | ID |
| name | string | NOT NULL, UNIQUE INDEX | スキル名 |
| description | text | - | 説明 |
| skill_type | string | NOT NULL, default: `"neutral"` | スキル分類（positive/negative/neutral） |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `index_batting_skills_on_name`（UNIQUE）

### 4.2 batting_styles テーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | ID |
| name | string | - | スタイル名 |
| description | string | - | 説明 |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**備考**: DB定義では `name` に NOT NULL 制約なし。モデルバリデーション（`validates :name, presence: true, uniqueness: true`）でのみ制約。`description` の型は `text` ではなく `string`。UNIQUEインデックスもDB上にはなく、モデルの `uniqueness` バリデーションのみ。

### 4.3 pitching_skills テーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | ID |
| name | string | - | スキル名 |
| description | text | - | 説明 |
| skill_type | string | - | スキル分類（positive/negative/neutral） |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `index_pitching_skills_on_name`（UNIQUE）

**備考**: `batting_skills` と異なり、`name` と `skill_type` にDB上の NOT NULL 制約がない。モデルバリデーション（`validates :name, presence: true, uniqueness: true` / `validates :skill_type, presence: true`）でのみ制約。また `skill_type` のDB上のデフォルト値もない。

### 4.4 pitching_styles テーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | ID |
| name | string | - | スタイル名 |
| description | string | - | 説明 |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**備考**: `batting_styles` と同一構造。DB上の制約はタイムスタンプの NOT NULL のみ。UNIQUEインデックスなし。

### 4.5 player_types テーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | ID |
| name | string | NOT NULL | タイプ名 |
| description | text | - | 説明 |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `index_player_types_on_name`（UNIQUE）

### 4.6 biorhythms テーブル

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY, 自動採番 | ID |
| name | string | NOT NULL | バイオリズム名 |
| start_date | date | NOT NULL | 開始日 |
| end_date | date | NOT NULL | 終了日 |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `index_biorhythms_on_name`（UNIQUE）

### 4.7 中間テーブル

#### 4.7.1 player_batting_skills

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY | ID |
| player_id | bigint | NOT NULL, FK(players) | 選手ID |
| batting_skill_id | bigint | NOT NULL, FK(batting_skills) | 打撃スキルID |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `(player_id, batting_skill_id)` UNIQUE — 同一選手に同じスキルの重複登録を防止

**モデルバリデーション**: `validates :batting_skill_id, uniqueness: { scope: :player_id }`

#### 4.7.2 player_pitching_skills

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY | ID |
| player_id | bigint | NOT NULL, FK(players) | 選手ID |
| pitching_skill_id | bigint | NOT NULL, FK(pitching_skills) | 投球スキルID |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `(player_id, pitching_skill_id)` UNIQUE

**モデルバリデーション**: `validates :pitching_skill_id, uniqueness: { scope: :player_id }`

#### 4.7.3 player_player_types

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY | ID |
| player_id | bigint | NOT NULL, FK(players) | 選手ID |
| player_type_id | bigint | NOT NULL, FK(player_types) | 選手タイプID |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `(player_id, player_type_id)` UNIQUE

**モデルバリデーション**: `validates :player_type_id, uniqueness: { scope: :player_id }`

#### 4.7.4 player_biorhythms

| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | bigint | PRIMARY KEY | ID |
| player_id | bigint | NOT NULL, FK(players) | 選手ID |
| biorhythm_id | bigint | NOT NULL, FK(biorhythms) | バイオリズムID |
| created_at | datetime | NOT NULL | 作成日時 |
| updated_at | datetime | NOT NULL | 更新日時 |

**インデックス**: `(player_id, biorhythm_id)` UNIQUE

**モデルバリデーション**: `validates :biorhythm_id, uniqueness: { scope: :player_id }`

### 4.8 players テーブルとの外部キー関連

`players` テーブルは以下の外部キーでマスタデータを直接参照する:

| カラム | 参照先 | 関係 | Player側の定義 |
|--------|-------|------|---------------|
| `batting_style_id` | `batting_styles(id)` | 打撃スタイル | `belongs_to :batting_style, optional: true` |
| `pitching_style_id` | `pitching_styles(id)` | 投球スタイル | `belongs_to :pitching_style, optional: true` |
| `pinch_pitching_style_id` | `pitching_styles(id)` | 代打時投球スタイル | `belongs_to :pinch_pitching_style, class_name: 'PitchingStyle', optional: true` |
| `catcher_pitching_style_id` | `pitching_styles(id)` | 捕手時投球スタイル | `belongs_to :catcher_pitching_style, class_name: 'PitchingStyle', optional: true` |

全て `optional: true` であり、未設定（`NULL`）が許容される。

### 4.9 DB制約とモデルバリデーションの不整合

6種類のマスタデータテーブル間で、DB制約とモデルバリデーションの対応にばらつきがある:

| テーブル | name NOT NULL（DB） | name UNIQUE INDEX（DB） | name presence（Model） | name uniqueness（Model） |
|---------|:---:|:---:|:---:|:---:|
| batting_skills | YES | YES | YES | YES |
| batting_styles | NO | NO | YES | YES |
| pitching_skills | NO | YES | YES | YES |
| pitching_styles | NO | NO | YES | YES |
| player_types | YES | YES | YES | YES |
| biorhythms | YES | YES | YES | YES |

`batting_styles` と `pitching_styles` はDB上の制約が最も緩く、モデルバリデーションに依存している。

---

## 5. ビジネスロジック

### 5.1 スキルタイプ分類（skill_type）

`BattingSkill` と `PitchingSkill` は `skill_type` 属性を持ち、ActiveRecord enum で管理される:

```ruby
enum :skill_type, { positive: 'positive', negative: 'negative', neutral: 'neutral' }
```

| 値 | 意味 | フロントエンド表示色 |
|----|------|-------------------|
| `positive` | 有利なスキル | 青（`blue`） |
| `negative` | 不利なスキル | 赤（`red`） |
| `neutral` | 中立的なスキル | 緑（`green`） |

DBには文字列値（`'positive'`, `'negative'`, `'neutral'`）として保存される。デフォルト値は `batting_skills` テーブルでのみ `"neutral"` が設定されている（`pitching_skills` はDBデフォルトなし、ただしフロントエンドのダイアログで新規作成時のデフォルト値として `'neutral'` を使用）。

### 5.2 削除制約

マスタデータの削除は、選手との関連状態によって以下のように制約される:

| マスタデータ | 削除制約の種類 | 選手紐づき時の動作 |
|------------|--------------|------------------|
| BattingSkill | `dependent: :restrict_with_error` | Railsレベルで削除拒否（エラーメッセージ返却） |
| PitchingSkill | 外部キー制約のみ | DB側で外部キー制約違反エラー |
| PlayerType | `dependent: :restrict_with_error` | Railsレベルで削除拒否（エラーメッセージ返却） |
| Biorhythm | `dependent: :restrict_with_error` | Railsレベルで削除拒否（エラーメッセージ返却） |
| BattingStyle | 外部キー制約（players.batting_style_id） | DB側で外部キー制約違反エラー |
| PitchingStyle | 外部キー制約（players.pitching_style_id 等3カラム） | DB側で外部キー制約違反エラー |

**備考**: `BattingSkill`, `PlayerType`, `Biorhythm` は `has_many :players, through:` と `dependent: :restrict_with_error` により、Railsレベルで削除を制限する。`BattingStyle`, `PitchingStyle` はPlayerモデル側で `belongs_to` として直接参照されており、外部キー制約でDB側が削除を拒否する。`PitchingSkill` はモデルに `has_many` 定義がないが、`player_pitching_skills` テーブルの外部キー制約がDB側で機能する。

### 5.3 バリデーション一覧

#### 5.3.1 マスタデータモデル

| モデル | フィールド | バリデーション |
|--------|----------|--------------|
| BattingSkill | name | presence, uniqueness |
| BattingSkill | skill_type | presence, inclusion（positive/negative/neutral） |
| BattingStyle | name | presence, uniqueness |
| PitchingSkill | name | presence, uniqueness |
| PitchingSkill | skill_type | presence, inclusion（positive/negative/neutral） |
| PitchingStyle | name | presence, uniqueness |
| PlayerType | name | presence, uniqueness |
| Biorhythm | name | presence, uniqueness |
| Biorhythm | start_date | presence |
| Biorhythm | end_date | presence |

全モデルで `name` の一意性バリデーションが適用されており、同名マスタデータの重複登録は不可。

#### 5.3.2 中間テーブル

| モデル | フィールド | バリデーション |
|--------|----------|--------------|
| PlayerBattingSkill | batting_skill_id | uniqueness（scope: player_id） |
| PlayerPitchingSkill | pitching_skill_id | uniqueness（scope: player_id） |
| PlayerPlayerType | player_type_id | uniqueness（scope: player_id） |
| PlayerBiorhythm | biorhythm_id | uniqueness（scope: player_id） |

同一選手への同一マスタデータの重複紐づけはバリデーションとDB UNIQUEインデックスの双方で防止される。

### 5.4 マスタデータ参照先の連携

#### 5.4.1 Playerモデルのマスタデータ関連定義

```ruby
# 直接参照（belongs_to）
belongs_to :batting_style, optional: true
belongs_to :pitching_style, optional: true
belongs_to :pinch_pitching_style, class_name: 'PitchingStyle', optional: true
belongs_to :catcher_pitching_style, class_name: 'PitchingStyle', optional: true

# 多対多（has_many through）
has_many :player_batting_skills, dependent: :destroy
has_many :batting_skills, through: :player_batting_skills
has_many :player_pitching_skills, dependent: :destroy
has_many :pitching_skills, through: :player_pitching_skills
has_many :player_player_types, dependent: :destroy
has_many :player_types, through: :player_player_types
has_many :player_biorhythms, dependent: :destroy
has_many :biorhythms, through: :player_biorhythms
```

#### 5.4.2 Playerモデルのマスタデータ関連ヘルパーメソッド

`Player` モデルには、各マスタデータの紐づけIDを取得するヘルパーメソッドが定義されている:

```ruby
def batting_skill_ids    # player_batting_skills.map(&:batting_skill_id)
def pitching_skill_ids   # player_pitching_skills.map(&:pitching_skill_id)
def player_type_ids      # player_player_types.map(&:player_type_id)
def biorhythm_ids        # player_biorhythms.map(&:biorhythm_id)
```

#### 5.4.3 Player側の中間テーブル削除戦略

Playerが削除された場合、中間テーブルのレコードは `dependent: :destroy` により自動削除される。これはマスタデータ側の `dependent: :restrict_with_error` とは逆の方向であり、「選手の削除は自由、マスタデータの削除は選手紐づき時に制限」という設計方針を反映している。

---

## 6. フロントエンド実装詳細

### 6.1 TypeScript型定義

#### 6.1.1 BattingSkill（src/types/battingSkill.ts）

```typescript
export type SkillType = 'positive' | 'negative' | 'neutral'

export interface BattingSkill {
  id: number
  name: string
  description: string | null
  skill_type: SkillType
}
```

#### 6.1.2 BattingStyle（src/types/battingStyle.ts）

```typescript
export interface BattingStyle {
  id: number
  name: string
  description: string | null
}
```

#### 6.1.3 PitchingSkill（src/types/pitchingSkill.ts）

```typescript
export type SkillType = 'positive' | 'negative' | 'neutral'

export interface PitchingSkill {
  id: number
  name: string
  description: string | null
  skill_type: SkillType
}
```

**備考**: `SkillType` 型は `battingSkill.ts` と `pitchingSkill.ts` の両方で個別に定義されている（共通化されていない）。

#### 6.1.4 PitchingStyle（src/types/pitchingStyle.ts）

```typescript
export interface PitchingStyle {
  id: number
  name: string
  description: string | null
}
```

#### 6.1.5 PlayerType（src/types/playerType.ts）

```typescript
export interface PlayerType {
  id: number
  name: string
  description: string | null
}
```

#### 6.1.6 Biorhythm（src/types/biorhythm.ts）

```typescript
export interface Biorhythm {
  id: number
  name: string
  start_date: string // YYYY-MM-DD
  end_date: string   // YYYY-MM-DD
}
```

### 6.2 状態管理

マスタデータ管理画面ではVuex/Piniaによるグローバル状態管理は使用していない。各 `GenericMasterSettings` インスタンスがローカルにデータを保持する:

- `loading: ref(false)` — ローディング状態
- `items: ref<T[]>([])` — マスタデータ一覧
- `isDialogVisible: ref(false)` — ダイアログ表示状態
- `editingItem: ref<T | null>(null)` — 編集中のアイテム

データの取得・更新はすべて各コンポーネント内で `axios` を直接使用して行い、操作後は `loadItems()` で一覧を再取得する。

### 6.3 API通信

- **HTTPクライアント**: `@/plugins/axios`（カスタム設定済みaxiosインスタンス）
- **エラーハンドリング**: `isAxiosError` でAxiosエラーを判定。レスポンスの `errors` 配列（Rails側の `full_messages`）があれば結合して表示
- **通知**: `useSnackbar` コンポーザブルで成功/エラーメッセージを画面下部に表示
- **国際化**: 全ラベル・メッセージは `vue-i18n` の `t()` 関数経由。i18nキープレフィックスは `settings.{masterType}` の命名規則

---

## 7. 既知の制約・未実装機能

### ~~7.1 認証未実装~~ （解決済み）

6種類のマスタデータコントローラは全て `Api::V1::BaseController` を継承しており、`before_action :authenticate_user!` により認証が必須となった。

### 7.2 専用シリアライザー不在

マスタデータのAPIレスポンスは `to_json` による直接シリアライズを使用している。`app/serializers/` に該当するシリアライザーファイルは存在しない。このため:
- `created_at`, `updated_at` がレスポンスに常に含まれる（フロントエンド側では使用していない）
- レスポンス形式のカスタマイズ（フィールド選択、ネスト構造等）ができない
- N+1クエリ対策が不要な代わりに、将来の拡張時にシリアライザー導入が必要になる可能性がある

### 7.3 DB制約の不均一性

セクション4.9で詳述した通り、`batting_styles` と `pitching_styles` はDB上の NOT NULL 制約・UNIQUE INDEX がなく、モデルバリデーションに完全に依存している。これはマイグレーションが段階的に追加された結果と考えられるが、データ整合性の観点ではDB制約の追加が望ましい。

### 7.4 PitchingSkillの has_many 未定義

`PitchingSkill` モデルには `has_many :player_pitching_skills` / `has_many :players, through:` の定義がない。`BattingSkill`, `PlayerType`, `Biorhythm` には定義されている。これにより:
- `PitchingSkill` の削除時は `dependent: :restrict_with_error` ではなくDB外部キー制約のみで制限される
- エラーメッセージの形式がRails側（`restrict_with_error`）とDB側（外部キー制約違反）で異なる

### 7.5 BattingStyleの has_many 未定義

`BattingStyle` モデルにも `has_many :players` の定義がない。Playerモデル側で `belongs_to :batting_style` が定義されているため参照は機能するが、`BattingStyle.find(1).players` のような逆引きクエリは使用できない。`PitchingStyle` も同様。

### 7.6 バイオリズムの期間バリデーション未実装

`Biorhythm` モデルでは `start_date` と `end_date` の存在チェックのみ行っており、`start_date <= end_date` の論理チェック、期間重複チェック、年度範囲チェック等は未実装。フロントエンド側も日付形式の正規表現チェックのみで、論理的な期間バリデーションは行っていない。

### ~~7.7 SkillType型の重複定義~~ （解決済み）

`SkillType` 型は `src/types/skill.ts` に共通定義として統合された。`BattingSkillSettings` と `PitchingSkillSettings` は `@/types/skill` からインポートしている。ただし、`battingSkill.ts` と `pitchingSkill.ts` にも個別の `SkillType` 定義が残っている可能性がある。

---

## 8. マスタデータ管理方針の変更（2026-02-15）

### 8.1 YAML設定ファイル管理への移行

対象5種（打撃特徴、投球特徴、打撃特殊能力、投球特殊能力、選手タイプ）はYAML設定ファイルでの管理に移行中。バイオリズムはDB管理のまま維持（将来的に日程表との連動予定）。

#### 8.1.1 移行方針（案A: DBシード方式）— 実装済み

- **既存テーブルと関連は維持**: `batting_skills`, `batting_styles`, `pitching_skills`, `pitching_styles`, `player_types` テーブルおよび中間テーブルはそのまま残す
- **YAML設定ファイル**: `config/master_data/*.yml` に各マスタデータを配置
- **Rakeタスクによる同期**（`lib/tasks/master_data.rake`）:
  - `rake master_data:sync`: YAML → DB 同期（`find_or_initialize_by(name:)` で upsert、削除は行わない）
  - `rake master_data:export`: DB → YAML 出力（現在のDBデータをYAMLに書き出し）
- **APIの書き込み制限**: 対象5種のコントローラで `create`/`update`/`destroy` が `403 Forbidden` を返すように変更済み

この方式により、既存の選手データとの関連やAPIエンドポイントの動作を維持したまま、マスタデータの管理を YAML ファイルで一元化できる。

#### 8.1.1a Rakeタスク詳細

**対象モデルと同期フィールド**:

| キー | モデル | ソート | 同期フィールド |
|------|--------|-------|--------------|
| `batting_styles` | BattingStyle | `:id` | `name`, `description` |
| `pitching_styles` | PitchingStyle | `:id` | `name`, `description` |
| `batting_skills` | BattingSkill | `:id` | `name`, `description`, `skill_type` |
| `pitching_skills` | PitchingSkill | `:id` | `name`, `description`, `skill_type` |
| `player_types` | PlayerType | `:id` | `name`, `description`, `category` |

**`master_data:sync` の動作**:
1. 各YAMLファイル（`config/master_data/{key}.yml`）を読み込み
2. エントリごとに `Model.find_or_initialize_by(name: entry["name"])` で既存レコードを検索（なければ新規）
3. YAMLのフィールド値を `assign_attributes` でセット
4. 新規レコードまたは変更があったレコードのみ `save!` で保存
5. 削除は行わない（YAMLから削除してもDBレコードは残る）

**`master_data:export` の動作**:
1. 各モデルからソート順で全レコードを取得
2. `key` + 同期フィールドをハッシュに変換
3. `config/master_data/{key}.yml` にYAML形式で書き出し

#### 8.1.2 Settings画面の変更

フロントエンドのSettings画面は**読み取り専用**に変更された（バックエンドも `403 Forbidden` で書き込みを拒否）:

- **追加ボタン**: 非表示
- **編集ボタン（mdi-pencil）**: 非表示
- **削除ボタン（mdi-delete）**: 非表示
- **操作カラム**: テーブルから除外
- **案内表示**: 「この設定は設定ファイルで管理されているため、ここでは閲覧のみ可能です。」（v-alert, `settings.managedByConfigFile`）

**変更対象コンポーネント**:

| コンポーネント | 変更内容 |
|--------------|---------|
| `GenericMasterSettings.vue` | `readonly` prop を追加（default: false）。readonly=true でCRUD UI非表示、案内表示 |
| `PitchingStyleSettings.vue` | `:readonly="true"` を指定 |
| `BattingStyleSettings.vue` | `:readonly="true"` を指定 |
| `PitchingSkillSettings.vue` | `:readonly="true"` を指定 |
| `BattingSkillSettings.vue` | `:readonly="true"` を指定 |
| `PlayerTypeSettings.vue` | `:readonly="true"` を指定 |
| `BiorhythmSettings.vue` | `readonly` 指定なし（CRUD操作可能のまま） |

**国際化対応**:

- `src/locales/ja.json` の `settings` セクションに `managedByConfigFile` キーを追加

#### 8.1.3 今後の方針

段階的にDB依存を削減し、最終的には**案B（DB完全廃止、YAML単独管理）**への移行を検討。ただし、選手データとの関連（外部キー、中間テーブル）や既存機能への影響を考慮し、慎重に進める。

当面は案Aで運用し、YAML設定ファイルの管理運用が安定した段階で、データベーステーブルの廃止を検討する。
