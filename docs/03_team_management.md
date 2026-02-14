# 03. チーム管理

## 概要

東方BIG野球まとめシステムにおけるチーム管理機能は、チームの作成・編集・削除、およびチームに所属する選手（チームメンバー）の管理を担う。チーム管理は以下の3つの主要エンティティで構成される:

1. **チーム（Team）**: 名前・略称・活動状態を持つ基本エンティティ。監督・コーチは中間テーブル（TeamManager）経由で管理する
2. **チームメンバーシップ（TeamMembership）**: チームと選手の多対多関連を管理する中間テーブル。選手ごとのコストタイプ選択（`selected_cost_type`）および軍区分（`squad`: 1軍/2軍）を保持する
3. **チームマネージャー（TeamManager）**: チームと監督（Manager）の関連を管理する中間テーブル。役割（`role`: director/coach）をenumで区別し、同一リーグ内での兼任禁止バリデーションを持つ

チーム管理機能は以下の画面で構成される:

- **チーム一覧画面（TeamList）**: 全チームの表示・作成・編集・削除
- **チーム作成/編集ダイアログ（TeamDialog）**: チームの名前・略称・監督・コーチ・活動状態を設定
- **チームメンバー編集画面（TeamMembers）**: 選手の追加・削除、コストタイプ選択、総コスト管理

さらに、コミッショナーモード（リーグ管理）では以下の追加管理機能が提供される:

- **コミッショナー用チームメンバーシップ管理**: squad/コストタイプの個別更新・削除
- **コミッショナー用チームマネージャー管理**: 監督・コーチの個別CRUD

---

## 画面構成（フロントエンド）

### チーム一覧画面（TeamList）

**パス:** `/teams`

**コンポーネント:** `src/views/TeamList.vue`

**レイアウト:**
```
┌────────────────────────────────────────────────────────┐
│  チーム一覧                            [+ チームを追加] │
├────────────────────────────────────────────────────────┤
│  ID │ チーム名 │ 略称 │ 監督名 │ 活動中 │ 操作        │
│  1  │ 紅魔館   │ SDM  │ 霊夢   │   ✓   │ [編集][削除]│
│  2  │ 白玉楼   │ WHT  │ 魔理沙 │   ✓   │ [編集][削除]│
│  3  │ 永遠亭   │ EIT  │ -      │       │ [編集][削除]│
└────────────────────────────────────────────────────────┘
```

**データテーブルヘッダー定義（`TeamList.vue:71-78`）:**

| ヘッダー | キー | ソート | 説明 |
|---------|------|--------|------|
| ID | `id` | 可 | チームID |
| チーム名 | `name` | 可 | チーム正式名称 |
| 略称 | `short_name` | 可 | チーム略称 |
| 監督名 | `manager_name` | 不可 | 監督の名前（カスタムスロットで `item.manager?.name` を表示） |
| 活動中 | `is_active` | 不可 | アクティブフラグ（`mdi-check` アイコン表示） |
| 操作 | `actions` | 不可 | 編集・削除アイコン |

**操作アイコン:**

| アイコン | 動作 |
|---------|------|
| `mdi-pencil` | チーム編集ダイアログ（`TeamDialog`）を開く。`openDialog(item)` で既存データのコピーを渡す |
| `mdi-delete` | `ConfirmDialog` で確認後、`DELETE /api/v1/teams/:id` を実行 |

**データ取得（`TeamList.vue:92-103`）:**
```typescript
const fetchTeams = async () => {
  loading.value = true;
  try {
    const response = await axios.get<Team[]>('/teams');
    teams.value = response.data;
  } catch (error) {
    console.error('Error fetching teams:', error);
    showSnackbar(t('teamList.fetchFailed'), 'error');
  } finally {
    loading.value = false;
  }
};
```

- マウント時（`onMounted`）に自動取得
- チーム保存完了（`TeamDialog` の `save` イベント）時に再取得
- チーム削除完了時に再取得

**削除フロー（`TeamList.vue:109-127`）:**
```
[1] deleteTeam(id) 呼び出し
       ↓
[2] ConfirmDialog.open() で確認表示（color: 'error'）
       ↓
[3] ユーザーが承認 → DELETE /api/v1/teams/:id 実行
       ↓
[4] 成功時: スナックバー表示 + fetchTeams() で一覧再取得
       ↓
[5] 失敗時: エラースナックバー表示
```

**ダイアログ制御（`TeamList.vue:133-136`）:**
```typescript
const openDialog = (team: Team | null = null) => {
  editingTeam.value = team ? { ...team } : null; // スプレッド構文でコピー（参照渡し防止）
  dialogVisible.value = true;
};
```

**国際化キー:**
- `teamList.title`: 画面タイトル
- `teamList.addTeam`: 追加ボタンラベル
- `teamList.headers.*`: テーブルヘッダー各項目（id, name, shortName, managerName, isActive, actions）
- `teamList.noData`: データなし時のメッセージ
- `teamList.deleteConfirmTitle` / `deleteConfirmMessage`: 削除確認ダイアログ
- `teamList.deleteSuccess` / `deleteFailed` / `fetchFailed`: 操作結果メッセージ

---

### チーム作成/編集ダイアログ（TeamDialog）

**コンポーネント:** `src/components/TeamDialog.vue`

**用途:** チームの新規作成および既存チームの編集

**ダイアログレイアウト:**
```
+──────────────────────────────────+
|  チームを追加 / チームを編集      |
|                                  |
|  名前:        [________________] |
|  略称:        [________________] |
|  監督:        [▼ 霊夢        ]   |
|  コーチ:      [▼ 魔理沙, 早苗]   |
|  [✓] 活動中                       |
|                                  |
|          [キャンセル] [保存]      |
+──────────────────────────────────+
```

**Props（`TeamDialog.vue:79-89`）:**

| Prop | 型 | デフォルト | 説明 |
|------|-----|---------|------|
| `isVisible` | `boolean` | `false` | ダイアログ表示フラグ（v-model対応） |
| `team` | `Team \| null` | `null` | 編集対象のチーム（`null`で新規作成） |
| `defaultManagerId` | `number \| null` | `null` | デフォルト監督ID（マネージャー一覧から遷移時に使用） |

**Emits:**
- `update:isVisible`: ダイアログ表示状態の変更
- `save`: 保存完了通知（親が `fetchTeams()` を再実行）

**フォームフィールド:**

| フィールド | v-model | 型 | バリデーション | 説明 |
|-----------|---------|------|-------------|------|
| 名前 | `editedTeam.name` | `v-text-field` | `required`（空文字不可） | チーム正式名称 |
| 略称 | `editedTeam.short_name` | `v-text-field` | なし | チーム略称（任意） |
| 監督 | `editedTeam.director_id` | `v-autocomplete` | なし | 監督（Managerテーブルから選択）。`defaultManagerId` 設定時は `readonly` |
| コーチ | `editedTeam.coach_ids` | `v-autocomplete (multiple)` | なし | コーチ（複数選択可） |
| 活動中 | `editedTeam.is_active` | `v-checkbox` | なし | アクティブフラグ（デフォルト: `true`） |

**内部状態（EditedTeam型、`TeamDialog.vue:98-104`）:**
```typescript
interface EditedTeam {
  name: string;
  short_name: string;
  is_active: boolean;
  director_id?: number | null;
  coach_ids?: number[];
}
```

**バリデーション（`TeamDialog.vue:119-123`）:**
```typescript
const rules = {
  required: (value: string) => !!value || t('validation.required'),
};
const isFormValid = computed(() => !!editedTeam.value.name);
```
- 保存ボタンは `isFormValid` が `false` の場合に `:disabled` で無効化

**動作フロー（`TeamDialog.vue:135-153`）:**

1. **新規作成**（`props.team` が `null`）:
   - タイトル: `t('teamDialog.title.add')`
   - `editedTeam` をデフォルト値で初期化: `{ name: '', short_name: '', is_active: true, director_id: null, coach_ids: [] }`
   - `defaultManagerId` があれば `director_id` に設定
   - 保存: `POST /api/v1/teams` に `{ team: teamData }` を送信

2. **編集**（`props.team` がオブジェクト）:
   - タイトル: `t('teamDialog.title.edit')`
   - `editedTeam` を `props.team` から初期化:
     - `director_id`: `props.team.director?.id`
     - `coach_ids`: `props.team.coaches?.map(c => c.id) ?? []`
   - 保存: `PATCH /api/v1/teams/:id` に `{ team: teamData }` を送信

3. 保存成功時: `save` イベントを emit → 親が `fetchTeams()` 実行 → ダイアログ閉じる

4. 保存失敗時: エラーメッセージをスナックバーで表示
   - `error.response.data.errors` が配列の場合、改行区切りで連結して表示

**監督・コーチ選択肢の取得（`TeamDialog.vue:125-133`）:**
```typescript
const fetchManagers = async () => {
  const response = await axios.get<Manager[]>('/managers');
  managers.value = response.data;
};
```
- ダイアログ表示時（`watch(() => props.isVisible)`）に `managers.value.length === 0` のときのみ取得（キャッシュ）

**defaultManagerId の watch（`TeamDialog.vue:155-159`）:**
- `defaultManagerId` が変更され、新規作成モードの場合、`editedTeam.director_id` を自動設定（`immediate: true`）

**国際化キー:**
- `teamDialog.title.add` / `teamDialog.title.edit`: ダイアログタイトル
- `teamDialog.form.name` / `shortName` / `director` / `coaches` / `isActive`: フォームラベル
- `teamDialog.notifications.addSuccess` / `updateSuccess`: 保存成功メッセージ
- `teamDialog.notifications.saveFailed` / `saveFailedWithErrors` / `fetchManagersFailed`: エラーメッセージ

---

### チームメンバー編集画面（TeamMembers）

**パス:** `/teams/:teamId/members`

**コンポーネント:** `src/views/TeamMembers.vue`

**レイアウト:**
```
┌────────────────────────────────────────────────────────┐
│  紅魔館のメンバー管理                                  │
├────────────────────────────────────────────────────────┤
│  コスト一覧表: [▼ 2025年度コスト表]                   │
│  選手選択:     [▼ 00 霧雨魔理沙   ] [追加]            │
├────────────────────────────────────────────────────────┤
│  チームメンバー一覧                                    │
│  合計: 25/50 人 / 総コスト: 180/200                    │
│  [投手: 10] [捕手: 3] [内野手: 8] [外野手: 4]         │
├────────────────────────────────────────────────────────┤
│ 背番号 │ 名前   │ タイプ │ 守備 │ 投 │ 打 │ コスト  │ 操作│
│ 00     │ 魔理沙 │ 二刀流 │ P    │ 右 │ 右 │[▼通常 10]│[×]│
│ 01     │ 霊夢   │ 野手専 │ C    │ 右 │ 右 │[▼通常 8] │[×]│
└────────────────────────────────────────────────────────┘
│                               [キャンセル] [保存]       │
└────────────────────────────────────────────────────────┘
```

**主要な機能:**

1. **コスト一覧表の選択**: `CostListSelect` 共有コンポーネントで選択。マウント時に現在日時が期間内のコスト表を自動選択。選択変更時に `watch` で全データを再取得
2. **選手の追加**: 選択中コスト一覧表に `normal_cost` が null でない選手のみ候補に表示。すでにチームに追加済みの選手は除外
3. **コストタイプの選択**: 選手ごとに `normal_cost`, `relief_only_cost`, `pitcher_only_cost`, `fielder_only_cost`, `two_way_cost` から選択（選手のプレイヤータイプIDに応じて選択肢が動的に変わる）
4. **制限チェック**:
   - 最大選手数: `MAX_PLAYERS = 50`
   - 総コスト上限: `TOTAL_TEAM_MAX_COST = 200`
   - 超過時は警告スナックバー表示（保存自体は可能）

**データテーブルヘッダー定義（`TeamMembers.vue:147-156`）:**

| ヘッダー | キー | 説明 |
|---------|------|------|
| 背番号 | `number` | 選手の背番号 |
| 名前 | `name` | 選手名 |
| プレイヤータイプ | `player_type_ids` | 選手タイプ（`v-chip-group` でチップ表示、`playerTypes` マスタから名称解決） |
| 守備位置 | `position` | 投手・捕手・内野手・外野手（`t('baseball.positions.${item.position}')` で国際化） |
| 投 | `throws` | 投球腕（`t('baseball.throwingHands.${item.throwing_hand}')` で国際化） |
| 打 | `bats` | 打席（`t('baseball.battingHands.${item.batting_hand}')` で国際化） |
| コスト | `cost` | `v-select` でコストタイプ選択ドロップダウン |
| 操作 | `actions` | 削除ボタン（`mdi-delete`） |

**コストタイプ選択肢の動的生成（`TeamMembers.vue:276-297`）:**

```typescript
const getAvailableCostTypes = (player: Player) => {
  const costPlayerForSelectedList = player.cost_players.find(
    cp => cp.cost_id === selectedCostListId.value
  );
  if (!costPlayerForSelectedList) return [];

  const options: { value: CostType, text: string }[] = [];

  // normal_cost: 値がnullでなければ常に表示
  addOption('normal_cost', costPlayerForSelectedList.normal_cost);

  // relief_only_cost: player_type_ids に 9 が含まれる場合
  if (player.player_type_ids?.includes(9))
    addOption('relief_only_cost', costPlayerForSelectedList.relief_only_cost);

  // pitcher_only_cost / fielder_only_cost: player_type_ids に 8 が含まれる場合
  if (player.player_type_ids?.includes(8)) {
    addOption('pitcher_only_cost', costPlayerForSelectedList.pitcher_only_cost);
    addOption('fielder_only_cost', costPlayerForSelectedList.fielder_only_cost);
  }

  // two_way_cost: player_type_ids に 2 が含まれる場合
  if (player.player_type_ids?.includes(2))
    addOption('two_way_cost', costPlayerForSelectedList.two_way_cost);

  return options;
};
```

**プレイヤータイプID とコストタイプの対応:**

| player_type_id | 意味 | 追加コストタイプ |
|---------------|------|---------------|
| 2 | （二刀流関連） | `two_way_cost` |
| 8 | （投手/野手切替可能） | `pitcher_only_cost`, `fielder_only_cost` |
| 9 | （リリーフ専用） | `relief_only_cost` |

※ player_type_ids の定数値（2, 8, 9）の意味の詳細はマスタデータ仕様（05_master_data.md）参照。

**選手追加フロー（`TeamMembers.vue:305-333`）:**
```
[1] selectedCost で有効なコスト一覧表を選択（未選択時は選手選択が disabled）
       ↓
[2] availablePlayers から選手を選択
    （normal_cost が null でなく、かつ teamPlayers に未追加の選手のみ）
       ↓
[3] addPlayer() 呼び出し
       ↓
[4] 重複チェック（teamPlayers に同じIDの選手がいないか確認）
       ↓
[5] initial_cost_type = 'normal_cost' で TeamPlayer オブジェクトを作成
       ↓
[6] teamPlayers に追加 → selectedPlayer をクリア
       ↓
[7] 人数制限チェック → MAX_PLAYERS 超過時は警告スナックバー
[8] コスト制限チェック → TOTAL_TEAM_MAX_COST 超過時は警告スナックバー
```

**初期コストタイプ決定ロジック（`TeamMembers.vue:216-251`）:**

チームメンバー取得時（`fetchTeamPlayers`）の `selected_cost_type` 決定は以下の優先順位:

1. バックエンドから返された `selected_cost_type` が有効な選択肢に存在し、対応するコスト値が null でなければ採用
2. `normal_cost` が null でなければ `'normal_cost'` を採用
3. いずれかの選択肢が存在すればその最初の値を採用
4. いずれもなければ `'normal_cost'` をデフォルトとする

**保存フロー（`TeamMembers.vue:340-359`）:**
```
[1] saveTeamMembers() 呼び出し
       ↓
[2] selectedCostListId が null なら警告表示して中断
       ↓
[3] payload 生成:
    {
      cost_list_id: selectedCostListId.value,
      players: [
        { player_id: 1, selected_cost_type: 'normal_cost' },
        { player_id: 2, selected_cost_type: 'relief_only_cost' },
        ...
      ]
    }
       ↓
[4] POST /api/v1/teams/:teamId/team_players に送信
       ↓
[5] 成功時: スナックバー表示
[6] 失敗時: エラースナックバー表示
```

**computed プロパティ:**

1. **`totalTeamCost`**（`TeamMembers.vue:159-165`）: 全チームメンバーのコストを合算。各選手の `selected_cost_type` と選択中コスト一覧表IDに基づいて `cost_players` から実際のコスト値を取得
2. **`availablePlayers`**（`TeamMembers.vue:167-174`）: 全選手から「選択中コスト一覧表にコストデータが存在」かつ「`normal_cost` が null でない」かつ「チーム未追加」の選手を抽出
3. **`positionCounts`**（`TeamMembers.vue:176-189`）: チームメンバーの `position` フィールド（pitcher, catcher, infielder, outfielder）ごとの人数をカウント

**データ取得タイミング:**

| イベント | 取得API |
|---------|--------|
| マウント時 | `fetchTeam()` |
| `selectedCost` 変更時（`watch`） | `fetchAllPlayers()` → `fetchTeamPlayers()` → `fetchPlayerTypes()` |

- `fetchTeam()`: `GET /api/v1/teams/:teamId` でチーム基本情報を取得
- `fetchAllPlayers()`: `GET /api/v1/team_registration_players` で全選手一覧を取得
- `fetchTeamPlayers()`: `GET /api/v1/teams/:teamId/team_players` でチーム所属選手を取得
- `fetchPlayerTypes()`: `GET /api/v1/player-types` でプレイヤータイプマスタを取得

**国際化キー:**
- `teamMembers.title`: 画面タイトル（`{ teamName }` プレースホルダ）
- `teamMembers.selectCostList` / `selectPlayer` / `addPlayer`: コントロールラベル
- `teamMembers.teamMembersTitle`: カードタイトル
- `teamMembers.totalCount` / `totalCost`: 合計表示（`{ count, max }`, `{ cost, max }` プレースホルダ）
- `teamMembers.headers.*`: テーブルヘッダー各項目
- `teamMembers.costTypes.*`: コストタイプ名（`normal_cost`, `relief_only_cost` 等）
- `teamMembers.notifications.*`: 各種通知メッセージ
- `teamMembers.unknownType`: 不明なプレイヤータイプのフォールバック

---

## APIエンドポイント

### 1. チーム一覧取得

**エンドポイント:** `GET /api/v1/teams`

**コントローラー:** `Api::V1::TeamsController#index`

**認証:** 必要（`ApplicationController` の認証）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "name": "紅魔館",
    "short_name": "SDM",
    "is_active": true,
    "has_season": false,
    "director": {
      "id": 1,
      "name": "博麗霊夢",
      "role": "director"
    },
    "coaches": [
      {
        "id": 2,
        "name": "霧雨魔理沙",
        "role": "coach"
      }
    ]
  }
]
```

**処理:**
```ruby
# app/controllers/api/v1/teams_controller.rb:7-10
def index
  @teams = Team.preload(:director, :coaches).all
  render json: @teams, each_serializer: TeamSerializer
end
```

- `preload(:director, :coaches)` でN+1クエリを防止
- `TeamSerializer` で `id`, `name`, `short_name`, `is_active`, `has_season`, `director`, `coaches` を出力

---

### 2. チーム詳細取得

**エンドポイント:** `GET /api/v1/teams/:id`

**コントローラー:** `Api::V1::TeamsController#show`

**認証:** 必要

**レスポンス（200 OK）:** チーム一覧取得と同じ形式の単一オブジェクト

**レスポンス（404 Not Found）:**
```json
{
  "error": "Team not found"
}
```

**処理:**
```ruby
# app/controllers/api/v1/teams_controller.rb:13-15, 47-51
def show
  render json: @team, serializer: TeamSerializer
end

def set_team
  @team = Team.includes(:director, :coaches).find(params[:id])
rescue ActiveRecord::RecordNotFound
  render json: { error: 'Team not found' }, status: :not_found
end
```

- `includes(:director, :coaches)` でEager Loadingを適用
- `ActiveRecord::RecordNotFound` を rescue して404を返却

---

### 3. チーム作成

**エンドポイント:** `POST /api/v1/teams`

**コントローラー:** `Api::V1::TeamsController#create`

**認証:** 必要

**リクエスト:**
```json
{
  "team": {
    "name": "守矢神社",
    "short_name": "MRY",
    "is_active": true,
    "director_id": 3,
    "coach_ids": [4, 5]
  }
}

```

**許可パラメータ（`teams_controller.rb:53-55`）:**
```ruby
def team_params
  params.require(:team).permit(:name, :short_name, :is_active, :director_id, coach_ids: [])
end
```

**レスポンス（201 Created）:** TeamSerializerの出力（チーム詳細と同形式）

**レスポンス（422 Unprocessable Entity）:**
```json
{
  "errors": ["Name can't be blank"]
}
```

**処理フロー:**
```
[1] team_params から director_id, coach_ids を除外して Team.new
       ↓
[2] team.save 実行
       ↓
[3a] 保存成功時:
       → update_managers(team, director_id, coach_ids) で監督・コーチを設定
       → 201 Created で TeamSerializer の結果を返却
[3b] 保存失敗時:
       → 422 Unprocessable Entity でエラーメッセージ配列を返却
```

---

### 4. チーム更新

**エンドポイント:** `PATCH /api/v1/teams/:id` または `PUT /api/v1/teams/:id`

**コントローラー:** `Api::V1::TeamsController#update`

**認証:** 必要

**リクエスト:** チーム作成と同形式

**レスポンス（200 OK）:** TeamSerializerの出力

**レスポンス（422 Unprocessable Entity）:** チーム作成と同形式のエラー

**処理:**
```ruby
# app/controllers/api/v1/teams_controller.rb:30-37
def update
  if @team.update(team_params.except(:director_id, :coach_ids))
    update_managers(@team, team_params[:director_id], team_params[:coach_ids])
    render json: @team, serializer: TeamSerializer
  else
    render json: { errors: @team.errors.full_messages }, status: :unprocessable_entity
  end
end
```

---

### 5. チーム削除

**エンドポイント:** `DELETE /api/v1/teams/:id`

**コントローラー:** `Api::V1::TeamsController#destroy`

**認証:** 必要

**レスポンス（204 No Content）:** レスポンスボディなし

**レスポンス（404 Not Found）:**
```json
{
  "error": "Team not found"
}
```

**処理:**
```ruby
# app/controllers/api/v1/teams_controller.rb:40-43
def destroy
  @team.destroy
  head :no_content
end
```

**削除時の制約:**
- `Team` モデルの `has_one :season, dependent: :restrict_with_error` により、シーズンが紐づいている場合は削除不可（`ActiveRecord::DeleteRestrictionError` が発生）
- 現在のコントローラーではこのエラーを rescue していないため、500 Internal Server Error が返却される

---

### 6. チームメンバー（選手）一覧取得

**エンドポイント:** `GET /api/v1/teams/:team_id/team_players`

**コントローラー:** `Api::V1::TeamPlayersController#index`

**認証:** 必要

**クエリパラメータ:**
- `cost_list_id`（任意）: コスト一覧表のID。シリアライザーで `current_cost` 計算に使用

**リクエスト例:**
```
GET /api/v1/teams/1/team_players?cost_list_id=3
```

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "name": "霧雨魔理沙",
    "number": "00",
    "short_name": "魔理沙",
    "position": "pitcher",
    "player_type_ids": [2, 8],
    "throwing_hand": "right",
    "batting_hand": "right",
    "defense_p": "S",
    "defense_c": null,
    "defense_1b": null,
    "defense_2b": "C",
    "defense_3b": "B",
    "defense_ss": "D",
    "defense_of": "A",
    "defense_lf": "A",
    "defense_cf": "A",
    "defense_rf": "A",
    "throwing_c": null,
    "throwing_of": "85",
    "throwing_lf": "85",
    "throwing_cf": "85",
    "throwing_rf": "85",
    "cost_players": [
      {
        "id": 10,
        "cost_id": 3,
        "player_id": 1,
        "normal_cost": 10,
        "relief_only_cost": null,
        "pitcher_only_cost": 8,
        "fielder_only_cost": 7,
        "two_way_cost": 12
      }
    ],
    "selected_cost_type": "normal_cost",
    "current_cost": 10
  }
]
```

**処理:**
```ruby
# app/controllers/api/v1/team_players_controller.rb:4-8
def index
  cost_list_id = params[:cost_list_id]
  players = @team.players
  render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id
end
```

**TeamPlayerSerializer（`app/serializers/team_player_serializer.rb`）:**
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

- `PlayerSerializer` を継承し、`selected_cost_type` と `current_cost` を追加
- `selected_cost_type`: 該当チームの `TeamMembership` から取得
- `current_cost`: `selected_cost_type` と `cost_list_id` に基づいて `CostPlayer` テーブルからコスト値を動的取得（`send` メソッドでカラム名を動的指定）

**PlayerSerializer（`app/serializers/player_serializer.rb`）:**
```ruby
class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :position, :player_type_ids, :throwing_hand, :batting_hand,
             :defense_p, :defense_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss,
             :defense_of, :defense_lf, :defense_cf, :defense_rf,
             :throwing_c, :throwing_of, :throwing_lf, :throwing_cf, :throwing_rf

  has_many :cost_players, serializer: CostPlayerSerializer

  def player_type_ids
    object.player_player_types.pluck(:player_type_id)
  end
end
```

---

### 7. チームメンバー一括更新

**エンドポイント:** `POST /api/v1/teams/:team_id/team_players`

**コントローラー:** `Api::V1::TeamPlayersController#create`

**認証:** 必要

**リクエスト:**
```json
{
  "cost_list_id": 3,
  "players": [
    { "player_id": 1, "selected_cost_type": "normal_cost" },
    { "player_id": 2, "selected_cost_type": "relief_only_cost" },
    { "player_id": 3, "selected_cost_type": "two_way_cost" }
  ]
}
```

**レスポンス（200 OK）:**
```json
{
  "message": "Team members updated successfully"
}
```

**レスポンス（422 Unprocessable Entity）:**
```json
{
  "error": "Validation failed: Selected cost type can't be blank"
}
```

**処理フロー:**
```
[1] params.require(:players) で players 配列を取得
       ↓
[2] incoming_player_ids として player_id の配列を抽出
       ↓
[3] トランザクション開始
       ↓
[4] incoming_player_ids に含まれない既存の TeamMembership を destroy_all
       ↓
[5] 各 player について:
    - find_or_initialize_by(player_id) で既存レコード検索 or 新規初期化
    - update!(selected_cost_type: p[:selected_cost_type]) で更新
       ↓
[6] コミット成功 → 200 OK
[7] ActiveRecord::RecordInvalid → ロールバック → 422 Unprocessable Entity
```

**実装コード（`app/controllers/api/v1/team_players_controller.rb:10-28`）:**
```ruby
def create
  player_params = params.require(:players)
  incoming_player_ids = player_params.map { |p| p[:player_id] }

  ActiveRecord::Base.transaction do
    @team.team_memberships.where.not(player_id: incoming_player_ids).destroy_all

    player_params.each do |p|
      membership = @team.team_memberships.find_or_initialize_by(player_id: p[:player_id])
      membership.update!(selected_cost_type: p[:selected_cost_type])
    end
  end

  render json: { message: 'Team members updated successfully' }, status: :ok
rescue ActiveRecord::RecordInvalid => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

**重要な注意点:**
- このエンドポイントは**一括置換**方式で動作する。リクエストに含まれない既存メンバーは削除される
- フロントエンドは保存時に全メンバーを送信する必要がある
- `cost_list_id` パラメータはリクエストに含まれるがバックエンドでは使用していない（フロントエンド側の参照用）
- `squad` フィールドは更新されない（デフォルト値 `"second"` のまま）

---

### 8. チームメンバーシップ一覧取得（守備適性情報付き）

**エンドポイント:** `GET /api/v1/teams/:team_id/team_memberships`

**コントローラー:** `Api::V1::TeamMembershipsController#index`

**認証:** 必要

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "name": "00 霧雨魔理沙",
    "player_id": 1,
    "defense_p": "S",
    "defense_c": null,
    "defense_1b": null,
    "defense_2b": "C",
    "defense_3b": "B",
    "defense_ss": "D",
    "defense_of": "A",
    "defense_lf": "A",
    "defense_cf": "A",
    "defense_rf": "A",
    "throwing_c": null,
    "throwing_of": "85",
    "throwing_lf": "85",
    "throwing_cf": "85",
    "throwing_rf": "85"
  }
]
```

**処理（`app/controllers/api/v1/team_memberships_controller.rb:4-34`）:**

```ruby
def index
  team = Team.find(params[:team_id])
  team_memberships = team.team_memberships.preload(:player)

  output = team_memberships.map do |member|
    player = member.player
    {
      id: member.id,
      name: "#{player.number} #{player.name}",
      player_id: player.id,
      defense_p: player.defense_p, defense_c: player.defense_c,
      defense_1b: player.defense_1b, defense_2b: player.defense_2b,
      defense_3b: player.defense_3b, defense_ss: player.defense_ss,
      defense_of: player.defense_of, defense_lf: player.defense_lf,
      defense_cf: player.defense_cf, defense_rf: player.defense_rf,
      throwing_c: player.throwing_c, throwing_of: player.throwing_of,
      throwing_lf: player.throwing_lf, throwing_cf: player.throwing_cf,
      throwing_rf: player.throwing_rf,
    }
  end

  render json: output
end
```

**特徴:**
- シリアライザーを使わず、カスタムハッシュ形式でレスポンスを構築
- `name` フィールドは `"#{player.number} #{player.name}"` 形式（背番号＋名前）
- 守備適性（`defense_*`）と送球適性（`throwing_*`）を含む

**用途:**
- ロースター登録画面やスタメン選択画面など、守備適性情報が必要な場面で使用
- TeamMembers.vue（チームメンバー編集画面）では使用していない

---

### 9. コミッショナー用チームマネージャー管理

**コントローラー:** `Api::V1::Commissioner::TeamManagersController`

**ベースパス:** `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers`

| HTTPメソッド | パス | アクション | 説明 |
|-------------|------|----------|------|
| GET | `/team_managers` | `index` | チームの監督・コーチ一覧取得（`includes(:manager)`） |
| GET | `/team_managers/:id` | `show` | 個別取得 |
| POST | `/team_managers` | `create` | 監督/コーチ追加（`manager_id`, `role` を指定） |
| PATCH | `/team_managers/:id` | `update` | 役割変更等 |
| DELETE | `/team_managers/:id` | `destroy` | 個別削除 |

**許可パラメータ:** `params.require(:team_manager).permit(:manager_id, :role)`

---

### 10. コミッショナー用チームメンバーシップ管理

**コントローラー:** `Api::V1::Commissioner::TeamMembershipsController`

**ベースパス:** `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships`

| HTTPメソッド | パス | アクション | 説明 |
|-------------|------|----------|------|
| GET | `/team_memberships` | `index` | チームメンバーシップ一覧取得（`includes(:player)`） |
| GET | `/team_memberships/:id` | `show` | 個別取得 |
| PATCH | `/team_memberships/:id` | `update` | squad/selected_cost_type の個別更新 |
| DELETE | `/team_memberships/:id` | `destroy` | 個別削除 |

**許可パラメータ:** `params.require(:team_membership).permit(:squad, :selected_cost_type)`

**通常のチームメンバー管理との違い:**
- 通常版（`TeamPlayersController`）は一括置換方式
- コミッショナー版は個別CRUD方式（特定のメンバーシップだけを更新・削除可能）
- コミッショナー版では `squad` フィールドの更新も可能

---

## データモデル

### teamsテーブル

**スキーマ定義（`db/schema.rb:353-361`）:**
```ruby
create_table "teams", force: :cascade do |t|
  t.string "name"
  t.string "short_name"
  t.boolean "is_active", default: true
  t.bigint "manager_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["manager_id"], name: "index_teams_on_manager_id"
end

add_foreign_key "teams", "managers"
```

**カラム詳細:**

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|----|----|----------|------|
| `id` | bigint | NO | AUTO_INCREMENT | 主キー |
| `name` | string | YES | - | チーム正式名称 |
| `short_name` | string | YES | - | チーム略称 |
| `is_active` | boolean | YES | `true` | アクティブフラグ |
| `manager_id` | bigint | NO | - | 監督ID（`managers` テーブルへの外部キー） |
| `created_at` | datetime | NO | - | 作成日時 |
| `updated_at` | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_teams_on_manager_id` (manager_id)

**外部キー制約:**
- `manager_id` → `managers.id`

**モデル（`app/models/team.rb`）:**
```ruby
class Team < ApplicationRecord
  has_one :season, dependent: :restrict_with_error
  has_many :team_memberships, dependent: :destroy
  has_many :players, through: :team_memberships

  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships

  has_many :team_managers, dependent: :destroy
  has_one :director_team_manager, -> { where(role: :director) }, class_name: 'TeamManager', dependent: :destroy
  has_one :director, through: :director_team_manager, source: :manager
  has_many :coach_team_managers, -> { where(role: :coach) }, class_name: 'TeamManager', dependent: :destroy
  has_many :coaches, through: :coach_team_managers, source: :manager

  validates :name, presence: true
end
```

**リレーション:**

| 関連名 | 種類 | 対象 | dependent | 説明 |
|--------|------|------|-----------|------|
| `season` | `has_one` | Season | `restrict_with_error` | チームのシーズン。存在時は削除不可 |
| `team_memberships` | `has_many` | TeamMembership | `destroy` | チームメンバーシップ（中間テーブル） |
| `players` | `has_many :through` | Player | - | チームに所属する選手 |
| `league_memberships` | `has_many` | LeagueMembership | `destroy` | リーグ加盟（中間テーブル） |
| `leagues` | `has_many :through` | League | - | 加盟リーグ |
| `team_managers` | `has_many` | TeamManager | `destroy` | チームマネージャー（中間テーブル） |
| `director_team_manager` | `has_one` (scoped) | TeamManager | `destroy` | 監督のTeamManagerレコード（`role: :director` でフィルタ） |
| `director` | `has_one :through` | Manager | - | 監督 |
| `coach_team_managers` | `has_many` (scoped) | TeamManager | `destroy` | コーチのTeamManagerレコード群（`role: :coach` でフィルタ） |
| `coaches` | `has_many :through` | Manager | - | コーチ |

**バリデーション:**
- `name`: 必須（`presence: true`）

**削除時の挙動:**
- `season` が存在 → 削除不可（`restrict_with_error`）
- `team_memberships`, `league_memberships`, `team_managers` → 連鎖削除（`dependent: :destroy`）
  - ただし `team_memberships` に `player_absences` が紐づいている場合は、そちらの `restrict_with_error` により削除が失敗する

**スキーマとコントローラーの不整合:**

`teams` テーブルには `manager_id` カラム（NOT NULL）が存在するが、現在のコントローラー実装では `director_id` / `coach_ids` パラメータを使用して `team_managers` テーブル経由で管理している。`teams.manager_id` カラムはチーム作成時に値が設定されるが、その後の監督変更で更新されないため、実際の監督と一致しなくなる可能性がある。

---

### team_membershipsテーブル

**スキーマ定義（`db/schema.rb:341-351`）:**
```ruby
create_table "team_memberships", force: :cascade do |t|
  t.bigint "team_id", null: false
  t.bigint "player_id", null: false
  t.string "squad", default: "second", null: false
  t.string "selected_cost_type", default: "normal_cost", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["player_id"], name: "index_team_memberships_on_player_id"
  t.index ["team_id", "player_id"], name: "index_team_memberships_on_team_id_and_player_id", unique: true
  t.index ["team_id"], name: "index_team_memberships_on_team_id"
end

add_foreign_key "team_memberships", "players"
add_foreign_key "team_memberships", "teams"
```

**カラム詳細:**

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|----|----|----------|------|
| `id` | bigint | NO | AUTO_INCREMENT | 主キー |
| `team_id` | bigint | NO | - | チームID |
| `player_id` | bigint | NO | - | 選手ID |
| `squad` | string | NO | `"second"` | 軍区分（`"first"` = 1軍, `"second"` = 2軍） |
| `selected_cost_type` | string | NO | `"normal_cost"` | 選択コストタイプ |
| `created_at` | datetime | NO | - | 作成日時 |
| `updated_at` | datetime | NO | - | 更新日時 |

**selected_cost_type の許容値:**
- `normal_cost`: 通常コスト
- `relief_only_cost`: リリーフ専用コスト
- `pitcher_only_cost`: 投手専用コスト
- `fielder_only_cost`: 野手専用コスト
- `two_way_cost`: 二刀流コスト

**インデックス:**
- `index_team_memberships_on_team_id` (team_id)
- `index_team_memberships_on_player_id` (player_id)
- `index_team_memberships_on_team_id_and_player_id` (team_id, player_id) — **UNIQUE制約**: 同一チームに同一選手の重複登録を防止

**外部キー制約:**
- `team_id` → `teams.id`
- `player_id` → `players.id`

**モデル（`app/models/team_membership.rb`）:**
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

**リレーション:**

| 関連名 | 種類 | 対象 | dependent | 説明 |
|--------|------|------|-----------|------|
| `team` | `belongs_to` | Team | - | 所属チーム |
| `player` | `belongs_to` | Player | - | 所属選手 |
| `season_rosters` | `has_many` | SeasonRoster | - | シーズンロスター（1軍/2軍登録履歴） |
| `player_absences` | `has_many` | PlayerAbsence | `restrict_with_error` | 選手離脱記録（存在時は削除不可） |

**バリデーション:**
- `squad`: `"first"` または `"second"` のみ許可（`inclusion`）
- `selected_cost_type`: 必須（`presence: true`）

**シリアライザー:**

`TeamMembershipSerializer`（`app/serializers/team_membership_serializer.rb`）:
```ruby
class TeamMembershipSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :player_id, :squad, :selected_cost_type
  belongs_to :player
end
```

---

### team_managersテーブル

**スキーマ定義（`db/schema.rb:331-339`）:**
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

add_foreign_key "team_managers", "managers"
add_foreign_key "team_managers", "teams"
```

**カラム詳細:**

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|----|----|----------|------|
| `id` | bigint | NO | AUTO_INCREMENT | 主キー |
| `team_id` | bigint | NO | - | チームID |
| `manager_id` | bigint | NO | - | 監督/コーチID |
| `role` | integer | NO | `0` | 役割（enum: `0` = director, `1` = coach） |
| `created_at` | datetime | NO | - | 作成日時 |
| `updated_at` | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_team_managers_on_team_id` (team_id)
- `index_team_managers_on_manager_id` (manager_id)

**外部キー制約:**
- `team_id` → `teams.id`
- `manager_id` → `managers.id`

**モデル（`app/models/team_manager.rb`）:**
```ruby
class TeamManager < ApplicationRecord
  belongs_to :team
  belongs_to :manager

  enum :role, { director: 0, coach: 1 }

  validates :role, presence: true
  validates :team_id, uniqueness: { scope: :role, if: -> { director? },
    message: 'には既に監督が設定されています' }
  validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [:create, :update]

  private

  def manager_cannot_be_assigned_to_multiple_teams_in_same_league
    return unless manager_id.present? && team.present?
    current_league = team.leagues.first
    return unless current_league.present?

    other_teams_in_same_league = current_league.teams.where.not(id: team.id)
    if TeamManager.where(manager_id: manager_id, team_id: other_teams_in_same_league.select(:id)).exists?
      errors.add(:manager_id, 'は同一リーグ内の複数のチームに兼任することはできません')
    end
  end
end
```

**enum定義:**
- `role`: `director` (0) / `coach` (1)

**バリデーション:**

| バリデーション | 対象 | 条件 | 説明 |
|-------------|------|------|------|
| `presence` | `role` | 常時 | 役割は必須 |
| `uniqueness` (scope: `:role`) | `team_id` | `director?` の場合のみ | 1チームに監督は1人まで |
| カスタム | `manager_id` | `create`/`update` 時 | 同一リーグ内の複数チームへの兼任を禁止 |

**同一リーグ兼任禁止の詳細:**

`manager_cannot_be_assigned_to_multiple_teams_in_same_league` メソッドにより、同じマネージャーが同一リーグ内の複数チームの監督/コーチを兼任することが禁止される。処理フロー:

1. 当該チームが所属するリーグを取得（`team.leagues.first`）
2. リーグが存在しなければスキップ（リーグ未参加のチームでは制約なし）
3. 同じリーグに所属する他のチームを取得
4. 他チームに同じマネージャーが `TeamManager` として登録されていれば、バリデーションエラー

**シリアライザー:**

`TeamManagerSerializer`（`app/serializers/team_manager_serializer.rb`）:
```ruby
class TeamManagerSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :manager_id, :role
  belongs_to :manager
end
```

---

### ER図（チーム管理関連）

```
┌──────────┐     ┌──────────────────┐     ┌──────────┐
│ managers │     │  team_managers   │     │  teams   │
│──────────│     │──────────────────│     │──────────│
│ id       │←────│ manager_id       │     │ id       │
│ name     │     │ team_id          │────→│ name     │
│ short_name│    │ role (enum)      │     │short_name│
│ irc_name │     │──────────────────│     │is_active │
│ user_id  │                              │manager_id│←┐
│ role     │                              │──────────│ │
└──────────┘                              └────┬─────┘ │
                                               │       │
                                               │       │
                              ┌─────────────────────────┘
                              │ (FK: 未使用の遺留カラム)
                              │
                    ┌─────────┴────────┐     ┌──────────┐
                    │ team_memberships │     │ players  │
                    │──────────────────│     │──────────│
                    │ id               │     │ id       │
                    │ team_id          │     │ name     │
                    │ player_id        │────→│ number   │
                    │ squad            │     │ position │
                    │selected_cost_type│     │ ...      │
                    │──────────────────│     └──────────┘
                    └──────────────────┘
```

---

## ビジネスロジック

### チーム作成・編集時の監督・コーチ管理

**実装（`app/controllers/api/v1/teams_controller.rb:57-71`）:**
```ruby
def update_managers(team, director_id, coach_ids)
  team.transaction do
    team.director = director_id.present? ? Manager.find_by(id: director_id) : nil

    team.coach_team_managers.destroy_all
    if coach_ids.present?
      coach_ids.uniq.each do |id|
        team.coach_team_managers.create!(manager_id: id)
      end
    end
  end
rescue ActiveRecord::RecordInvalid => e
  team.errors.add(:base, e.message)
  raise ActiveRecord::Rollback
end
```

**処理フロー:**
1. トランザクション開始
2. **監督の設定**: `director_id` が存在すれば `Manager.find_by(id:)` で検索して `team.director =` で割り当て。存在しなければ `nil` を代入（監督なし）。既存の監督レコードは `has_one` の自動処理で削除される
3. **コーチの再設定**: `team.coach_team_managers.destroy_all` で既存コーチを全削除 → `coach_ids` から重複削除（`uniq`）して各コーチの `TeamManager` レコードを作成
4. エラー時: `team.errors` にメッセージを追加してロールバック

**制約:**
- 監督（director）は0人または1人（`TeamManager` モデルの `uniqueness` バリデーションでも保証）
- コーチ（coach）は複数人設定可能
- 同一リーグ内の兼任禁止バリデーション（`TeamManager` モデル）がトリガーされる場合がある
  - `team.coach_team_managers.create!` が `RecordInvalid` を raise → rescue でロールバック

**注意点:**
- `director_id` に無効なIDを指定すると、`Manager.find_by` が `nil` を返すため監督が未設定になる（エラーにならない）
- `coach_ids` が空またはパラメータに含まれない場合、既存のコーチがすべて削除される
- コーチ更新は毎回「全削除→再作成」方式のため、既存のコーチのIDは保持されない

---

### チームメンバーの一括更新

**処理概要:**

チームメンバー編集画面で保存ボタンを押すと、`teamPlayers` 配列全体をバックエンドに送信し、`team_memberships` テーブルを一括置換する。

**処理フロー（`app/controllers/api/v1/team_players_controller.rb:10-28`）:**

1. `params.require(:players)` で `players` 配列を取得
2. `incoming_player_ids` として送信された `player_id` の配列を抽出
3. トランザクション開始
4. `@team.team_memberships.where.not(player_id: incoming_player_ids).destroy_all`: 送信されなかった既存メンバーを削除
5. `player_params` の各要素について `find_or_initialize_by(player_id:)` + `update!(selected_cost_type:)` でUpsert
6. コミット成功 → 成功メッセージ返却
7. バリデーションエラー時 → ロールバック → 422 返却

**制約:**
- `selected_cost_type` は `TeamMembership` モデルの `presence: true` で検証
- `squad` フィールドは更新されない（デフォルト値 `"second"` のまま。軍区分の変更はロースター管理画面で行う）
- `team_memberships` に `player_absences` が紐づいている場合、`destroy_all` が `restrict_with_error` により失敗する可能性がある

---

### チーム削除時の制約

`Team` モデルの `has_one :season, dependent: :restrict_with_error` により、チームに紐づくシーズンが存在する場合は削除不可。

**影響の連鎖:**
```
Team#destroy 呼び出し
  ├── season が存在 → ActiveRecord::DeleteRestrictionError（削除中止）
  └── season が不在 → 以下が連鎖削除:
       ├── team_memberships (destroy) → ただし player_absences がある場合は restrict_with_error
       ├── league_memberships (destroy)
       └── team_managers (destroy)
```

---

## フロントエンド実装詳細

### TypeScript型定義

**Team型（`src/types/team.ts`）:**
```typescript
import { type Manager } from '@/types/manager'

export interface Team {
  id: number;
  name: string;
  short_name: string;
  is_active: boolean;
  has_season: boolean;
  director?: Manager;
  coaches?: Manager[];
}
```

**Manager型（`src/types/manager.ts`）:**
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

**TeamPlayer型（`src/views/TeamMembers.vue` 内で定義）:**
```typescript
type CostType = 'normal_cost' | 'relief_only_cost' | 'pitcher_only_cost' | 'fielder_only_cost' | 'two_way_cost';

interface TeamPlayer extends Player {
  selected_cost_type: CostType;
  current_cost: number;
}
```

**Player型（`src/types/player.ts`）:**
```typescript
import type { PlayerCost } from './playerCost';

export interface Player {
  id: number;
  name: string;
  short_name: string;
  number: string;
  position: string;
  throwing_hand: string;
  batting_hand: string;
  player_type_ids: number[];
  cost_players: PlayerCost[];
  defense_p?: string;
  defense_c?: string;
  defense_1b?: string;
  defense_2b?: string;
  defense_3b?: string;
  defense_ss?: string;
  defense_of?: string;
  defense_lf?: string;
  defense_cf?: string;
  defense_rf?: string;
  throwing_c?: number;
  throwing_of?: string;
  throwing_lf?: string;
  throwing_cf?: string;
  throwing_rf?: string;
}
```

**PlayerCost型（`src/types/playerCost.ts`）:**
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

**CostList型（`src/types/costList.ts`）:**
```typescript
export interface CostList {
  id: number;
  name: string;
  start_date: string | null;
  end_date: string | null;
  effective_date: string | null;
}
```

**PlayerType型（`src/types/playerType.ts`）:**
```typescript
export interface PlayerType {
  id: number;
  name: string;
  description: string | null;
}
```

---

### コンポーネント構成

**TeamList.vue:**
- 責務: チーム一覧の表示、チーム作成・編集ダイアログの制御、チーム削除
- 使用コンポーネント:
  - `TeamDialog`: チーム作成・編集ダイアログ（`v-model:isVisible` と `:team` props で制御）
  - `ConfirmDialog`: 削除確認ダイアログ（`ref` で直接メソッド呼び出し）
- 状態:
  - `teams: ref<Team[]>([])` — チーム一覧
  - `loading: ref(true)` — ローディング状態
  - `dialogVisible: ref(false)` — ダイアログ表示フラグ
  - `editingTeam: ref<Team | null>(null)` — 編集中のチーム（新規作成時は `null`）

**TeamDialog.vue:**
- 責務: チームの作成・編集フォーム表示と保存
- Props: `isVisible`, `team`, `defaultManagerId`
- Emits: `update:isVisible`, `save`
- 状態:
  - `editedTeam: ref<EditedTeam>({...defaultTeam})` — フォーム入力内容
  - `managers: ref<Manager[]>([])` — 監督・コーチ選択肢（初回表示時にフェッチ、キャッシュ）
  - `isFormValid: computed(() => !!editedTeam.value.name)` — フォームバリデーション

**TeamMembers.vue:**
- 責務: チームメンバーの編集、コストタイプ選択、総コスト計算、保存
- 使用コンポーネント:
  - `CostListSelect`（`src/components/shared/CostListSelect.vue`）: コスト一覧表選択ドロップダウン。マウント時に `GET /api/v1/costs` でコスト表一覧を取得し、現在日時が含まれるコスト表を自動選択
- 状態:
  - `team: ref<Partial<Team>>({})` — 対象チーム
  - `allPlayers: ref<Player[]>([])` — 全選手一覧（`GET /api/v1/team_registration_players`）
  - `teamPlayers: ref<TeamPlayer[]>([])` — チームメンバー
  - `selectedCost: ref<CostList | null>(null)` — 選択中のコスト一覧表
  - `selectedPlayer: ref<Player | null>(null)` — 追加する選手
  - `playerTypes: ref<PlayerType[]>([])` — プレイヤータイプマスタ
- 定数:
  - `MAX_PLAYERS = 50`
  - `TOTAL_TEAM_MAX_COST = 200`

---

### 状態管理

**認証:**
- `useAuth` composable でログイン状態を管理
- チーム管理画面はすべて `meta: { requiresAuth: true }` で認証必須（`authGuard` で制御）

**スナックバー通知:**
- `useSnackbar` composable で成功・エラーメッセージを一元表示
- `showSnackbar(message, type)` の `type`: `'success'` / `'error'` / `'warning'`

---

### APIクライアント（Axios）

フロントエンドの `axios` インスタンスは `/api/v1` をベースURLとして設定されており、コンポーネント内では相対パスでリクエストを送信する。

```typescript
// 例:
await axios.get<Team[]>('/teams');           // GET /api/v1/teams
await axios.post('/teams', { team: data });  // POST /api/v1/teams
await axios.patch(`/teams/${id}`, { team }); // PATCH /api/v1/teams/:id
await axios.delete(`/teams/${id}`);          // DELETE /api/v1/teams/:id
```

---

## ルーティング

### バックエンド（`config/routes.rb`）

**チーム管理関連ルート（`config/routes.rb:23-31`）:**
```ruby
resources :teams, only: [:index, :show, :update, :create, :destroy] do
  resource :season, only: [:show, :update], controller: 'team_seasons' do
    patch 'season_schedules/:id', to: 'team_seasons#update_season_schedule'
  end
  resource :roster, only: [:show, :create], controller: 'team_rosters'
  resource :key_player, only: [:create], controller: 'team_key_players'
  resources :team_players, only: [:index, :create]
  resources :team_memberships, only: [:index]
end
```

**生成されるルート一覧（チーム管理直接関連）:**

| HTTPメソッド | パス | コントローラー#アクション |
|-------------|------|------------------------|
| GET | `/api/v1/teams` | `teams#index` |
| POST | `/api/v1/teams` | `teams#create` |
| GET | `/api/v1/teams/:id` | `teams#show` |
| PATCH/PUT | `/api/v1/teams/:id` | `teams#update` |
| DELETE | `/api/v1/teams/:id` | `teams#destroy` |
| GET | `/api/v1/teams/:team_id/team_players` | `team_players#index` |
| POST | `/api/v1/teams/:team_id/team_players` | `team_players#create` |
| GET | `/api/v1/teams/:team_id/team_memberships` | `team_memberships#index` |

**コミッショナー用ルート（`config/routes.rb:69-84`）:**
```ruby
namespace :commissioner do
  resources :leagues do
    resources :teams do
      resources :team_memberships, only: [:index, :update, :destroy] do
        resources :player_absences, only: [:index, :create, :update, :destroy]
      end
      resources :team_managers, only: [:index, :create, :update, :destroy]
    end
  end
end
```

**生成されるルート一覧（コミッショナー用）:**

| HTTPメソッド | パス | コントローラー#アクション |
|-------------|------|------------------------|
| GET | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships` | `commissioner/team_memberships#index` |
| PATCH | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id` | `commissioner/team_memberships#update` |
| DELETE | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id` | `commissioner/team_memberships#destroy` |
| GET | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers` | `commissioner/team_managers#index` |
| POST | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers` | `commissioner/team_managers#create` |
| PATCH | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id` | `commissioner/team_managers#update` |
| DELETE | `/api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id` | `commissioner/team_managers#destroy` |

### フロントエンド（Vue Router）

**チーム管理関連ルート（`src/router/index.ts`）:**

| パス | name | コンポーネント | メタ |
|------|------|-------------|------|
| `/teams` | `TeamList` | `TeamList.vue`（lazy load） | `requiresAuth: true` |
| `/teams/:teamId/members` | `TeamMembers` | `TeamMembers.vue`（lazy load） | `requiresAuth: true`, `title: 'チームメンバー登録'` |

**ナビゲーション:**
- チームメンバー編集画面 → 前画面: `router.back()` でブラウザバック
- チーム一覧 → チームメンバー編集: 直接的なリンクは未実装

---

## シリアライザー一覧

| シリアライザー | 継承元 | 属性 | 関連 | 用途 |
|-------------|--------|------|------|------|
| `TeamSerializer` | `ActiveModel::Serializer` | `id`, `name`, `short_name`, `is_active`, `has_season` | `has_one :director`, `has_many :coaches` | チーム一覧/詳細 |
| `TeamPlayerSerializer` | `PlayerSerializer` | PlayerSerializer属性 + `selected_cost_type`, `current_cost` | （PlayerSerializerの `has_many :cost_players`） | チームメンバー一覧（コスト情報付き） |
| `TeamMembershipSerializer` | `ActiveModel::Serializer` | `id`, `team_id`, `player_id`, `squad`, `selected_cost_type` | `belongs_to :player` | コミッショナー用メンバーシップ管理 |
| `TeamManagerSerializer` | `ActiveModel::Serializer` | `id`, `team_id`, `manager_id`, `role` | `belongs_to :manager` | コミッショナー用マネージャー管理 |

**TeamSerializer の `has_season` カスタム属性:**
```ruby
def has_season
  object.season.present?
end
```

---

## 既知の制約・未実装機能

### 1. スキーマとコントローラー実装の不整合（teams.manager_id）

**問題:** `teams` テーブルには `manager_id` カラム（NOT NULL、外部キー制約あり）が存在するが、現在のコントローラーでは `director_id` / `coach_ids` パラメータを使用して `team_managers` テーブル経由で監督・コーチを管理している。チーム作成時に `manager_id` の値が設定されるが、その後の監督変更では更新されないため、実データと乖離する。

**推奨対応:** マイグレーションで `teams.manager_id` カラムを削除し、すべての監督・コーチ管理を `team_managers` テーブルに統一。

---

### 2. チーム削除時のエラーハンドリング不足

**問題:** チームに紐づくシーズンが存在する場合、`Team#destroy` は `ActiveRecord::DeleteRestrictionError` を発生させるが、コントローラーでこのエラーをハンドリングしていない。

**影響:** 削除失敗時に 500 Internal Server Error が返却される。

**推奨対応:**
```ruby
def destroy
  @team.destroy
  head :no_content
rescue ActiveRecord::DeleteRestrictionError => e
  render json: { error: 'シーズンが紐づいているため削除できません' }, status: :unprocessable_entity
end
```

---

### 3. チーム一覧→チームメンバー編集へのナビゲーション未実装

**問題:** チーム一覧画面からチームメンバー編集画面（`/teams/:teamId/members`）へ直接遷移するリンク/ボタンが存在しない。

**推奨対応:** チーム一覧の操作列に「メンバー編集」アイコンを追加。

---

### 4. squad フィールドはチームメンバー編集画面で変更不可

**問題:** `team_memberships.squad` フィールドはチームメンバー編集画面では編集できない。新規追加された選手はデフォルト値（`"second"` = 2軍）のまま。

**仕様:** `squad` はシーズン運営中にロースター管理画面で動的に変更される。チーム作成時には設定不要であり、これは意図的な仕様。コミッショナー用エンドポイント（`commissioner/team_memberships#update`）では `squad` の更新が可能。

---

### 5. コストタイプのバリデーション不足

**問題:** `TeamMembership` モデルの `selected_cost_type` に対して `presence: true` のみのバリデーションがあり、値の範囲チェック（`inclusion`）が存在しない。

**影響:** 不正な値がデータベースに保存される可能性がある。

**推奨対応:**
```ruby
validates :selected_cost_type, inclusion: {
  in: %w(normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost),
  message: "%{value} is not a valid cost type"
}
```

---

### 6. チーム一覧の監督名表示の不整合

**問題:** `TeamList.vue:27` で `item.manager?.name` を参照しているが、`TeamSerializer` は `has_one :director` で監督情報を返却しており、`manager` プロパティは存在しない。`Team` 型定義にも `manager` プロパティはなく、`director?: Manager` が定義されている。

**影響:** 監督名が常に `-` と表示される可能性がある。

**推奨対応:**
```vue
<template v-slot:item.manager_name="{ item }">
  {{ item.director?.name || '-' }}
</template>
```

---

### 7. コスト一覧表選択が必須

**仕様:** チームメンバー編集画面では、コスト一覧表を選択しないと選手の追加・取得ができない。コスト管理がシステムの必須機能であるため、これは仕様通りの動作。

---

## まとめ

チーム管理機能は、チームの基本情報（名前・略称・監督・コーチ・活動状態）の管理と、チームに所属する選手（チームメンバーシップ）の管理を統合的に提供する。

**主要な特徴:**
- チーム一覧画面でのCRUD操作（`TeamsController` 5アクション）
- チームメンバー編集画面での選手追加・削除、コストタイプ選択（`TeamPlayersController` 一括更新方式）
- 守備適性情報付きメンバー一覧（`TeamMembershipsController`）
- 総コスト（最大200）・人数制限（最大50人）のリアルタイム計算
- 監督・コーチの複数管理（`team_managers` 中間テーブル + `TeamManager` モデル）
- 同一リーグ内での監督/コーチ兼任禁止バリデーション
- コミッショナー用の個別CRUD管理（`commissioner/team_memberships`, `commissioner/team_managers`）
- Vue 3 Composition API + Vuetify 3 によるリッチUI（`v-data-table`, `v-autocomplete`, `v-dialog`）

**既知の課題:**
- `teams.manager_id` カラムの遺留（コントローラーで使用されていない）
- チーム削除時の `DeleteRestrictionError` ハンドリング未実装
- チーム一覧の監督名表示の不整合（`manager?.name` → `director?.name`）
- `selected_cost_type` の値範囲バリデーション未実装
