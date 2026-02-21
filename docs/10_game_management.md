# 10. 試合管理機能仕様書

## 概要

本機能は、東方BIG野球リーグの試合結果入力、スコアボード管理、スタメン登録、スコアシート表示を包括的に管理する。試合日程データ（`season_schedules` テーブル）を基盤とし、試合詳細情報（スコア、スコアボード、先発・勝敗投手、スタメン等）をJSON形式で保存する。

**主要な特徴:**
- 試合結果入力画面: スコアボード入力、投手記録（先発・勝敗投手・セーブ）、基本情報（球場、ホーム/ビジター、DH制）
- スコアシート画面: スコアボード表示、スタメン登録ダイアログ、打撃記録入力（未完成機能）
- スコアボードコンポーネント: 動的イニング追加/削除、サヨナラ勝ち対応（ホームチーム裏攻撃なし）
- スタメンダイアログ: ホーム/ビジターチーム両方のスタメンを同時登録、守備位置・打順管理
- データモデル: `season_schedules` テーブルに `scoreboard`, `starting_lineup`, `opponent_starting_lineup` をJSONB形式で保存

**技術スタック:**
- バックエンド: Rails 8, PostgreSQL JSONB
- フロントエンド: Vue 3 Composition API, TypeScript, Vuetify 3
- APIエンドポイント: `GET /game/:id`, `PUT /game/:id`, `PATCH /game/:id`

---

## 画面構成（フロントエンド）

### 試合結果入力画面 (GameResult.vue)

**パス:** `/teams/:teamId/seasons/:seasonId/games/:scheduleId`

**コンポーネント:** `src/views/GameResult.vue`

**レイアウト:**
```
┌─────────────────────────────────────────────────────────────────┐
│ [ツールバー: オレンジ背景]                                       │
│ {チーム名} | 試合: {試合番号} | {日付}                   │
│ [シーズンポータルへ] [スコアシート] ────────────── [保存ボタン] │
└─────────────────────────────────────────────────────────────────┘
│ [基本情報カード]                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 基本情報                                                    │ │
│ │ ┌────────┐┌────────┐┌──────┐┌────┐┌──────┐              │ │
│ │ │先発投手││対戦相手││ホーム/││球場││DH制 │              │ │
│ │ │        ││        ││ビジター││    ││     │              │ │
│ │ └────────┘└────────┘└──────┘└────┘└──────┘              │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ [試合情報カード]                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 試合情報                                                    │ │
│ │ ┌─────────────────────────────────────────────────────────┐ │ │
│ │ │ [スコアボードコンポーネント]                             │ │ │
│ │ │ チーム | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 計        │ │ │
│ │ │ ビジター| □ | □ | □ | □ | □ | □ | □ | □ | □ | 0        │ │ │
│ │ │ ホーム  | □ | □ | □ | □ | □ | □ | □ | □ | □ | 0        │ │ │
│ │ │ [イニング追加] [イニング削除] □ 裏攻撃なし              │ │ │
│ │ └─────────────────────────────────────────────────────────┘ │ │
│ │ ┌────────────┐┌────────────┐┌────────────┐               │ │
│ │ │ 勝利投手   ││ 敗戦投手   ││ セーブ投手 │               │ │
│ │ │            ││            ││            │               │ │
│ │ └────────────┘└────────────┘└────────────┘               │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**フォームフィールド:**

| フィールドID | ラベル | 入力タイプ | コンポーネント | 備考 |
|-------------|--------|-----------|--------------|------|
| `announced_starter_id` | 先発投手 | select | `TeamMemberSelect` | 自チーム登録選手から選択 |
| `opponent_team_id` | 対戦相手 | select | `TeamSelect` | 全チームから選択（略称表示） |
| `home_away` | ホーム/ビジター | select | v-select | 'home' / 'visitor' |
| `stadium` | 球場 | text | v-text-field | 自由入力 |
| `designated_hitter_enabled` | DH制 | select | v-select | true / false |
| `scoreboard` | スコアボード | custom | `Scoreboard` | イニング別得点入力 |
| `winning_pitcher_id` | 勝利投手 | select | `PlayerSelect` | 全選手から選択 |
| `losing_pitcher_id` | 敗戦投手 | select | `PlayerSelect` | 全選手から選択 |
| `save_pitcher_id` | セーブ投手 | select | `PlayerSelect` | 全選手から選択 |

**動作フロー（保存時）:**

```
[1] ユーザーがスコアボード・投手情報を入力
       ↓
[2] [保存]ボタンクリック (@click="saveGame")
       ↓
[3] スコアボードから自動的に総得点を計算:
     - homeTeamScore = scoreboard.home の合計
     - awayTeamScore = scoreboard.away の合計
       ↓
[4] home_away に応じて score / opponent_score を設定:
     - home_away === 'home' の場合:
       score = homeTeamScore, opponent_score = awayTeamScore
     - home_away === 'visitor' の場合:
       score = awayTeamScore, opponent_score = homeTeamScore
       ↓
[5] スコアボードが全て空 (null or 0) の場合:
     score = null, opponent_score = null に設定
       ↓
[6] PUT /game/{scheduleId} でデータ送信
       ↓
[7a] 成功時: Snackbar に「保存成功」メッセージ
       ↓
[7b] 失敗時: Snackbar に「保存失敗」エラーメッセージ（赤色）
```

**国際化（i18n）キー:**
- `gameResult.game`: 試合番号ラベル
- `gameResult.dateDisplay`: 日付表示フォーマット
- `gameResult.basicInfo`: 基本情報カードタイトル
- `gameResult.gameInfo`: 試合情報カードタイトル
- `gameResult.announcedStarter`: 先発投手ラベル
- `gameResult.opponentTeam`: 対戦相手ラベル
- `gameResult.homeAway.title`: ホーム/ビジタータイトル
- `gameResult.homeAway.home`: ホーム選択肢
- `gameResult.homeAway.away`: ビジター選択肢
- `gameResult.stadium`: 球場ラベル
- `gameResult.dhSystem.title`: DH制タイトル
- `gameResult.dhSystem.enabled`: DH制あり
- `gameResult.dhSystem.disabled`: DH制なし
- `gameResult.winningPitcher`: 勝利投手ラベル
- `gameResult.losingPitcher`: 敗戦投手ラベル
- `gameResult.savePitcher`: セーブ投手ラベル
- `gameResult.save`: 保存ボタンラベル
- `gameResult.saveSuccess`: 保存成功メッセージ
- `gameResult.saveFailed`: 保存失敗メッセージ
- `seasonPortal.title`: シーズンポータルタイトル

---

### スコアシート画面 (ScoreSheet.vue)

**パス:** `/teams/:teamId/seasons/:seasonId/games/:scheduleId/scoresheet`

**コンポーネント:** `src/views/ScoreSheet.vue`

**レイアウト:**
```
┌─────────────────────────────────────────────────────────────────┐
│ [ツールバー: 緑背景]                                             │
│ {チーム名} | 試合: {試合番号} | {日付} | vs. {対戦相手}         │
│ | {スコア} ({勝敗})                                               │
│ [試合結果に戻る] ──────────────────────── [スタメン登録]         │
└─────────────────────────────────────────────────────────────────┘
│ [スコアボード表（読み取り専用）]                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ チーム      | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 計       │ │
│ │ {ビジター}  | 0 | 1 | 0 | 2 | 0 | 0 | 0 | 0 | 1 | 4       │ │
│ │ {ホーム}    | 0 | 0 | 0 | 1 | 0 | 0 | 2 | 0 | X | 3       │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ [打撃記録表（スタメン登録後表示）]                                │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 打順|選手名|守備|1|2|3|4|5|6|7|8|9|安打|打点                 │ │
│ │  1  | XX  | 中 |□|□|□|□|□|□|□|□|□| -  | -                  │ │
│ │  2  | YY  | 遊 |□|□|□|□|□|□|□|□|□| -  | -                  │ │
│ │ ... (9人分またはDH制で10人分)                                │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**打撃記録セレクト選択肢:**
- '安打', '二塁打', '三塁打', '本塁打', '犠打', '犠飛', '四球', '死球', '三振', '併殺', 'ゴロ', 'フライ'

**注意事項:**
- 打撃記録の「安打」「打点」列の自動集計機能は未実装（現在は常に `-` 表示）
- 打撃記録は入力可能だが保存機能は未実装（`battingResults` はローカル状態のみ）

**動作フロー（スタメン登録）:**

```
[1] [スタメン登録]ボタンクリック
       ↓
[2] StartingMemberDialog 表示
       ↓
[3] ホームチーム・ビジターチームそれぞれ最大9人（DH制で10人）のスタメンを入力
     - 打順 (1-9 or 1-10)
     - 守備位置 (p, c, 1b, 2b, 3b, ss, lf, cf, rf, dh)
     - 選手選択
       ↓
[4] [保存]ボタンクリック (ダイアログ内)
       ↓
[5] PATCH /game/{scheduleId} で starting_lineup / opponent_starting_lineup 送信
       ↓
[6a] 成功時: Snackbar に「スタメン保存成功」メッセージ、打撃記録表が表示される
       ↓
[6b] 失敗時: Snackbar にエラーメッセージ（赤色）
```

**国際化（i18n）キー:**
- `scoreSheet.order`: 打順ラベル
- `scoreSheet.player`: 選手ラベル
- `scoreSheet.position`: 守備位置ラベル
- `scoreSheet.hits`: 安打ラベル
- `scoreSheet.rbi`: 打点ラベル
- `messages.startingMembersSaved`: スタメン保存成功メッセージ
- `messages.failedToSaveStartingMembers`: スタメン保存失敗メッセージ

---

### スコアボードコンポーネント (Scoreboard.vue)

**コンポーネント:** `src/components/Scoreboard.vue`

**Props:**
- `modelValue: Scoreboard` (v-model バインディング)
- `homeTeamName: string` (ホームチーム名)
- `awayTeamName: string` (ビジターチーム名)

**Emits:**
- `update:modelValue` (スコアボード変更時)

**機能:**

1. **イニング別得点入力**: 各イニングに数値入力フィールド、入力値は `number | null`
2. **自動合計計算**: ホーム/ビジターそれぞれの総得点を自動計算して表示
3. **イニング追加**: [イニング追加]ボタンで延長戦対応（ホーム/ビジター両方に null を追加）
4. **イニング削除**: [イニング削除]ボタンで最終イニング削除（最低1イニングは維持）
5. **サヨナラ勝ち対応**: [裏攻撃なし]チェックボックスで、ホームチームの最終イニング攻撃を削除
   - チェックON: `scoreboard.home.pop()` で最終イニング削除
   - チェックOFF: `scoreboard.home.push(null)` で最終イニング追加

**サヨナラ勝ち判定ロジック:**
```typescript
const isWalkOff = computed(() => {
  return !!(localScoreboard.value && localScoreboard.value.home.length < localScoreboard.value.away.length);
});
```

**国際化（i18n）キー:**
- `gameResult.team`: チームラベル
- `gameResult.total`: 合計ラベル
- `gameResult.addInning`: イニング追加ボタン
- `gameResult.removeInning`: イニング削除ボタン
- `gameResult.noBottomInning`: 裏攻撃なしチェックボックス

---

### スタメンダイアログ (StartingMemberDialog.vue)

**コンポーネント:** `src/components/StartingMemberDialog.vue`

**Props:**
- `modelValue: boolean` (ダイアログ表示制御)
- `homeTeamId: number` (ホームチームID)
- `allPlayers: Player[]` (全選手リスト、対戦相手スタメン用)
- `initialHomeLineup: LineupMember[]` (既存ホームチームスタメン)
- `initialOpponentLineup: LineupMember[]` (既存対戦相手スタメン)
- `designatedHitterEnabled: boolean` (DH制有効/無効)

**Emits:**
- `update:modelValue` (ダイアログ開閉)
- `save` (保存時、`{ homeLineup: StartingMember[], opponentLineup: StartingMember[] }` を emit)

**レイアウト:**
```
┌─────────────────────────────────────────────────────────────────┐
│ スタメン登録                                                     │
│ ┌───────────────────────┐┌───────────────────────┐             │
│ │ ホームチームスタメン  ││ ビジターチームスタメン │             │
│ │ 打順|守備|選手|守備率 ││ 打順|守備|選手|守備率 │             │
│ │  1  | □ | □  | -     ││  1  | □ | □  | -     │             │
│ │  2  | □ | □  | -     ││  2  | □ | □  | -     │             │
│ │  3  | □ | □  | -     ││  3  | □ | □  | -     │             │
│ │ ... (9人またはDH制で10人) (9人またはDH制で10人)              │
│ └───────────────────────┘└───────────────────────┘             │
│                                       [キャンセル] [保存]       │
└─────────────────────────────────────────────────────────────────┘
```

**守備位置選択:**

| 守備位置キー | 表示名 | 守備能力参照フィールド | スローイング参照フィールド |
|-------------|--------|---------------------|------------------------|
| `p` | 投手 | `defense_p` | - |
| `c` | 捕手 | `defense_c` | `throwing_c` |
| `1b` | 一塁手 | `defense_1b` | - |
| `2b` | 二塁手 | `defense_2b` | - |
| `3b` | 三塁手 | `defense_3b` | - |
| `ss` | 遊撃手 | `defense_ss` | - |
| `lf` | 左翼手 | `defense_lf` (未設定時 `defense_of` で代替) | `throwing_of` |
| `cf` | 中堅手 | `defense_cf` (未設定時 `defense_of` で代替) | `throwing_of` |
| `rf` | 右翼手 | `defense_rf` (未設定時 `defense_of` で代替) | `throwing_of` |
| `dh` | 指名打者 | - | - |

**守備率表示ロジック:**
- 外野手 (lf/cf/rf): `{defense_lf or defense_of}/{throwing_of}`
- 捕手 (c): `{defense_c}/{+3}` (throwing_c が正の場合は `+` 付与)
- その他内野手: `{defense_XX}` のみ（スローイングなし）
- DH: `-` (守備なし)

**守備位置キーボードショートカット:**

| キー | 守備位置 |
|------|---------|
| `1`, `p`, `P` | 投手 (p) |
| `2` | 捕手 (c) |
| `3` | 一塁手 (1b) |
| `4` | 二塁手 (2b) |
| `5` | 三塁手 (3b) |
| `6` | 遊撃手 (ss) |
| `7` | 左翼手 (lf) |
| `8` | 中堅手 (cf) |
| `9` | 右翼手 (rf) |
| `0`, `d`, `D` | 指名打者 (dh) |

**守備位置重複制御:**
- 各チーム内で同じ守備位置を複数選択することは不可（選択済みの位置は選択肢から除外）
- ただし、現在選択中の位置は選択肢に含まれる（変更可能）

**選手選択:**
- ホームチーム: `GET /teams/{homeTeamId}/team_players` で取得した選手リスト
- 対戦相手: Props で渡された `allPlayers` リスト（全選手）
- Autocomplete で選手番号 + 名前表示（例: `3 霊夢`）

**保存データ形式:**
```typescript
{
  homeLineup: [
    { player_id: 1, position: 'p', order: 1 },
    { player_id: 5, position: 'c', order: 2 },
    // ... 最大9人（DH制で10人）
  ],
  opponentLineup: [
    { player_id: 10, position: 'ss', order: 1 },
    // ...
  ]
}
```

**国際化（i18n）キー:**
- `startingMemberDialog.title`: ダイアログタイトル
- `startingMemberDialog.homeTeamLineup`: ホームチームスタメン
- `startingMemberDialog.opponentTeamLineup`: ビジターチームスタメン
- `startingMemberDialog.tableHeaders.battingOrder`: 打順ラベル
- `startingMemberDialog.tableHeaders.position`: 守備位置ラベル
- `startingMemberDialog.tableHeaders.player`: 選手ラベル
- `startingMemberDialog.tableHeaders.defenseRating`: 守備率ラベル
- `baseball.positions.pitcher` / `catcher` / `first_baseman` ... (各守備位置名)
- `baseball.shortPositions.{position}`: 守備位置略称（スコアシート用）
- `actions.cancel`: キャンセルボタン
- `actions.save`: 保存ボタン

---

## APIエンドポイント

### 1. 試合詳細取得

**エンドポイント:** `GET /api/v1/game/:id`

**コントローラー:** `Api::V1::GameController#show`

**ルーティング定義:** `config/routes.rb` (line 33)
```ruby
resources :game, only: [:show, :update]
```

**認証要否:** 要（ApplicationController の `authenticate_user!` が適用）

**パスパラメータ:**
- `id`: SeasonSchedule の ID

**レスポンス（成功時 200 OK）:**

コントローラーがインラインでハッシュを構築して返却:
```json
{
  "team_id": 1,
  "team_name": "紅魔館",
  "season_id": 5,
  "game_date": "2024-05-15",
  "game_number": 10,
  "announced_starter_id": 3,
  "stadium": "幻想郷ドーム",
  "home_away": "home",
  "designated_hitter_enabled": true,
  "score": 5,
  "opponent_score": 3,
  "opponent_team_id": 2,
  "opponent_team": "白玉楼",
  "winning_pitcher_id": 8,
  "losing_pitcher_id": 15,
  "save_pitcher_id": null,
  "scoreboard": {
    "home": [0, 1, 0, 2, 0, 0, 0, 2, null],
    "away": [0, 0, 1, 0, 0, 2, 0, 0, 0]
  },
  "starting_lineup": [
    { "player_id": 1, "position": "cf", "order": 1 },
    { "player_id": 5, "position": "ss", "order": 2 },
    { "player_id": 8, "position": "p", "order": 9 }
  ],
  "opponent_starting_lineup": [
    { "player_id": 10, "position": "2b", "order": 1 },
    { "player_id": 12, "position": "lf", "order": 2 }
  ],
  "game_result": {
    "opponent_short_name": "白玉",
    "score": "5 - 3",
    "result": "win"
  }
}
```

**注意**:
- `game_number` は `SeasonSchedule#calculated_game_number` から取得（DBカラム値 or 動的計算）
- `announced_starter_id` は `announced_starter&.id`（TeamMembershipのID）
- `game_result` は `date < Date.today` の場合のみ `game_result_hash` を呼び出して生成。未来の試合では `null`

**レスポンス（失敗時）:**
- `404 Not Found`: SeasonSchedule が存在しない、またはシーズンが未初期化
  ```json
  { "error": "Season not initialized for this team" }
  ```
  または
  ```json
  { "error": "Team or Season not found" }
  ```
- `400 Bad Request`: 日付フォーマット不正
  ```json
  { "error": "Invalid date format" }
  ```

**処理フロー:**
```
[1] SeasonSchedule.find(params[:id]) で試合データ取得
       ↓
[2] season, team をアソシエーションから取得
       ↓
[3] game_number: season_schedule.calculated_game_number を呼び出し
     - SeasonSchedule モデルのメソッドに統合済み
     - game_number カラムが設定済みならそれを使用
     - 未設定なら動的計算
       ↓
[4] game_result: season_schedule.game_result_hash を呼び出し
     - SeasonSchedule モデルのメソッドに統合済み
     - date < Date.today の場合のみ呼び出し
       ↓
[5] JSON レスポンス返却（インラインハッシュ構築）
```

**注意事項:**
- ~~`oppnent_score` はバックエンドDBのタイポ~~ → **修正済み (cmd_142)**: カラム名を `opponent_score`, `opponent_team_id` にリネーム。変換コードも除去済み。
- `game_result` は試合日が過去かつスコア入力済みの場合のみ生成される。未来の試合や未入力の試合では `null`。
- **DESIGN-008,009**: `game_number` と `game_result` のロジックは `SeasonSchedule` モデルに統合済み（`calculated_game_number`, `game_result_hash`）。コントローラーからの重複実装は除去されている。

---

### 2. 試合結果更新

**エンドポイント:** `PUT /api/v1/game/:id`

**コントローラー:** `Api::V1::GameController#update`

**ルーティング定義:** `config/routes.rb` (line 33)

**認証要否:** 要

**パスパラメータ:**
- `id`: SeasonSchedule の ID

**リクエストボディ:**
```json
{
  "announced_starter_id": 3,
  "stadium": "幻想郷ドーム",
  "home_away": "home",
  "designated_hitter_enabled": true,
  "score": 5,
  "opponent_score": 3,
  "opponent_team_id": 2,
  "winning_pitcher_id": 8,
  "losing_pitcher_id": 15,
  "save_pitcher_id": null,
  "scoreboard": {
    "home": [0, 1, 0, 2, 0, 0, 0, 2, null],
    "away": [0, 0, 1, 0, 0, 2, 0, 0, 0]
  },
  "starting_lineup": [
    { "player_id": 1, "position": "cf", "order": 1 },
    { "player_id": 5, "position": "ss", "order": 2 }
  ],
  "opponent_starting_lineup": [
    { "player_id": 10, "position": "2b", "order": 1 }
  ]
}
```

**許可されるパラメータ (Strong Parameters):**
```ruby
params.permit(
  :announced_starter_id,
  :stadium,
  :home_away,
  :designated_hitter_enabled,
  :score,
  :opponent_score,
  :opponent_team_id,
  :winning_pitcher_id,
  :losing_pitcher_id,
  :save_pitcher_id,
  scoreboard: { home: [], away: [] },
  starting_lineup: [ :player_id, :position, :order ],
  opponent_starting_lineup: [ :player_id, :position, :order ]
)
```

**レスポンス（成功時 200 OK）:**

`season_schedule` オブジェクトをそのまま JSON として返却（`SeasonScheduleSerializer` は不使用）:
```json
{
  "id": 123,
  "season_id": 5,
  "date": "2024-05-15",
  "date_type": "game_day",
  "announced_starter_id": 3,
  "opponent_team_id": 2,
  "game_number": 10,
  "stadium": "幻想郷ドーム",
  "home_away": "home",
  "designated_hitter_enabled": true,
  "score": 5,
  "opponent_score": 3,
  "winning_pitcher_id": 8,
  "losing_pitcher_id": 15,
  "save_pitcher_id": null,
  "scoreboard": {
    "home": [0, 1, 0, 2, 0, 0, 0, 2, null],
    "away": [0, 0, 1, 0, 0, 2, 0, 0, 0]
  },
  "starting_lineup": [...],
  "opponent_starting_lineup": [...],
  "created_at": "2024-05-01T12:00:00.000Z",
  "updated_at": "2024-05-15T18:30:00.000Z"
}
```

**レスポンス（失敗時）:**
- `404 Not Found`: 試合が存在しない
  ```json
  { "error": "Game not found" }
  ```
- `422 Unprocessable Entity`: バリデーションエラー
  ```json
  {
    "errors": [
      "Home away is not included in the list"
    ]
  }
  ```

**処理フロー:**
```
[1] SeasonSchedule.find(params[:id]) で試合取得
       ↓
[2] game_params で Strong Parameters 適用
       ↓
[3] season_schedule.update(update_params) で更新実行
       ↓
[4a] 成功時: season_schedule をそのまま JSON として 200 OK 返却
       ↓
[4b] 失敗時: エラーメッセージ配列を 422 で返却
```

**注意**: 更新成功時のレスポンスは `SeasonScheduleSerializer` ではなく、`season_schedule` オブジェクトをそのまま `render json:` で返却している。

---

### 3. スタメン更新（PATCH）

**エンドポイント:** `PATCH /api/v1/game/:id`

**コントローラー:** `Api::V1::GameController#update` (PUT と同じアクション)

**リクエストボディ（部分更新）:**
```json
{
  "starting_lineup": [
    { "player_id": 1, "position": "cf", "order": 1 },
    { "player_id": 5, "position": "ss", "order": 2 },
    { "player_id": 8, "position": "p", "order": 9 }
  ],
  "opponent_starting_lineup": [
    { "player_id": 10, "position": "2b", "order": 1 },
    { "player_id": 12, "position": "lf", "order": 2 }
  ]
}
```

**処理フロー:**
- PUT と同一（Rails の update アクションは PATCH/PUT 両対応）

---

## データモデル

### season_schedules テーブル

**定義場所:** `db/schema.rb` (line 291-317)

**カラム定義:**

| カラム名 | 型 | NULL | 説明 |
|---------|-----|------|------|
| `id` | bigint | NOT NULL | 主キー |
| `season_id` | bigint | NOT NULL | 外部キー → seasons.id |
| `date` | date | NOT NULL | 試合日 |
| `date_type` | string | NULL | 日付タイプ ('game_day', 'interleague_game_day', 'off_day' 等) |
| `announced_starter_id` | bigint | NULL | 外部キー → team_memberships.id (先発投手) |
| `opponent_team_id` | bigint | NULL | 外部キー → teams.id (対戦相手チーム) |
| `game_number` | integer | NULL | 試合番号（シーズン内通算） |
| `stadium` | string | NULL | 球場名 |
| `home_away` | string | NULL | 'home' or 'visitor' |
| `designated_hitter_enabled` | boolean | NULL | DH制有効/無効 |
| `score` | integer | NULL | 自チームの得点 |
| `opponent_score` | integer | NULL | 対戦相手の得点 |
| `winning_pitcher_id` | bigint | NULL | 外部キー → players.id (勝利投手) |
| `losing_pitcher_id` | bigint | NULL | 外部キー → players.id (敗戦投手) |
| `save_pitcher_id` | bigint | NULL | 外部キー → players.id (セーブ投手) |
| `scoreboard` | jsonb | NULL | スコアボード（イニング別得点） |
| `starting_lineup` | jsonb | NULL | 自チームスタメン |
| `opponent_starting_lineup` | jsonb | NULL | 対戦相手スタメン |
| `created_at` | datetime | NOT NULL | 作成日時 |
| `updated_at` | datetime | NOT NULL | 更新日時 |

**インデックス:**
- `index_season_schedules_on_season_id`
- `index_season_schedules_on_announced_starter_id`
- `index_season_schedules_on_opponent_team_id`
- `index_season_schedules_on_winning_pitcher_id`
- `index_season_schedules_on_losing_pitcher_id`
- `index_season_schedules_on_save_pitcher_id`

**アソシエーション (SeasonSchedule モデル):**

**定義場所:** `app/models/season_schedule.rb`

```ruby
class SeasonSchedule < ApplicationRecord
  belongs_to :season
  belongs_to :announced_starter, class_name: "TeamMembership", optional: true
  belongs_to :opponent_team, class_name: "Team", foreign_key: "opponent_team_id", optional: true
  belongs_to :winning_pitcher, class_name: "Player", optional: true
  belongs_to :losing_pitcher, class_name: "Player", optional: true
  belongs_to :save_pitcher, class_name: "Player", optional: true

  validates :home_away, inclusion: { in: [ "home", "visitor" ] }, allow_blank: true
end
```

**モデルメソッド:**

| メソッド | 説明 |
|---------|------|
| `calculated_game_number` | `game_number` カラム値があればそれを使用、なければ同シーズン内の試合日（`game_day` / `interleague_game_day`）で `date < 当該日` の件数 + 1 を動的計算 |
| `game_result_hash` | `score` と `opponent_score` の両方が存在する場合に `{ opponent_short_name, score, result }` を返す。スコア未入力なら `nil` |

```ruby
def calculated_game_number
  game_number || season.season_schedules
    .where(date_type: [ "game_day", "interleague_game_day" ])
    .where("date < ?", date)
    .count + 1
end

def game_result_hash
  return nil if score.blank? || opponent_score.blank?
  result = if score > opponent_score then "win"
  elsif score < opponent_score then "lose"
  else "draw"
  end
  {
    opponent_short_name: opponent_team&.short_name,
    score: "#{score} - #{opponent_score}",
    result: result
  }
end
```

**JSON 構造仕様:**

#### scoreboard (JSONB)

**構造:**
```json
{
  "home": [0, 1, 0, 2, 0, 0, 0, 2, null],
  "away": [0, 0, 1, 0, 0, 2, 0, 0, 0]
}
```

**仕様:**
- `home`: ホームチームのイニング別得点配列（`(number | null)[]`）
- `away`: ビジターチームのイニング別得点配列（`(number | null)[]`）
- 配列長は可変（9イニング以上、延長戦対応）
- サヨナラ勝ちの場合、`home.length < away.length`（ホーム最終回なし）
- `null` は未入力を意味する（0 とは区別）

#### starting_lineup (JSONB)

**構造:**
```json
[
  { "player_id": 1, "position": "cf", "order": 1 },
  { "player_id": 5, "position": "ss", "order": 2 },
  { "player_id": 8, "position": "p", "order": 9 }
]
```

**仕様:**
- 配列要素数: 9人（通常） or 10人（DH制）
- `player_id`: players.id への参照
- `position`: 守備位置キー (`p`, `c`, `1b`, `2b`, `3b`, `ss`, `lf`, `cf`, `rf`, `dh`)
- `order`: 打順 (1-9 or 1-10)

#### opponent_starting_lineup (JSONB)

**構造:** `starting_lineup` と同一

---

## ビジネスロジック

### 試合結果入力フロー

```
[シーズンポータル画面]
     ↓
[試合日程一覧から試合を選択]
     ↓
[試合結果入力画面 (GameResult.vue) に遷移]
     ↓
[1. 基本情報入力]
   - 先発投手選択（自チーム登録選手から）
   - 対戦相手選択（全チームから、略称表示）
   - ホーム/ビジター選択
   - 球場名入力
   - DH制有効/無効選択
     ↓
[2. スコアボード入力 (Scoreboard コンポーネント)]
   - 各イニングの得点を入力
   - 延長戦の場合は [イニング追加] で10回以降追加
   - サヨナラ勝ちの場合は [裏攻撃なし] チェック
   - 自動的に総得点が計算される
     ↓
[3. 投手記録入力]
   - 勝利投手選択（全選手から）
   - 敗戦投手選択
   - セーブ投手選択（該当なければ未選択）
     ↓
[4. [保存]ボタンクリック]
   - スコアボードから自動的に score / opponent_score を計算
   - PUT /game/{scheduleId} でデータ送信
     ↓
[5. 保存成功]
   - Snackbar に「保存成功」メッセージ表示
   - データベース更新完了
```

### スコア自動計算ロジック

**実装場所:** `GameResult.vue` の `saveGame` メソッド (line 267-298)

```typescript
// スコアボードから合計を計算
const homeTeamScore = gameData.value.scoreboard.home.reduce(
  (acc: number, val) => acc + (Number(val) || 0), 0
);
const awayTeamScore = gameData.value.scoreboard.away.reduce(
  (acc: number, val) => acc + (Number(val) || 0), 0
);

// スコアボードが全て空（null or 0）かチェック
const isScoreboardEmpty = (scoreboardArray: (number | null)[]) => {
  return scoreboardArray.every(val => val === null || val === 0);
};

const homeScoreboardEmpty = isScoreboardEmpty(gameData.value.scoreboard.home);
const awayScoreboardEmpty = isScoreboardEmpty(gameData.value.scoreboard.away);

// 全て空なら score/opponent_score を null に
if (homeScoreboardEmpty && awayScoreboardEmpty) {
  gameData.value.score = null;
  gameData.value.opponent_score = null;
}
// home_away に応じて自チーム得点を設定
else if (gameData.value.home_away === 'home') {
  gameData.value.score = homeTeamScore;
  gameData.value.opponent_score = awayTeamScore;
} else {
  gameData.value.score = awayTeamScore;
  gameData.value.opponent_score = homeTeamScore;
}
```

### スタメン登録フロー

```
[スコアシート画面 (ScoreSheet.vue)]
     ↓
[1. [スタメン登録]ボタンクリック]
   - StartingMemberDialog が開く
   - 既存スタメンデータがあれば初期値として表示
     ↓
[2. ホームチームスタメン入力（左側）]
   - 打順 1-9（DH制で1-10）
   - 守備位置選択（重複不可、キーボードショートカット対応）
   - 選手選択（自チーム選手リストから autocomplete）
   - 守備率が自動表示（守備能力 + スローイング）
     ↓
[3. 対戦相手スタメン入力（右側）]
   - 同様に入力（全選手リストから選択）
     ↓
[4. [保存]ボタンクリック（ダイアログ内）]
   - 入力内容を { homeLineup, opponentLineup } で emit
   - 親コンポーネント (ScoreSheet.vue) が受け取る
     ↓
[5. handleSaveStartingMembers メソッド実行]
   - 打順でソート
   - { player_id, position, order } 形式に変換
   - PATCH /game/{scheduleId} で送信
     ↓
[6a. 保存成功]
   - Snackbar に「スタメン保存成功」メッセージ
   - 打撃記録表が表示される（startingMembers が更新される）
     ↓
[6b. 保存失敗]
   - Snackbar にエラーメッセージ（赤色）
```

### 試合結果判定ロジック

**実装場所:**
- `SeasonSchedule#game_result_hash` モデルメソッド（統合済み）
- `SeasonScheduleSerializer#game_result` はモデルメソッドに委譲
- `GameController#show` は `date < Date.today` の場合のみ `game_result_hash` を呼び出し

**判定条件:**
1. 試合日が過去（`season_schedule.date < Date.today`）— コントローラーでチェック
2. スコアが両方入力済み（`score.present? && opponent_score.present?`）— モデルメソッドでチェック

**判定ロジック:**
```ruby
# SeasonSchedule#game_result_hash
result = if score > opponent_score then "win"
elsif score < opponent_score then "lose"
else "draw"
end
```

**出力形式:**
```json
{
  "opponent_short_name": "白玉",
  "score": "5 - 3",
  "result": "win"
}
```

**注意事項:**
- 未来の試合や未入力の試合では `game_result` は `null`
- **DESIGN-008,009**: `game_number` の計算ロジックと `game_result` の生成ロジックは `SeasonSchedule` モデルに統合済み。コントローラーとシリアライザーの重複は解消

---

## フロントエンド実装詳細

### コンポーネント構成

```
src/
├── views/
│   ├── GameResult.vue           # 試合結果入力画面
│   ├── ScoreSheet.vue           # スコアシート画面
│   └── SeasonPortal.vue         # シーズンポータル（試合一覧リンク元）
├── components/
│   ├── Scoreboard.vue           # スコアボードコンポーネント
│   ├── StartingMemberDialog.vue # スタメン登録ダイアログ
│   └── shared/
│       ├── TeamMemberSelect.vue # チームメンバー選択
│       ├── TeamSelect.vue       # チーム選択
│       └── PlayerSelect.vue     # 選手選択
└── types/
    ├── gameData.ts              # 試合データ型定義
    ├── scoreboard.ts            # スコアボード型定義
    ├── startingMember.ts        # スタメン型定義
    ├── player.ts                # 選手型定義
    └── team.ts                  # チーム型定義
```

### 型定義

#### GameData (`src/types/gameData.ts`)

```typescript
import type { Scoreboard } from './scoreboard';

export interface LineupItem {
  player_id: number;
  position: string;
  order: number;
}

export interface GameData {
  team_id: number;
  team_name: string;
  season_id: number;
  game_date: string;
  game_number: number;
  announced_starter_id: number | null;
  stadium: string;
  home_away: 'home' | 'visitor' | null;
  designated_hitter_enabled: boolean | null;
  opponent_team_id: number | null;
  opponent_team_name: string;
  score: number | null;
  opponent_score: number | null;
  winning_pitcher_id: number | null;
  losing_pitcher_id: number | null;
  save_pitcher_id: number | null;
  scoreboard: Scoreboard | null;
  starting_lineup: LineupItem[] | null;
}
```

**注意**: `opponent_starting_lineup` は型定義に含まれていないが、`ScoreSheet.vue` のデフォルト値では `opponent_starting_lineup: []` として初期化し、APIレスポンスから取得して使用している。

#### Scoreboard (`src/types/scoreboard.ts`)

```typescript
export interface Scoreboard {
  home: (number | null)[];
  away: (number | null)[];
}
```

#### StartingMember (`src/types/startingMember.ts`)

```typescript
import type { Player } from './player';

export interface StartingMember {
  battingOrder: number;
  position: string | null;
  player: Player | null;
}
```

### 主要なコンポーザブル・ユーティリティ

#### axios インスタンス
- `src/main.ts` で全体設定
- Base URL: `/api/v1/`
- CSRF トークン自動付与（Interceptor）

#### i18n
- 国際化は `vue-i18n` を使用
- メッセージキーは `src/locales/ja.json` に定義
- 試合管理関連キー: `gameResult.*`, `scoreSheet.*`, `startingMemberDialog.*`, `baseball.positions.*`

#### ルーティング
- GameResult: `/teams/:teamId/seasons/:seasonId/games/:scheduleId`
- ScoreSheet: `/teams/:teamId/seasons/:seasonId/games/:scheduleId/scoresheet`

### 状態管理

- **GameResult.vue**: `gameData` (ref) で試合情報を一元管理、Scoreboard コンポーネントには v-model で双方向バインディング
- **ScoreSheet.vue**: `gameData`, `startingMembers`, `startingPositions` を分離管理、スタメン情報は `starting_lineup` から復元
- **Scoreboard.vue**: `localScoreboard` でローカル状態を管理、変更時に `emit('update:modelValue')` で親に通知
- **StartingMemberDialog.vue**: `homeLineup`, `opponentLineup` でダイアログ内状態を管理、保存時に emit で親に通知

### API 呼び出しパターン

**試合データ取得 (GameResult.vue, ScoreSheet.vue):**
```typescript
const fetchGameData = async () => {
  try {
    const response = await axios.get(`/game/${scheduleId}`);
    gameData.value = response.data;
    // scoreboard が null の場合は初期化
    if (!gameData.value.scoreboard) {
      gameData.value.scoreboard = {
        home: Array(9).fill(null),
        away: Array(9).fill(null),
      };
    }
  } catch (error) {
    console.error('Failed to fetch game data:', error);
  }
};
```

**試合データ保存 (GameResult.vue):**
```typescript
const saveGame = async () => {
  // スコア計算ロジック（前述）
  // ...

  try {
    await axios.put(`/game/${scheduleId}`, gameData.value);
    showSnackbar(t('gameResult.saveSuccess'));
  } catch (error) {
    console.error('Failed to save game data:', error);
    showSnackbar(t('gameResult.saveFailed'), 'error');
  }
};
```

**スタメン保存 (ScoreSheet.vue):**
```typescript
const handleSaveStartingMembers = async (data: { homeLineup: StartingMember[], opponentLineup: StartingMember[] }) => {
  // LineupItem[] に変換
  const homeLineupToSave = sortedHomeMembers.map(member => ({
    player_id: member.player!.id,
    position: homePositions[member.player!.id].position,
    order: homePositions[member.player!.id].order,
  }));

  const opponentLineupToSave = ...; // 同様

  try {
    await axios.patch(`/game/${scheduleId}`, {
      starting_lineup: homeLineupToSave,
      opponent_starting_lineup: opponentLineupToSave,
    });
    showSnackbar(t('messages.startingMembersSaved'));
  } catch (error) {
    console.error('Failed to save starting members:', error);
    showSnackbar(t('messages.failedToSaveStartingMembers'), 'error');
  }
};
```

### スタイリング

**GameResult.vue:**
- ツールバー: `color="orange-lighten-3"`
- カードレイアウト: Vuetify の `v-card` を使用

**ScoreSheet.vue:**
- ツールバー: `color="green"`
- スコアボード表: カスタムCSS（`.scoreboard-table`）でボーダー、背景色、フォント設定
  - ヘッダー背景: `#fafafa`
  - チーム名列: 左寄せ、右ボーダー
  - イニング得点列: 中央揃え、等幅フォント（`Roboto Mono`）
  - 合計列: 太字、背景色 `#f5f5f5`
- 打撃記録表: `.batting-record-table` で中央揃え、最小幅設定

**Scoreboard.vue:**
- デフォルトの Vuetify テーブルスタイル使用
- イニング追加/削除ボタン: `v-btn` (class="mt-2")
- サヨナラチェックボックス: `v-checkbox` (class="mt-2 d-inline-flex")

**StartingMemberDialog.vue:**
- ダイアログ最大幅: `1200px`
- 2カラムレイアウト（`v-row` + `v-col cols="12" md="6"`）
- 守備位置セレクト幅: `150px`
- テーブルは Vuetify の `v-table` を使用

---

## 既知の制約・未実装機能

1. ~~**バックエンドのタイポ:**~~ → **修正済み (cmd_142)**: `oppnent_*` カラムを `opponent_*` にリネーム、変換コード除去済み

2. **打撃記録の自動集計未実装 (ScoreSheet.vue):**
   - 打撃記録入力欄は存在するが、「安打」「打点」列の自動計算機能なし
   - `battingResults` はローカル状態のみで保存機能なし

3. ~~**game_number の重複実装:**~~ → **修正済み (DESIGN-008)**: `SeasonSchedule#calculated_game_number` モデルメソッドに統合。コントローラーはモデルメソッドを呼び出すのみ

4. ~~**game_result の重複実装:**~~ → **修正済み (DESIGN-009)**: `SeasonSchedule#game_result_hash` モデルメソッドに統合。シリアライザーもモデルメソッドに委譲

5. ~~**バリデーション未定義:**~~ → **一部修正済み**: `home_away` の値制約（`'home'` / `'visitor'` のみ許可）が `validates :home_away, inclusion: { in: ["home", "visitor"] }, allow_blank: true` としてモデルレベルで定義済み

6. **CSRF トークン:**
   - ログインエンドポイント以外は全てCSRF保護が有効
   - フロントエンドの axios interceptor で自動付与

7. **GameData 型と opponent_starting_lineup:**
   - `GameData` 型定義（`gameData.ts`）に `opponent_starting_lineup` フィールドが未定義
   - `ScoreSheet.vue` のデフォルト値では `starting_lineup: []`, `opponent_starting_lineup: []` として初期化しているが、型定義には `starting_lineup` のみ

---

## 参考資料

- **バックエンド:**
  - `app/controllers/api/v1/game_controller.rb` (75行)
  - `app/models/season_schedule.rb` (32行 — `calculated_game_number`, `game_result_hash` メソッド含む)
  - `app/serializers/season_schedule_serializer.rb` (17行 — `game_result` は `game_result_hash` に委譲)
  - `db/schema.rb` (season_schedules テーブル定義: line 291-317)
  - `config/routes.rb` (line 33)

- **フロントエンド:**
  - `src/views/GameResult.vue` (314行)
  - `src/views/ScoreSheet.vue` (543行)
  - `src/components/Scoreboard.vue` (129行)
  - `src/components/StartingMemberDialog.vue` (317行)
  - `src/types/gameData.ts` (28行)
  - `src/types/scoreboard.ts` (5行)
  - `src/types/startingMember.ts` (8行)

---

**最終更新:** 2026-02-21
**作成者:** 足軽2号（マルチエージェントシステム）
**参照ソースコード:** 東方BIG野球まとめ (thbigmatome / thbigmatome-front)
