# 12. コミッショナー機能仕様書

## 概要

コミッショナー機能は、リーグ運営を統括管理する権限を持つユーザー専用の機能群である。リーグ作成、シーズン管理、対戦表自動生成、参加チーム管理、選手プール管理、チームスタッフ管理、選手離脱管理など、リーグ運営に必要な全ての操作を包括する。

**主要な特徴:**
- コミッショナー権限による全APIエンドポイント保護（`Api::V1::Commissioner::BaseController` 継承による `commissioner?` チェック）
- リーグ/シーズン/対戦のCRUD操作
- ネストされたRESTfulリソース構造（leagues → league_seasons → league_games）
- 6チーム制総当たり対戦表の自動生成ロジック（各対戦3回、合計90試合）
- リーグメンバーシップによるチーム参加管理（重複登録防止）
- シーズン別選手プール管理（コストランク別フィルタリング対応）
- チーム監督・コーチの兼任制約（同一リーグ内の複数チーム兼任禁止）
- 選手離脱管理（怪我/出場停止/調整期間）
- フロントエンド: コミッショナーモードトグル、リーグ詳細パネル（タブ切替UI）、公式Wiki外部リンク

---

## 画面構成（フロントエンド）

### リーグ管理画面

**パス:** `/commissioner/leagues`（推定）

**コンポーネント:** `src/views/commissioner/LeaguesView.vue`

**レイアウト:**
```
┌───────────────────────────────────────────────────────┐
│  リーグ管理                                            │
├───────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐  │
│  │ リーグ一覧          [新規リーグ作成ボタン]      │  │
│  ├─────────────────────────────────────────────────┤  │
│  │ ID | リーグ名 | チーム数 | 試合数 | アクティブ │  │
│  │  1 | 第1期   |    6    |   30   |  ✓       │  │
│  │  2 | 第2期   |    6    |   30   |  □       │  │
│  │                      [編集] [削除]              │  │
│  └─────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘

[新規リーグ作成/編集ダイアログ]
┌───────────────────────────┐
│ リーグ編集                │
├───────────────────────────┤
│ リーグ名: [________]      │
│ チーム数: [6      ]       │
│ 試合数:   [30     ]       │
│ ☑ アクティブ              │
│                           │
│  [キャンセル]   [保存]    │
└───────────────────────────┘

[チーム管理ダイアログ]
┌───────────────────────────────┐
│ 第1期 のチーム管理            │
├───────────────────────────────┤
│ 追加するチーム: [選択▼]       │
│          [チームを追加]       │
│                               │
│ ┌─────────────────────────┐   │
│ │ チーム名         │ 操作 │   │
│ │ 紅魔館           │ [削] │   │
│ │ 白玉楼           │ [削] │   │
│ └─────────────────────────┘   │
│           [閉じる]            │
└───────────────────────────────┘
```

**データテーブルヘッダー:**

| key | title | sortable |
|-----|-------|----------|
| id | ID | yes |
| name | リーグ名 | yes |
| num_teams | チーム数 | yes |
| num_games | 試合数 | yes |
| active | アクティブ | yes |
| actions | 操作 | no |

**フォームフィールド（リーグ作成/編集）:**

| フィールドID | ラベル | 入力タイプ | v-model | デフォルト値 |
|-------------|--------|-----------|---------|------------|
| `name` | リーグ名 | text | `editedLeague.name` | '' |
| `num_teams` | チーム数 | number | `editedLeague.num_teams` | 6 |
| `num_games` | 試合数 | number | `editedLeague.num_games` | 30 |
| `active` | アクティブ | checkbox | `editedLeague.active` | false |

**フォームフィールド（チーム追加）:**

| フィールドID | ラベル | 入力タイプ | options | 備考 |
|-------------|--------|-----------|---------|------|
| `selectedTeamIdToAdd` | 追加するチーム | select | `availableTeams` | 既に参加済みのチームは除外表示 |

**動作フロー:**

**リーグ作成:**
```
[1] [新規リーグ作成] ボタンクリック
       ↓
[2] dialog=true, editedLeague=defaultLeague, editedIndex=-1
       ↓
[3] ユーザーがリーグ名/チーム数/試合数/アクティブ設定を入力
       ↓
[4] [保存] ボタンクリック → saveLeague() 実行
       ↓
[5] POST /commissioner/leagues にリーグデータ送信
       ↓
[6a] 成功時: leagues配列に追加、スナックバー表示、ダイアログ閉じる
       ↓
[6b] 失敗時: エラースナックバー表示
```

**リーグ編集:**
```
[1] テーブル行の [編集] アイコンクリック → editLeague(item)
       ↓
[2] dialog=true, editedLeague={...item}, editedIndex=配列インデックス
       ↓
[3] ユーザーが値を変更
       ↓
[4] [保存] ボタンクリック → saveLeague() 実行
       ↓
[5] PUT /commissioner/leagues/:id にリーグデータ送信
       ↓
[6a] 成功時: 配列内オブジェクト更新、スナックバー表示、ダイアログ閉じる
       ↓
[6b] 失敗時: エラースナックバー表示
```

**リーグ削除:**
```
[1] テーブル行の [削除] アイコンクリック → deleteLeague(item)
       ↓
[2] 確認ダイアログ表示: 「リーグ「XXX」を削除してもよろしいですか？」
       ↓
[3] ユーザーが [OK] をクリック
       ↓
[4] DELETE /commissioner/leagues/:id
       ↓
[5a] 成功時: leagues配列からフィルタ除去、スナックバー表示
       ↓
[5b] 失敗時: エラースナックバー表示
```

**チーム管理:**
```
[1] （未実装: ボタン未配置だが関数は存在）openMembershipDialog(league) 呼び出し
       ↓
[2] membershipDialog=true, selectedLeagueId=league.id
       ↓
[3] fetchLeagueTeams() で現在のリーグメンバー取得
       ↓
[4] fetchAvailableTeams() で全チーム取得し、既存メンバーを除外
       ↓
[5a] チーム追加: selectedTeamIdToAdd選択 → [チームを追加] クリック
       ↓     POST /commissioner/leagues/:league_id/league_memberships
       ↓     成功時: リスト再取得、選択解除、スナックバー表示
       ↓
[5b] チーム削除: [削] アイコンクリック → 確認ダイアログ
       ↓     DELETE /commissioner/leagues/:league_id/league_memberships/:id
       ↓     成功時: リスト再取得、スナックバー表示
       ↓
[6] [閉じる] でダイアログクローズ、state初期化
```

**TypeScript型定義（インライン）:**

```typescript
interface League {
  id?: number
  name: string
  num_teams: number
  num_games: number
  active: boolean
}

interface Team {
  id: number
  name: string
}

interface LeagueMembership {
  id: number
  team: Team
}

interface TeamManager {
  id: number
  team_id: number
  manager_id: number
  role: string
  manager: {
    id: number
    name: string
  }
}

interface LeagueSeason {
  id: number
  league_id: number
  name: string
  start_date: string
  end_date: string
  status: 'pending' | 'active' | 'completed'
}

interface LeagueGame {
  id: number
  league_season_id: number
  home_team_id: number
  away_team_id: number
  game_date: string
  game_number: number
  home_team: Team
  away_team: Team
}

interface LeaguePoolPlayer {
  id: number
  league_season_id: number
  player_id: number
  player: { id: number; name: string }
}
```

**スナックバーメッセージ:**
- 成功時:
  - `リーグを作成しました` (POST /leagues)
  - `リーグを更新しました` (PUT /leagues/:id)
  - `リーグを削除しました` (DELETE /leagues/:id)
  - `チームをリーグに追加しました` (POST /league_memberships)
  - `チームをリーグから削除しました` (DELETE /league_memberships/:id)
- 失敗時:
  - `リーグの取得に失敗しました` (GET /leagues)
  - `リーグの保存に失敗しました` (POST/PUT /leagues)
  - `リーグの削除に失敗しました` (DELETE /leagues/:id)
  - `リーグチームの取得に失敗しました` (GET /league_memberships)
  - `利用可能なチームの取得に失敗しました` (GET /teams)
  - `チームの追加に失敗しました` (POST /league_memberships)
  - `チームの削除に失敗しました` (DELETE /league_memberships/:id)

**注意事項:**
- チーム管理ダイアログはリーグ一覧テーブルのアイコンボタン（`mdi-account-group`）から開く
- リーグ詳細パネルはリーグ一覧テーブルの設定アイコン（`mdi-cog`）から開く

---

### リーグ詳細パネル

リーグ一覧テーブルから `mdi-cog` アイコンをクリックするとリーグ詳細パネルが展開される。5つのタブで構成される。

**レイアウト:**
```
┌───────────────────────────────────────────────────────┐
│ {リーグ名} - 詳細管理                          [✕]    │
├───────────────────────────────────────────────────────┤
│ [シーズン] [対戦] [選手プール] [チームスタッフ] [離脱] │
├───────────────────────────────────────────────────────┤
│                                                       │
│ （タブに応じたコンテンツ）                              │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**タブ一覧:**

| タブ値 | タイトル（i18nキー） | 内容 |
|--------|---------------------|------|
| `seasons` | `commissioner.detail.tabs.seasons` | シーズン一覧テーブル + スケジュール生成ボタン |
| `games` | `commissioner.detail.tabs.games` | シーズン選択 → 対戦データテーブル |
| `poolPlayers` | `commissioner.detail.tabs.poolPlayers` | シーズン選択 → 選手プール一覧 |
| `teamStaff` | `commissioner.detail.tabs.teamStaff` | チーム選択 → チームマネージャー一覧 |
| `absences` | `commissioner.detail.tabs.absences` | 離脱管理説明（情報アラート表示） |

**シーズンタブ:**
- `v-data-table` でシーズン一覧を表示（ヘッダー: シーズン名、開始日、終了日、ステータス、操作）
- ステータスは `commissioner.detail.seasonStatus.{pending|active|completed}` で表示
- 操作列にスケジュール生成ボタン

**対戦タブ:**
- シーズンを `v-select` で選択
- 選択後に対戦データテーブルを表示（ヘッダー: 試合日、ホームチーム名、アウェイチーム名、試合番号）

**選手プールタブ:**
- シーズンを `v-select` で選択
- 選択後に選手プール一覧を表示（ヘッダー: 選手名）

**チームスタッフタブ:**
- リーグ参加チームを `v-select` で選択
- 選択後にチームマネージャー一覧を表示（ヘッダー: 監督名、役割）

**離脱タブ:**
- `v-alert` で離脱管理の説明情報を表示

---

### トップメニュー画面のコミッショナー機能

**コンポーネント:** `src/views/TopMenu.vue`

**コミッショナーモード関連UI:**

1. **コミッショナーモードトグル (`v-switch`):**
   - `isCommissioner` が `true` の場合のみ表示
   - `localStorage` に `commissionerMode` として `'on'`/`'off'` を保存
   - ONにすると全チーム一覧を取得して表示（管理者は所属チームのみ → 全チーム表示に切替）
   - アイコン: `mdi-shield-crown`

2. **コミッショナーモードボタン:**
   - `isCommissioner` が `true` の場合のみ表示
   - クリックで `/commissioner/leagues`（リーグ管理画面）へ遷移
   - 色: `primary`、variant: `elevated`、prepend-icon: `mdi-shield-crown`

3. **チーム選択UI:**
   - コミッショナーモードOFF: ログインユーザーの所属チームのみ表示
   - コミッショナーモードON: 全チームを表示
   - ボタン形式でチームを選択（選択中はprimary色、それ以外はoutlined）
   - チーム選択で `localStorage` にIDを保存し、シーズンポータルへ遷移

4. **公式Wikiリンクカード:**
   - `v-card` (variant="tonal", color="primary", hover)
   - 外部リンク: `https://thbigbaseball.wiki.fc2.com/`
   - アイコン: `mdi-baseball-diamond`（左）、`mdi-open-in-new`（右）
   - i18nキー: `topMenu.officialWiki.title`, `topMenu.officialWiki.subtitle`

---

## APIエンドポイント

### 共通仕様

**認証:** 全エンドポイントでコミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

```ruby
# app/controllers/api/v1/commissioner/base_controller.rb
class Api::V1::Commissioner::BaseController < Api::V1::BaseController
  before_action :check_commissioner

  private

  def check_commissioner
    head :forbidden unless current_user.commissioner?
  end
end
```

全てのコミッショナーエンドポイントは `before_action :check_commissioner` により、`current_user.commissioner?` が `false` の場合 `403 Forbidden` を返却する。

---

### 1. リーグ一覧取得

**エンドポイント:** `GET /api/v1/commissioner/leagues`

**コントローラー:** `Api::V1::Commissioner::LeaguesController#index`

**認証:** コミッショナー権限必須

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "name": "第1期リーグ",
    "num_teams": 6,
    "num_games": 30,
    "active": true,
    "created_at": "2024-11-04T12:00:00.000Z",
    "updated_at": "2024-11-04T12:00:00.000Z"
  },
  {
    "id": 2,
    "name": "第2期リーグ",
    "num_teams": 6,
    "num_games": 30,
    "active": false,
    "created_at": "2024-11-05T12:00:00.000Z",
    "updated_at": "2024-11-05T12:00:00.000Z"
  }
]
```

**処理フロー:**
```
[1] League.all で全リーグ取得
       ↓
[2] JSON形式でレスポンス返却（デフォルトシリアライザー使用）
```

---

### 2. リーグ詳細取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:id`

**コントローラー:** `Api::V1::Commissioner::LeaguesController#show`

**認証:** コミッショナー権限必須

**リクエスト:** なし（パスパラメータのみ）

**レスポンス（200 OK）:**
```json
{
  "id": 1,
  "name": "第1期リーグ",
  "num_teams": 6,
  "num_games": 30,
  "active": true,
  "created_at": "2024-11-04T12:00:00.000Z",
  "updated_at": "2024-11-04T12:00:00.000Z"
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:id])
       ↓
[2] @league をJSON形式でレスポンス返却
```

---

### 3. リーグ作成

**エンドポイント:** `POST /api/v1/commissioner/leagues`

**コントローラー:** `Api::V1::Commissioner::LeaguesController#create`

**認証:** コミッショナー権限必須

**リクエスト:**
```json
{
  "league": {
    "name": "第3期リーグ",
    "num_teams": 6,
    "num_games": 30,
    "active": false
  }
}
```

**許可パラメータ:**
- `name` (string, required)
- `num_teams` (integer, required, > 0)
- `num_games` (integer, required, > 0)
- `active` (boolean, optional)

**レスポンス（成功時 201 Created）:**
```json
{
  "id": 3,
  "name": "第3期リーグ",
  "num_teams": 6,
  "num_games": 30,
  "active": false,
  "created_at": "2024-11-06T12:00:00.000Z",
  "updated_at": "2024-11-06T12:00:00.000Z"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "name": ["を入力してください"],
  "num_teams": ["は0より大きい値にしてください"]
}
```

**処理フロー:**
```
[1] league_params でパラメータ取得（:name, :num_teams, :num_games, :active）
       ↓
[2] League.new(league_params) でインスタンス生成
       ↓
[3a] league.save 成功時: 201 Created, 作成したリーグをJSON返却
       ↓
[3b] league.save 失敗時: 422 Unprocessable Entity, league.errors をJSON返却
```

---

### 4. リーグ更新

**エンドポイント:** `PUT /api/v1/commissioner/leagues/:id`

**コントローラー:** `Api::V1::Commissioner::LeaguesController#update`

**認証:** コミッショナー権限必須

**リクエスト:**
```json
{
  "league": {
    "name": "第3期リーグ（修正版）",
    "active": true
  }
}
```

**許可パラメータ:**
- `name`, `num_teams`, `num_games`, `active` (部分更新可)

**レスポンス（成功時 200 OK）:**
```json
{
  "id": 3,
  "name": "第3期リーグ（修正版）",
  "num_teams": 6,
  "num_games": 30,
  "active": true,
  "created_at": "2024-11-06T12:00:00.000Z",
  "updated_at": "2024-11-06T13:00:00.000Z"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "num_teams": ["は0より大きい値にしてください"]
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:id])
       ↓
[2] league_params でパラメータ取得
       ↓
[3a] @league.update(league_params) 成功時: 200 OK, 更新したリーグをJSON返却
       ↓
[3b] @league.update 失敗時: 422 Unprocessable Entity, @league.errors をJSON返却
```

---

### 5. リーグ削除

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:id`

**コントローラー:** `Api::V1::Commissioner::LeaguesController#destroy`

**認証:** コミッショナー権限必須

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "base": ["削除できません"]
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:id])
       ↓
[2a] @league.destroy 成功時: 204 No Content
       ↓
[2b] @league.destroy 失敗時: 422 Unprocessable Entity, @league.errors をJSON返却
```

**注意:** リーグに紐づくリーグメンバーシップは `dependent: :destroy` により自動削除される。

---

### 6. リーグメンバーシップ一覧取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/league_memberships`

**コントローラー:** `Api::V1::Commissioner::LeagueMembershipsController#index`

**認証:** コミッショナー権限必須

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "league_id": 1,
    "team_id": 10,
    "created_at": "2024-11-04T12:00:00.000Z",
    "updated_at": "2024-11-04T12:00:00.000Z",
    "team": {
      "id": 10,
      "name": "紅魔館",
      "short_name": "紅魔",
      "is_active": true
    }
  },
  {
    "id": 2,
    "league_id": 1,
    "team_id": 11,
    "created_at": "2024-11-04T12:00:00.000Z",
    "updated_at": "2024-11-04T12:00:00.000Z",
    "team": {
      "id": 11,
      "name": "白玉楼",
      "short_name": "白玉",
      "is_active": true
    }
  }
]
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] @league.league_memberships.includes(:team) で関連チーム含めて取得
       ↓
[3] JSON形式でレスポンス返却（include: :team でチーム情報含む）
```

---

### 7. リーグメンバーシップ作成（チームをリーグに追加）

**エンドポイント:** `POST /api/v1/commissioner/leagues/:league_id/league_memberships`

**コントローラー:** `Api::V1::Commissioner::LeagueMembershipsController#create`

**認証:** コミッショナー権限必須

**リクエスト:**
```json
{
  "league_membership": {
    "team_id": 12
  }
}
```

**許可パラメータ:**
- `team_id` (integer, required)

**レスポンス（成功時 201 Created）:**
```json
{
  "id": 3,
  "league_id": 1,
  "team_id": 12,
  "created_at": "2024-11-06T12:00:00.000Z",
  "updated_at": "2024-11-06T12:00:00.000Z"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "league_id": ["は既に存在します"]
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] league_membership_params で :team_id 取得
       ↓
[3] @league.league_memberships.build(league_membership_params)
       ↓
[4a] league_membership.save 成功時: 201 Created, 作成したメンバーシップをJSON返却
       ↓
[4b] league_membership.save 失敗時: 422 Unprocessable Entity, league_membership.errors をJSON返却
```

**バリデーション:**
- `league_id` と `team_id` の組み合わせが一意であること（`validates :league_id, uniqueness: { scope: :team_id }`）

---

### 8. リーグメンバーシップ削除（チームをリーグから除外）

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:league_id/league_memberships/:id`

**コントローラー:** `Api::V1::Commissioner::LeagueMembershipsController#destroy`

**認証:** コミッショナー権限必須

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "base": ["削除できません"]
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] @league.league_memberships.find(params[:id]) でメンバーシップ取得
       ↓
[3a] league_membership.destroy 成功時: 204 No Content
       ↓
[3b] league_membership.destroy 失敗時: 422 Unprocessable Entity, league_membership.errors をJSON返却
```

---

### 9. リーグシーズン一覧取得（リーグ別）

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/league_seasons`

**コントローラー:** `Api::V1::Commissioner::LeagueSeasonsController#index`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "league_id": 1,
    "name": "2024年秋季シーズン",
    "start_date": "2024-11-01",
    "end_date": "2024-12-31",
    "status": "active"
  },
  {
    "id": 2,
    "league_id": 1,
    "name": "2025年春季シーズン",
    "start_date": "2025-03-01",
    "end_date": "2025-05-31",
    "status": "pending"
  }
]
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] @league.league_seasons でリーグに紐づくシーズンのみ取得
       ↓
[3] JSON形式でレスポンス返却
```

---

### 10. リーグシーズン詳細取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/league_seasons/:id`

**コントローラー:** `Api::V1::Commissioner::LeagueSeasonsController#show`

**認証:** コミッショナー権限必須

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
{
  "id": 1,
  "league_id": 1,
  "name": "2024年秋季シーズン",
  "start_date": "2024-11-01",
  "end_date": "2024-12-31",
  "status": "active"
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] before_action :set_league_season で @league.league_seasons.find(params[:id])
       ↓
[3] @league_season をJSON形式でレスポンス返却
```

---

### 11. リーグシーズン作成

**エンドポイント:** `POST /api/v1/commissioner/leagues/:league_id/league_seasons`

**コントローラー:** `Api::V1::Commissioner::LeagueSeasonsController#create`

**認証:** コミッショナー権限必須

**リクエスト:**
```json
{
  "league_season": {
    "name": "2025年夏季シーズン",
    "start_date": "2025-06-01",
    "end_date": "2025-08-31",
    "status": "pending"
  }
}
```

**許可パラメータ:**
- `name` (string, required)
- `start_date` (date, required)
- `end_date` (date, required, >= start_date)
- `status` (integer, required: 0=pending, 1=active, 2=completed)

**レスポンス（成功時 201 Created）:**
```json
{
  "id": 3,
  "league_id": 1,
  "name": "2025年夏季シーズン",
  "start_date": "2025-06-01",
  "end_date": "2025-08-31",
  "status": "pending"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "name": ["を入力してください"],
  "end_date": ["は開始日以降の日付にしてください"]
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] league_season_params で許可パラメータ取得
       ↓
[3] @league.league_seasons.build(league_season_params)
       ↓
[4a] @league_season.save 成功時: 201 Created, JSON返却
       ↓
[4b] @league_season.save 失敗時: 422 Unprocessable Entity, errors返却
```

---

### 12. リーグシーズン更新

**エンドポイント:** `PUT /api/v1/commissioner/leagues/:league_id/league_seasons/:id`

**コントローラー:** `Api::V1::Commissioner::LeagueSeasonsController#update`

**認証:** コミッショナー権限必須

**リクエスト:**
```json
{
  "league_season": {
    "status": "active"
  }
}
```

**許可パラメータ:** `name`, `start_date`, `end_date`, `status` (部分更新可)

**レスポンス（成功時 200 OK）:**
```json
{
  "id": 2,
  "league_id": 1,
  "name": "2025年春季シーズン",
  "start_date": "2025-03-01",
  "end_date": "2025-05-31",
  "status": "active"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "status": ["が不正です"]
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] before_action :set_league_season で @league.league_seasons.find(params[:id])
       ↓
[3] league_season_params で許可パラメータ取得
       ↓
[4a] @league_season.update(league_season_params) 成功時: 200 OK, JSON返却
       ↓
[4b] @league_season.update 失敗時: 422 Unprocessable Entity, errors返却
```

---

### 13. リーグシーズン削除

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:league_id/league_seasons/:id`

**コントローラー:** `Api::V1::Commissioner::LeagueSeasonsController#destroy`

**認証:** コミッショナー権限必須

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] before_action :set_league_season で @league.league_seasons.find(params[:id])
       ↓
[3] @league_season.destroy
       ↓
[4] 204 No Content
```

**注意:** リーグシーズンに紐づくリーグ対戦（`league_games`）と選手プール（`league_pool_players`）は `dependent: :destroy` により自動削除される。

---

### 14. 対戦表自動生成

**エンドポイント:** `POST /api/v1/commissioner/leagues/:league_id/league_seasons/:id/generate_schedule`

**コントローラー:** `Api::V1::Commissioner::LeagueSeasonsController#generate_schedule`

**認証:** コミッショナー権限必須

**リクエスト:** なし（パスパラメータのみ）

**レスポンス（成功時 200 OK）:**
```json
{
  "message": "Schedule generated successfully"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "error": "チーム数が6チームではありません"
}
```

**処理フロー:**
```
[1] before_action :set_league で League.find(params[:league_id])
       ↓
[2] before_action :set_league_season で @league.league_seasons.find(params[:id])
       ↓
[3] @league_season.generate_schedule メソッド実行
       ↓
[4a] 成功時: 200 OK, message返却
       ↓
[4b] 例外発生時: 422 Unprocessable Entity, error返却
```

**`generate_schedule` ビジネスロジック（LeagueSeasonモデル）:**
```ruby
def generate_schedule
  teams = league.teams.to_a # リーグに所属するチームを取得
  return if teams.size != 6 # 6チーム制であることを確認

  current_date = start_date
  game_count = 0

  # 総当たり組み合わせを生成
  teams.combination(2).each do |team1, team2|
    # team1 ホーム vs team2 アウェイ （3試合）
    3.times do |i|
      if game_count > 0 && game_count % 6 == 0
        current_date += 1.day # 6試合ごとに1日休養日
      end
      LeagueGame.create!(
        league_season: self,
        home_team: team1,
        away_team: team2,
        game_date: current_date,
        game_number: i + 1
      )
      game_count += 1
      current_date += 1.day # 試合ごとに日付を進める
    end

    # team2 ホーム vs team1 アウェイ （3試合）
    3.times do |i|
      if game_count > 0 && game_count % 6 == 0
        current_date += 1.day # 6試合ごとに1日休養日
      end
      LeagueGame.create!(
        league_season: self,
        home_team: team2,
        away_team: team1,
        game_date: current_date,
        game_number: i + 1
      )
      game_count += 1
      current_date += 1.day # 試合ごとに日付を進める
    end
  end
end
```

**生成ロジック詳細:**
- 6チーム総当たり: 各対戦カードで「ホーム3試合」「アウェイ3試合」= 合計6試合/カード
- 組み合わせ数: 6C2 = 15カード
- 総試合数: 15カード × 6試合/カード = 90試合
- 休養日: 6試合ごとに1日休養日を挿入
- 試合番号（`game_number`）: 同一対戦カードの何試合目かを示す（1〜3）

---

### 15. リーグ対戦一覧取得（シーズン別）

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_games`

**コントローラー:** `Api::V1::Commissioner::LeagueGamesController#index`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "league_season_id": 1,
    "home_team_id": 10,
    "away_team_id": 11,
    "game_date": "2024-11-01",
    "game_number": 1,
    "home_team": {
      "id": 10,
      "name": "紅魔館"
    },
    "away_team": {
      "id": 11,
      "name": "白玉楼"
    }
  },
  {
    "id": 2,
    "league_season_id": 1,
    "home_team_id": 10,
    "away_team_id": 11,
    "game_date": "2024-11-02",
    "game_number": 2,
    "home_team": {
      "id": 10,
      "name": "紅魔館"
    },
    "away_team": {
      "id": 11,
      "name": "白玉楼"
    }
  }
]
```

**シリアライザー:** `LeagueGameSerializer`
- 出力属性: `id`, `league_season_id`, `home_team_id`, `away_team_id`, `game_date`, `game_number`
- アソシエーション: `home_team`, `away_team`

**処理フロー:**
```
[1] before_action :set_league_season で LeagueSeason.find(params[:league_season_id])
       ↓
[2] @league_season.league_games で関連する全対戦取得
       ↓
[3] JSON形式でレスポンス返却（LeagueGameSerializer使用、チーム情報含む）
```

---

### 16. リーグ対戦詳細取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_games/:id`

**コントローラー:** `Api::V1::Commissioner::LeagueGamesController#show`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
{
  "id": 1,
  "league_season_id": 1,
  "home_team_id": 10,
  "away_team_id": 11,
  "game_date": "2024-11-01",
  "game_number": 1,
  "home_team": {
    "id": 10,
    "name": "紅魔館"
  },
  "away_team": {
    "id": 11,
    "name": "白玉楼"
  }
}
```

**処理フロー:**
```
[1] before_action :set_league_season で LeagueSeason.find(params[:league_season_id])
       ↓
[2] before_action :set_league_game で @league_season.league_games.find(params[:id])
       ↓
[3] @league_game をJSON形式でレスポンス返却
```

---

### 17. 選手プール一覧取得（シーズン別、コストランク別フィルタ可）

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_pool_players`

**コントローラー:** `Api::V1::Commissioner::LeaguePoolPlayersController#index`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**クエリパラメータ（オプション）:**
- `cost_rank`: コストランクフィルタ（`A` / `B` / `C`）

**リクエスト例:**
```
GET /api/v1/commissioner/league_seasons/1/league_pool_players?cost_rank=A
```

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "league_season_id": 1,
    "player_id": 100,
    "player": {
      "id": 100,
      "name": "レミリア・スカーレット",
      "cost_players": [
        {
          "cost": {
            "normal_cost": 9
          }
        }
      ]
    }
  },
  {
    "id": 2,
    "league_season_id": 1,
    "player_id": 101,
    "player": {
      "id": 101,
      "name": "フランドール・スカーレット",
      "cost_players": [
        {
          "cost": {
            "normal_cost": 8
          }
        }
      ]
    }
  }
]
```

**シリアライザー:** `LeaguePoolPlayerSerializer`
- 出力属性: `id`, `league_season_id`, `player_id`
- アソシエーション: `player`

**処理フロー:**
```
[1] before_action :set_league_season で LeagueSeason.find(params[:league_season_id])
       ↓
[2] @league_season.pool_players で関連選手取得（through: :league_pool_players）
       ↓
[3] params[:cost_rank]が存在する場合、filter_by_cost_rank(@pool_players, params[:cost_rank]) でフィルタ
       ↓
[4] JSON形式でレスポンス返却（LeaguePoolPlayerSerializer使用）
```

**コストランクフィルタリングロジック:**
```ruby
def filter_by_cost_rank(players, cost_rank)
  case cost_rank.upcase
  when 'A'
    players.joins(cost_players: :cost).where('costs.normal_cost >= ?', 8)
  when 'B'
    players.joins(cost_players: :cost).where('costs.normal_cost BETWEEN ? AND ?', 5, 7)
  when 'C'
    players.joins(cost_players: :cost).where('costs.normal_cost <= ?', 4)
  else
    players # 不明なランクの場合はフィルタリングしない
  end
end
```

**コストランク定義:**
- **Aランク:** `normal_cost >= 8`
- **Bランク:** `normal_cost BETWEEN 5 AND 7`
- **Cランク:** `normal_cost <= 4`

---

### 18. 選手プール追加

**エンドポイント:** `POST /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_pool_players`

**コントローラー:** `Api::V1::Commissioner::LeaguePoolPlayersController#create`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:**
```json
{
  "league_pool_player": {
    "player_id": 102
  }
}
```

**許可パラメータ:**
- `player_id` (integer, required)

**レスポンス（成功時 201 Created）:**
```json
{
  "id": 3,
  "league_season_id": 1,
  "player_id": 102
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "league_season_id": ["は既に選手プールに登録されています"]
}
```

**処理フロー:**
```
[1] before_action :set_league_season で LeagueSeason.find(params[:league_season_id])
       ↓
[2] league_pool_player_params で :player_id 取得
       ↓
[3] @league_season.league_pool_players.build(league_pool_player_params)
       ↓
[4a] @league_pool_player.save 成功時: 201 Created, JSON返却
       ↓
[4b] @league_pool_player.save 失敗時: 422 Unprocessable Entity, errors返却
```

**バリデーション:**
- `league_season_id` と `player_id` の組み合わせが一意（`validates :league_season_id, uniqueness: { scope: :player_id, message: 'は既に選手プールに登録されています' }`）

---

### 19. 選手プール削除

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_pool_players/:id`

**コントローラー:** `Api::V1::Commissioner::LeaguePoolPlayersController#destroy`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**処理フロー:**
```
[1] before_action :set_league_season で LeagueSeason.find(params[:league_season_id])
       ↓
[2] before_action :set_league_pool_player で @league_season.league_pool_players.find(params[:id])
       ↓
[3] @league_pool_player.destroy
       ↓
[4] 204 No Content
```

---

### 20. チームマネージャー一覧取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers`

**コントローラー:** `Api::V1::Commissioner::TeamManagersController#index`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "team_id": 10,
    "manager_id": 5,
    "role": "director",
    "manager": {
      "id": 5,
      "name": "レミリア",
      "short_name": "レミ",
      "irc_name": "Remilia"
    }
  },
  {
    "id": 2,
    "team_id": 10,
    "manager_id": 6,
    "role": "coach",
    "manager": {
      "id": 6,
      "name": "咲夜",
      "short_name": "咲",
      "irc_name": "Sakuya"
    }
  }
]
```

**シリアライザー:** `TeamManagerSerializer`
- 出力属性: `id`, `team_id`, `manager_id`, `role`
- アソシエーション: `manager`

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] @team.team_managers.includes(:manager) で関連マネージャー含めて取得
       ↓
[3] JSON形式でレスポンス返却（TeamManagerSerializer使用）
```

---

### 21. チームマネージャー詳細取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id`

**コントローラー:** `Api::V1::Commissioner::TeamManagersController#show`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
{
  "id": 1,
  "team_id": 10,
  "manager_id": 5,
  "role": "director",
  "manager": {
    "id": 5,
    "name": "レミリア",
    "short_name": "レミ",
    "irc_name": "Remilia"
  }
}
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] before_action :set_team_manager で @team.team_managers.find(params[:id])
       ↓
[3] @team_manager をJSON形式でレスポンス返却
```

---

### 22. チームマネージャー作成

**エンドポイント:** `POST /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers`

**コントローラー:** `Api::V1::Commissioner::TeamManagersController#create`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:**
```json
{
  "team_manager": {
    "manager_id": 7,
    "role": "coach"
  }
}
```

**許可パラメータ:**
- `manager_id` (integer, required)
- `role` (string/integer, required: "director" / "coach" or 0 / 1)

**レスポンス（成功時 201 Created）:**
```json
{
  "id": 3,
  "team_id": 10,
  "manager_id": 7,
  "role": "coach"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "team_id": ["には既に監督が設定されています"]
}
```

または

```json
{
  "manager_id": ["は同一リーグ内の複数のチームに兼任することはできません"]
}
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] team_manager_params で :manager_id, :role 取得
       ↓
[3] @team.team_managers.build(team_manager_params)
       ↓
[4a] @team_manager.save 成功時: 201 Created, JSON返却
       ↓
[4b] @team_manager.save 失敗時: 422 Unprocessable Entity, errors返却
```

**バリデーション:**
- `role` は必須（0=director, 1=coach）
- `role` が `director` の場合、同一チームに既に監督が設定されていないこと（`validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: 'には既に監督が設定されています' }`）
- カスタムバリデーション: 同一リーグ内の他チームに同じマネージャーが既に割り当てられていないこと

**カスタムバリデーション詳細:**
```ruby
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

---

### 23. チームマネージャー更新

**エンドポイント:** `PUT /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id`

**コントローラー:** `Api::V1::Commissioner::TeamManagersController#update`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:**
```json
{
  "team_manager": {
    "role": "director"
  }
}
```

**許可パラメータ:** `manager_id`, `role` (部分更新可)

**レスポンス（成功時 200 OK）:**
```json
{
  "id": 3,
  "team_id": 10,
  "manager_id": 7,
  "role": "director"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "team_id": ["には既に監督が設定されています"]
}
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] before_action :set_team_manager で @team.team_managers.find(params[:id])
       ↓
[3] team_manager_params で許可パラメータ取得
       ↓
[4a] @team_manager.update(team_manager_params) 成功時: 200 OK, JSON返却
       ↓
[4b] @team_manager.update 失敗時: 422 Unprocessable Entity, errors返却
```

---

### 24. チームマネージャー削除

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id`

**コントローラー:** `Api::V1::Commissioner::TeamManagersController#destroy`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] before_action :set_team_manager で @team.team_managers.find(params[:id])
       ↓
[3] @team_manager.destroy
       ↓
[4] 204 No Content
```

---

### 25. チームメンバーシップ一覧取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships`

**コントローラー:** `Api::V1::Commissioner::TeamMembershipsController#index`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "team_id": 10,
    "player_id": 100,
    "squad": "first",
    "selected_cost_type": "normal_cost",
    "player": {
      "id": 100,
      "name": "レミリア・スカーレット"
    }
  },
  {
    "id": 2,
    "team_id": 10,
    "player_id": 101,
    "squad": "second",
    "selected_cost_type": "normal_cost",
    "player": {
      "id": 101,
      "name": "フランドール・スカーレット"
    }
  }
]
```

**シリアライザー:** `TeamMembershipSerializer`
- 出力属性: `id`, `team_id`, `player_id`, `squad`, `selected_cost_type`
- アソシエーション: `player`

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] @team.team_memberships.includes(:player) で関連選手含めて取得
       ↓
[3] JSON形式でレスポンス返却（TeamMembershipSerializer使用）
```

---

### 26. チームメンバーシップ詳細取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id`

**コントローラー:** `Api::V1::Commissioner::TeamMembershipsController#show`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
{
  "id": 1,
  "team_id": 10,
  "player_id": 100,
  "squad": "first",
  "selected_cost_type": "normal_cost",
  "player": {
    "id": 100,
    "name": "レミリア・スカーレット"
  }
}
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] before_action :set_team_membership で @team.team_memberships.find(params[:id])
       ↓
[3] @team_membership をJSON形式でレスポンス返却
```

---

### 27. チームメンバーシップ更新

**エンドポイント:** `PUT /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id`

**コントローラー:** `Api::V1::Commissioner::TeamMembershipsController#update`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:**
```json
{
  "team_membership": {
    "squad": "first",
    "selected_cost_type": "special_cost"
  }
}
```

**許可パラメータ:**
- `squad` (string, required: "first" / "second")
- `selected_cost_type` (string, required)

**レスポンス（成功時 200 OK）:**
```json
{
  "id": 2,
  "team_id": 10,
  "player_id": 101,
  "squad": "first",
  "selected_cost_type": "special_cost"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "squad": ["は一覧にありません"]
}
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] before_action :set_team_membership で @team.team_memberships.find(params[:id])
       ↓
[3] team_membership_params で :squad, :selected_cost_type 取得
       ↓
[4a] @team_membership.update(team_membership_params) 成功時: 200 OK, JSON返却
       ↓
[4b] @team_membership.update 失敗時: 422 Unprocessable Entity, errors返却
```

**バリデーション:**
- `squad` は "first" または "second" のいずれか（`validates :squad, inclusion: { in: %w(first second) }`）
- `selected_cost_type` は必須

---

### 28. チームメンバーシップ削除

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id`

**コントローラー:** `Api::V1::Commissioner::TeamMembershipsController#destroy`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**処理フロー:**
```
[1] before_action :set_team で Team.find(params[:team_id])
       ↓
[2] before_action :set_team_membership で @team.team_memberships.find(params[:id])
       ↓
[3] @team_membership.destroy
       ↓
[4] 204 No Content
```

---

### 29. 選手離脱一覧取得（チームメンバーシップ別）

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences`

**コントローラー:** `Api::V1::Commissioner::PlayerAbsencesController#index`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
[
  {
    "id": 1,
    "team_membership_id": 1,
    "season_id": 10,
    "absence_type": "injury",
    "reason": "左足首捻挫",
    "start_date": "2024-11-10",
    "duration": 3,
    "duration_unit": "games",
    "player_name": "レミリア・スカーレット"
  },
  {
    "id": 2,
    "team_membership_id": 1,
    "season_id": 10,
    "absence_type": "suspension",
    "reason": "退場処分",
    "start_date": "2024-11-15",
    "duration": 1,
    "duration_unit": "games",
    "player_name": "レミリア・スカーレット"
  }
]
```

**シリアライザー:** `PlayerAbsenceSerializer`
- 出力属性: `id`, `team_membership_id`, `season_id`, `absence_type`, `reason`, `start_date`, `duration`, `duration_unit`, `player_name`
- `player_name` はカスタム属性（`object.team_membership.player.name` から取得）

**処理フロー:**
```
[1] before_action :set_team_membership で TeamMembership.find(params[:team_membership_id])
       ↓
[2] @team_membership.player_absences で関連する全離脱情報取得
       ↓
[3] JSON形式でレスポンス返却（PlayerAbsenceSerializer使用）
```

---

### 30. 選手離脱詳細取得

**エンドポイント:** `GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences/:id`

**コントローラー:** `Api::V1::Commissioner::PlayerAbsencesController#show`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（200 OK）:**
```json
{
  "id": 1,
  "team_membership_id": 1,
  "season_id": 10,
  "absence_type": "injury",
  "reason": "左足首捻挫",
  "start_date": "2024-11-10",
  "duration": 3,
  "duration_unit": "games",
  "player_name": "レミリア・スカーレット"
}
```

**処理フロー:**
```
[1] before_action :set_team_membership で TeamMembership.find(params[:team_membership_id])
       ↓
[2] before_action :set_player_absence で @team_membership.player_absences.find(params[:id])
       ↓
[3] @player_absence をJSON形式でレスポンス返却
```

---

### 31. 選手離脱作成

**エンドポイント:** `POST /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences`

**コントローラー:** `Api::V1::Commissioner::PlayerAbsencesController#create`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:**
```json
{
  "player_absence": {
    "season_id": 10,
    "absence_type": "injury",
    "start_date": "2024-11-20",
    "duration": 5,
    "duration_unit": "days"
  }
}
```

**許可パラメータ:**
- `season_id` (integer, required)
- `absence_type` (string/integer, required: "injury" / "suspension" / "reconditioning" or 0 / 1 / 2)
- `start_date` (date, required)
- `duration` (integer, required, > 0)
- `duration_unit` (string, required: "days" / "games")

**レスポンス（成功時 201 Created）:**
```json
{
  "id": 3,
  "team_membership_id": 1,
  "season_id": 10,
  "absence_type": "injury",
  "reason": null,
  "start_date": "2024-11-20",
  "duration": 5,
  "duration_unit": "days",
  "player_name": "レミリア・スカーレット"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "absence_type": ["を入力してください"],
  "duration": ["は0より大きい値にしてください"]
}
```

**処理フロー:**
```
[1] before_action :set_team_membership で TeamMembership.find(params[:team_membership_id])
       ↓
[2] player_absence_params で許可パラメータ取得
       ↓
[3] @team_membership.player_absences.build(player_absence_params)
       ↓
[4a] @player_absence.save 成功時: 201 Created, JSON返却
       ↓
[4b] @player_absence.save 失敗時: 422 Unprocessable Entity, errors返却
```

**バリデーション:**
- `absence_type` は必須（0=injury, 1=suspension, 2=reconditioning）
- `start_date` は必須
- `duration` は必須かつ正の整数
- `duration_unit` は必須かつ "days" または "games" のいずれか（`validates :duration_unit, presence: true, inclusion: { in: %w(days games) }`）

---

### 32. 選手離脱更新

**エンドポイント:** `PUT /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences/:id`

**コントローラー:** `Api::V1::Commissioner::PlayerAbsencesController#update`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:**
```json
{
  "player_absence": {
    "duration": 7
  }
}
```

**許可パラメータ:** `season_id`, `absence_type`, `start_date`, `duration`, `duration_unit` (部分更新可)

**レスポンス（成功時 200 OK）:**
```json
{
  "id": 3,
  "team_membership_id": 1,
  "season_id": 10,
  "absence_type": "injury",
  "reason": null,
  "start_date": "2024-11-20",
  "duration": 7,
  "duration_unit": "days",
  "player_name": "レミリア・スカーレット"
}
```

**レスポンス（失敗時 422 Unprocessable Entity）:**
```json
{
  "duration_unit": ["は一覧にありません"]
}
```

**処理フロー:**
```
[1] before_action :set_team_membership で TeamMembership.find(params[:team_membership_id])
       ↓
[2] before_action :set_player_absence で @team_membership.player_absences.find(params[:id])
       ↓
[3] player_absence_params で許可パラメータ取得
       ↓
[4a] @player_absence.update(player_absence_params) 成功時: 200 OK, JSON返却
       ↓
[4b] @player_absence.update 失敗時: 422 Unprocessable Entity, errors返却
```

---

### 33. 選手離脱削除

**エンドポイント:** `DELETE /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:team_membership_id/player_absences/:id`

**コントローラー:** `Api::V1::Commissioner::PlayerAbsencesController#destroy`

**認証:** コミッショナー権限必須（`Api::V1::Commissioner::BaseController` 継承）

**リクエスト:** なし

**レスポンス（成功時 204 No Content）:**
```
（レスポンスボディなし）
```

**処理フロー:**
```
[1] before_action :set_team_membership で TeamMembership.find(params[:team_membership_id])
       ↓
[2] before_action :set_player_absence で @team_membership.player_absences.find(params[:id])
       ↓
[3] @player_absence.destroy
       ↓
[4] 204 No Content
```

---

## データモデル

### テーブル定義（db/schema.rb）

#### leagues テーブル

```ruby
create_table "leagues", force: :cascade do |t|
  t.string "name", null: false
  t.integer "num_teams", default: 6, null: false
  t.integer "num_games", default: 30, null: false
  t.boolean "active", default: false, null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
end
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| name | string | NO | - | リーグ名 |
| num_teams | integer | NO | 6 | 参加チーム数 |
| num_games | integer | NO | 30 | 試合数 |
| active | boolean | NO | false | アクティブフラグ |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

#### league_seasons テーブル

```ruby
create_table "league_seasons", force: :cascade do |t|
  t.bigint "league_id", null: false
  t.string "name", null: false
  t.date "start_date", null: false
  t.date "end_date", null: false
  t.integer "status", default: 0, null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["league_id"], name: "index_league_seasons_on_league_id"
end
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| league_id | bigint | NO | - | FK: leagues.id |
| name | string | NO | - | シーズン名 |
| start_date | date | NO | - | 開始日 |
| end_date | date | NO | - | 終了日 |
| status | integer | NO | 0 | シーズン状態（0=pending, 1=active, 2=completed） |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_league_seasons_on_league_id` (league_id)

#### league_games テーブル

```ruby
create_table "league_games", force: :cascade do |t|
  t.bigint "league_season_id", null: false
  t.bigint "home_team_id", null: false
  t.bigint "away_team_id", null: false
  t.date "game_date", null: false
  t.integer "game_number", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["away_team_id"], name: "index_league_games_on_away_team_id"
  t.index ["home_team_id"], name: "index_league_games_on_home_team_id"
  t.index ["league_season_id"], name: "index_league_games_on_league_season_id"
end
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| league_season_id | bigint | NO | - | FK: league_seasons.id |
| home_team_id | bigint | NO | - | FK: teams.id（ホームチーム） |
| away_team_id | bigint | NO | - | FK: teams.id（アウェイチーム） |
| game_date | date | NO | - | 試合日 |
| game_number | integer | NO | - | 同一対戦カード内の試合番号（1〜3） |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_league_games_on_league_season_id` (league_season_id)
- `index_league_games_on_home_team_id` (home_team_id)
- `index_league_games_on_away_team_id` (away_team_id)

#### league_memberships テーブル

```ruby
create_table "league_memberships", force: :cascade do |t|
  t.bigint "league_id", null: false
  t.bigint "team_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["league_id", "team_id"], name: "index_league_memberships_on_league_id_and_team_id", unique: true
  t.index ["league_id"], name: "index_league_memberships_on_league_id"
  t.index ["team_id"], name: "index_league_memberships_on_team_id"
end
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| league_id | bigint | NO | - | FK: leagues.id |
| team_id | bigint | NO | - | FK: teams.id |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_league_memberships_on_league_id_and_team_id` (league_id, team_id) **UNIQUE**
- `index_league_memberships_on_league_id` (league_id)
- `index_league_memberships_on_team_id` (team_id)

#### league_pool_players テーブル

```ruby
create_table "league_pool_players", force: :cascade do |t|
  t.bigint "league_season_id", null: false
  t.bigint "player_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["league_season_id"], name: "index_league_pool_players_on_league_season_id"
  t.index ["player_id"], name: "index_league_pool_players_on_player_id"
end
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| league_season_id | bigint | NO | - | FK: league_seasons.id |
| player_id | bigint | NO | - | FK: players.id |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_league_pool_players_on_league_season_id` (league_season_id)
- `index_league_pool_players_on_player_id` (player_id)

#### team_managers テーブル

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

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| team_id | bigint | NO | - | FK: teams.id |
| manager_id | bigint | NO | - | FK: managers.id |
| role | integer | NO | 0 | 役割（0=director, 1=coach） |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_team_managers_on_team_id` (team_id)
- `index_team_managers_on_manager_id` (manager_id)

#### team_memberships テーブル

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
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| team_id | bigint | NO | - | FK: teams.id |
| player_id | bigint | NO | - | FK: players.id |
| squad | string | NO | "second" | 軍（"first" / "second"） |
| selected_cost_type | string | NO | "normal_cost" | 選択コストタイプ |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_team_memberships_on_team_id_and_player_id` (team_id, player_id) **UNIQUE**
- `index_team_memberships_on_team_id` (team_id)
- `index_team_memberships_on_player_id` (player_id)

#### player_absences テーブル

```ruby
create_table "player_absences", force: :cascade do |t|
  t.bigint "team_membership_id", null: false
  t.bigint "season_id", null: false
  t.integer "absence_type", null: false
  t.text "reason"
  t.date "start_date", null: false
  t.integer "duration", null: false
  t.string "duration_unit", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["season_id"], name: "index_player_absences_on_season_id"
  t.index ["team_membership_id"], name: "index_player_absences_on_team_membership_id"
end
```

| カラム名 | 型 | NULL | デフォルト | 備考 |
|---------|---|------|----------|------|
| id | bigint | NO | - | PK（自動採番） |
| team_membership_id | bigint | NO | - | FK: team_memberships.id |
| season_id | bigint | NO | - | FK: seasons.id |
| absence_type | integer | NO | - | 離脱タイプ（0=injury, 1=suspension, 2=reconditioning） |
| reason | text | YES | - | 理由（テキスト） |
| start_date | date | NO | - | 離脱開始日 |
| duration | integer | NO | - | 離脱期間 |
| duration_unit | string | NO | - | 期間単位（"days" / "games"） |
| created_at | datetime | NO | - | 作成日時 |
| updated_at | datetime | NO | - | 更新日時 |

**インデックス:**
- `index_player_absences_on_team_membership_id` (team_membership_id)
- `index_player_absences_on_season_id` (season_id)

---

### モデルリレーション

#### League モデル

**ファイル:** `app/models/league.rb`

**アソシエーション:**
- `has_many :league_memberships, dependent: :destroy`
- `has_many :teams, through: :league_memberships`
- `has_many :league_seasons`

**バリデーション:**
- `validates :name, presence: true`
- `validates :num_teams, presence: true, numericality: { only_integer: true, greater_than: 0 }`
- `validates :num_games, presence: true, numericality: { only_integer: true, greater_than: 0 }`

---

#### LeagueSeason モデル

**ファイル:** `app/models/league_season.rb`

**アソシエーション:**
- `belongs_to :league`
- `has_many :league_games, dependent: :destroy`
- `has_many :league_pool_players, dependent: :destroy`
- `has_many :pool_players, through: :league_pool_players, source: :player`

**Enum:**
- `enum status: { pending: 0, active: 1, completed: 2 }`

**バリデーション:**
- `validates :name, presence: true`
- `validates :start_date, presence: true`
- `validates :end_date, presence: true`
- `validates :status, presence: true`
- `validates :end_date, comparison: { greater_than_or_equal_to: :start_date }`

**メソッド:**
- `generate_schedule`: 6チーム総当たり対戦表を自動生成（詳細は「APIエンドポイント 14. 対戦表自動生成」を参照）

---

#### LeagueGame モデル

**ファイル:** `app/models/league_game.rb`

**アソシエーション:**
- `belongs_to :league_season`
- `belongs_to :home_team, class_name: 'Team'`
- `belongs_to :away_team, class_name: 'Team'`

**バリデーション:**
- `validates :game_date, presence: true`
- `validates :game_number, presence: true, numericality: { only_integer: true, greater_than: 0 }`

---

#### LeagueMembership モデル

**ファイル:** `app/models/league_membership.rb`

**アソシエーション:**
- `belongs_to :league`
- `belongs_to :team`

**バリデーション:**
- `validates :league_id, uniqueness: { scope: :team_id }`（同一リーグに同じチームを複数回登録不可）

---

#### LeaguePoolPlayer モデル

**ファイル:** `app/models/league_pool_player.rb`

**アソシエーション:**
- `belongs_to :league_season`
- `belongs_to :player`

**バリデーション:**
- `validates :league_season_id, uniqueness: { scope: :player_id, message: 'は既に選手プールに登録されています' }`（同一シーズンに同じ選手を複数回登録不可）

---

#### Team モデル（関連部分のみ）

**ファイル:** `app/models/team.rb`

**アソシエーション:**
- `has_many :league_memberships, dependent: :destroy`
- `has_many :leagues, through: :league_memberships`
- `has_many :team_managers, dependent: :destroy`
- `has_one :director_team_manager, -> { where(role: :director) }, class_name: 'TeamManager', dependent: :destroy`
- `has_one :director, through: :director_team_manager, source: :manager`
- `has_many :coach_team_managers, -> { where(role: :coach) }, class_name: 'TeamManager', dependent: :destroy`
- `has_many :coaches, through: :coach_team_managers, source: :manager`
- `has_many :team_memberships, dependent: :destroy`
- `has_many :players, through: :team_memberships`

---

#### TeamManager モデル

**ファイル:** `app/models/team_manager.rb`

**アソシエーション:**
- `belongs_to :team`
- `belongs_to :manager`

**Enum:**
- `enum :role, { director: 0, coach: 1 }`

**バリデーション:**
- `validates :role, presence: true`
- `validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: 'には既に監督が設定されています' }`（監督は1チームに1人まで）
- カスタムバリデーション: `validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [:create, :update]`

**カスタムバリデーション詳細:**
同一リーグ内の複数チームに同じマネージャーを兼任させることを禁止。チームが所属するリーグを特定し、そのリーグ内の他チームに同じマネージャーが既に割り当てられている場合、エラーを追加する。

---

#### TeamMembership モデル（関連部分のみ）

**ファイル:** `app/models/team_membership.rb`

**アソシエーション:**
- `belongs_to :team`
- `belongs_to :player`
- `has_many :season_rosters`
- `has_many :player_absences, dependent: :restrict_with_error`

**バリデーション:**
- `validates :squad, inclusion: { in: %w(first second) }`
- `validates :selected_cost_type, presence: true`

---

#### PlayerAbsence モデル

**ファイル:** `app/models/player_absence.rb`

**アソシエーション:**
- `belongs_to :team_membership`
- `belongs_to :season`

**Enum:**
- `enum :absence_type, { injury: 0, suspension: 1, reconditioning: 2 }`

**バリデーション:**
- `validates :absence_type, presence: true`
- `validates :start_date, presence: true`
- `validates :duration, presence: true, numericality: { only_integer: true, greater_than: 0 }`
- `validates :duration_unit, presence: true, inclusion: { in: %w(days games) }`

---

## ビジネスロジック

### リーグ運営フロー

1. **リーグ作成:** コミッショナーがリーグを新規作成（名前、チーム数、試合数、アクティブ状態設定）
2. **チーム追加:** リーグメンバーシップ作成により、既存チームをリーグに参加登録
3. **シーズン作成:** リーグに紐づくシーズンを作成（名前、開始日、終了日、ステータス設定）
4. **選手プール登録:** シーズンごとに使用可能な選手をプール登録（コストランク別フィルタリング可能）
5. **対戦表自動生成:** シーズンの `generate_schedule` を実行し、6チーム総当たり対戦表を自動生成（90試合）
6. **チームスタッフ管理:** 各チームに監督・コーチを割り当て（同一リーグ内の兼任禁止）
7. **選手離脱管理:** 怪我・出場停止・調整期間などの離脱情報を登録・更新
8. **シーズン進行:** ステータスを pending → active → completed と更新

### 対戦表自動生成ロジック詳細

**前提条件:**
- リーグに参加するチーム数が正確に6チームであること
- シーズンに `start_date` が設定されていること

**生成手順:**
1. リーグメンバーシップから参加チーム6チームを取得
2. 6チームから2チームの全組み合わせ（6C2 = 15カード）を生成
3. 各対戦カードについて:
   - team1 ホーム vs team2 アウェイ を3試合生成
   - team2 ホーム vs team1 アウェイ を3試合生成
4. 各試合に対して:
   - `game_date`: 開始日から順次1日ずつ進める（6試合ごとに休養日1日追加）
   - `game_number`: 同一対戦カード内の試合番号（1〜3）
   - `league_season_id`, `home_team_id`, `away_team_id` を設定し、LeagueGame レコード作成

**生成結果:**
- 総試合数: 15カード × 6試合/カード = 90試合
- 休養日: 6試合ごとに1日挿入
- 所要日数: 90試合 + 休養日（約15日）= 約105日

### シーズンステータス管理

**ステータス値:**
- `pending` (0): 準備中（対戦表未生成 or 未開始）
- `active` (1): 進行中（試合が実施されている）
- `completed` (2): 終了（全試合完了）

**遷移フロー:**
```
[作成] → pending
          ↓（対戦表生成、開始日到達）
        active
          ↓（全試合完了、終了日経過）
        completed
```

### コストランク別選手プールフィルタリング

**用途:** シーズンごとの選手プールで、コストに基づく戦力均衡を図るため、Aランク（高コスト）、Bランク（中コスト）、Cランク（低コスト）に分類し、フィルタリング可能にする。

**フィルタリング基準:**
- **Aランク:** `normal_cost >= 8`
- **Bランク:** `5 <= normal_cost <= 7`
- **Cランク:** `normal_cost <= 4`

**実装方法:**
`GET /api/v1/commissioner/league_seasons/:league_season_id/league_pool_players?cost_rank=A` のように `cost_rank` クエリパラメータを指定することで、該当コストランクの選手のみを取得可能。

### チーム監督・コーチの兼任制約

**制約内容:**
同一リーグ内の複数チームに、同じマネージャーを監督またはコーチとして割り当てることは禁止される。

**実装方法:**
TeamManager モデルのカスタムバリデーション `manager_cannot_be_assigned_to_multiple_teams_in_same_league` により、作成・更新時にチェックが行われる。

**チェックロジック:**
1. 対象チームが所属するリーグを特定（`team.leagues.first`）
2. そのリーグ内の他チームを取得（`current_league.teams.where.not(id: team.id)`）
3. 他チームに同じマネージャーが既に割り当てられているかチェック
4. 存在する場合、バリデーションエラー追加

**エラーメッセージ:**
`manager_id: 'は同一リーグ内の複数のチームに兼任することはできません'`

---

## フロントエンド実装詳細

### コンポーネント構成

**メインビュー:**
- `src/views/commissioner/LeaguesView.vue`: リーグ管理画面（全機能統合）

**ダイアログ:**
- リーグ作成/編集ダイアログ（インライン定義）
- チーム管理ダイアログ（インライン定義、テーブル行のアイコンボタンから起動）

**インラインパネル:**
- リーグ詳細パネル（テーブル行の `mdi-cog` アイコンから展開、5タブ構成）

**コンポーネントディレクトリ:**
- `src/components/commissioner/`: 存在しない（全機能が LeaguesView.vue に集約）

### 状態管理（リアクティブ変数）

**リーグ一覧:**
- `leagues`: ref<League[]> - リーグ一覧データ
- `loading`: ref<boolean> - ローディング状態

**リーグ作成/編集:**
- `dialog`: ref<boolean> - ダイアログ表示フラグ
- `editedLeague`: ref<League> - 編集中リーグデータ
- `editedIndex`: ref<number> - 編集対象のインデックス（-1: 新規作成）
- `defaultLeague`: League型定数 - デフォルト値

**チーム管理:**
- `membershipDialog`: ref<boolean> - チーム管理ダイアログ表示フラグ
- `selectedLeagueId`: ref<number | null> - 選択中リーグID
- `selectedLeagueName`: ref<string> - 選択中リーグ名
- `currentLeagueTeams`: ref<LeagueMembership[]> - 現在のリーグ参加チーム
- `availableTeams`: ref<Team[]> - 追加可能チーム一覧（既存メンバー除外）
- `selectedTeamIdToAdd`: ref<number | null> - 追加対象チームID
- `membershipLoading`: ref<boolean> - チーム管理ローディング状態

**リーグ詳細パネル:**
- `detailLeague`: ref<League | null> - 詳細表示中のリーグ
- `detailTab`: ref<string> - 選択中のタブ（初期値: `'seasons'`）
- `detailLeagueTeams`: ref<LeagueMembership[]> - 詳細パネル用リーグ参加チーム

**シーズン管理:**
- `leagueSeasons`: ref<LeagueSeason[]> - シーズン一覧
- `leagueSeasonsLoading`: ref<boolean> - ローディング状態

**対戦管理:**
- `selectedGameSeasonId`: ref<number | null> - 対戦表示用の選択シーズンID
- `leagueGames`: ref<LeagueGame[]> - 対戦一覧
- `leagueGamesLoading`: ref<boolean> - ローディング状態

**選手プール管理:**
- `selectedPoolSeasonId`: ref<number | null> - プール表示用の選択シーズンID
- `poolPlayers`: ref<LeaguePoolPlayer[]> - プール選手一覧
- `poolPlayersLoading`: ref<boolean> - ローディング状態

**チームスタッフ管理:**
- `selectedStaffTeamId`: ref<number | null> - スタッフ表示用の選択チームID
- `teamManagers`: ref<TeamManager[]> - チームマネージャー一覧
- `teamManagersLoading`: ref<boolean> - ローディング状態

### API呼び出し（Axios）

**ベースURL:** `/api/v1` （推定、Axiosインスタンス設定による）

**主要API:**
- `GET /commissioner/leagues` - リーグ一覧取得
- `POST /commissioner/leagues` - リーグ作成
- `PUT /commissioner/leagues/:id` - リーグ更新
- `DELETE /commissioner/leagues/:id` - リーグ削除
- `GET /commissioner/leagues/:league_id/league_memberships` - リーグメンバーシップ一覧取得
- `POST /commissioner/leagues/:league_id/league_memberships` - チーム追加
- `DELETE /commissioner/leagues/:league_id/league_memberships/:id` - チーム削除
- `GET /commissioner/leagues/:league_id/league_seasons` - シーズン一覧取得
- `POST /commissioner/leagues/:league_id/league_seasons/:id/generate_schedule` - スケジュール生成
- `GET /commissioner/leagues/:league_id/league_seasons/:season_id/league_games` - 対戦一覧取得
- `GET /commissioner/leagues/:league_id/league_seasons/:season_id/league_pool_players` - プール一覧取得
- `GET /commissioner/leagues/:league_id/teams/:team_id/team_managers` - チームマネージャー一覧
- `GET /teams` - 全チーム取得（リーグメンバーシップ外）

### Vuetify 3コンポーネント使用状況

- `v-container`, `v-row`, `v-col`: レイアウト
- `v-card`, `v-card-title`, `v-card-text`, `v-card-actions`: カード構成
- `v-data-table`: リーグ一覧、チームメンバーシップ一覧表示
- `v-dialog`: モーダルダイアログ（リーグ編集、チーム管理）
- `v-text-field`: テキスト入力（リーグ名、チーム数、試合数）
- `v-checkbox`: チェックボックス（アクティブフラグ）
- `v-select`: セレクトボックス（チーム選択）
- `v-btn`: ボタン（作成、保存、キャンセル、削除等）
- `v-icon`: アイコン（編集: `mdi-pencil`, 削除: `mdi-delete`）
- `v-spacer`: スペーサー

### useSnackbar Composable

**ファイル:** `src/composables/useSnackbar.ts`（推定）

**メソッド:**
- `showSnackbar(message: string, type: 'success' | 'error')`: スナックバー表示

**使用箇所:**
- 全API成功時: `showSnackbar('〇〇しました', 'success')`
- 全API失敗時: `showSnackbar('〇〇に失敗しました', 'error')`

---

## TODO / 改善提案

### 認証・権限

~~**現状:** 一部のコントローラーがコミッショナー権限チェックを行っていない。~~

**実装済み:** 全コミッショナーコントローラーが `Api::V1::Commissioner::BaseController` を継承し、`before_action :check_commissioner` による権限チェックが統一された。LeagueSeasonsController もコミッショナー名前空間に移動完了。

### フロントエンド実装状況

**実装済み:**
- LeaguesView.vue にチーム管理ボタン配置（`mdi-account-group` アイコン）
- リーグ詳細パネルを新設（`mdi-cog` アイコンから展開）
- リーグ詳細パネル内にタブUI: シーズン管理、対戦管理、選手プール管理、チームスタッフ管理、離脱管理
- TopMenu.vue にコミッショナーモードトグルスイッチ + リーグ管理ボタン
- TopMenu.vue に公式Wikiリンクカード

**未実装:**
- 離脱管理タブは説明アラート表示のみ（CRUD操作画面は未実装）

### 対戦表自動生成の改善

**現状:** 6チーム固定の総当たりロジックがハードコーディングされている。

**提案:**
- チーム数に応じた対戦表生成アルゴリズムの汎用化
- 対戦数（現在3回固定）の可変化
- 休養日挿入ルールのカスタマイズ可能化

### エラーハンドリング

**現状:** フロントエンドで `console.error` によるログ出力のみ。

**提案:**
- エラーメッセージの詳細表示（バリデーションエラーのフィールド別表示）
- リトライ機構の実装（ネットワークエラー時）

### テスト

**現状:**
- バックエンド: 6コントローラー（LeagueSeasonsController, LeagueGamesController, LeaguePoolPlayersController, TeamMembershipsController, PlayerAbsencesController, TeamManagersController）の認可テスト72件が実装済み（RSpec request specs）
- テスト内容: Commissioner/一般ユーザー/未認証の3パターン + CRUD正常系
- GitHub Actions CI (`test.yml`) でRSpec + Vitestが自動実行される

**今後:**
- フロントエンド: Vitest + Vue Test Utils でコンポーネントテスト作成
- E2Eテスト: Playwright でリーグ運営フロー全体のテスト作成

---

## 参考情報

**関連仕様書:**
- `01_authentication.md`: 認証機能仕様（コミッショナー権限の基盤となる `user.commissioner?` の定義元）
- `03_team_management.md`: チーム管理仕様（LeagueMembershipで参照するTeamモデルの詳細）
- `04_player_management.md`: 選手管理仕様（LeaguePoolPlayerで参照するPlayerモデルの詳細）
- `11_player_absence.md`: 選手離脱管理仕様（本仕様書と重複部分あり、統合検討の余地あり）

**ソースコードパス:**
- バックエンド: `/home/morinaga/projects/thbigmatome/`
- フロントエンド: `/home/morinaga/projects/thbigmatome-front/`

**データベーススキーマ:**
- `/home/morinaga/projects/thbigmatome/db/schema.rb`

**ルーティング:**
- `/home/morinaga/projects/thbigmatome/config/routes.rb`

---

**作成日:** 2026-02-14
**更新日:** 2026-02-21
**作成者:** 足軽4号
**ソースコード基準日:** 2026-02-21
