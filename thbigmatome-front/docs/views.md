# 画面仕様書 (views.md)

最終更新日: 2026-03-10

## 参照ソースファイル一覧

- `src/router/index.ts`
- `src/views/LoginForm.vue`
- `src/views/HomePortalView.vue`
- `src/views/HomeView.vue`
- `src/views/ManagerList.vue`
- `src/views/Players.vue`
- `src/views/PlayerDetailView.vue`
- `src/views/TeamList.vue`
- `src/views/TeamMembers.vue`
- `src/views/SeasonPortal.vue`
- `src/views/GameResult.vue`
- `src/views/ScoreSheet.vue`
- `src/views/GamesView.vue`
- `src/views/GameImportView.vue`
- `src/views/GameDetailView.vue`
- `src/views/GameLineupView.vue`
- `src/views/StatsView.vue`
- `src/views/CostAssignment.vue`
- `src/views/Settings.vue`
- `src/views/CompetitionRosterView.vue`
- `src/views/PlayerCardsView.vue`
- `src/views/PlayerCardDetailView.vue`
- `src/views/GameRecordListView.vue`
- `src/views/GameRecordDetailView.vue`
- `src/views/ActiveRoster.vue` ※ルーター未登録（レガシー）
- `src/views/PlayerAbsenceHistory.vue` ※ルーター未登録（レガシー）
- `src/views/commissioner/CardSetsView.vue`
- `src/views/commissioner/StadiumsView.vue`
- `src/views/commissioner/CompetitionsView.vue`
- `src/views/commissioner/UsersView.vue`

---

## 1. ルーティング一覧

| パス | ルート名 | コンポーネント | パラメータ | 認証要否 |
|------|---------|--------------|-----------|---------|
| `/login` | `Login` | `LoginForm` | — | 不要 |
| `/` | `ホーム` | `HomePortalView` | — | 要（authGuard） |
| `/home` | — | `HomeView` | — | 要（authGuard） |
| `/managers` | `監督一覧` | `ManagerList` | — | 要（authGuard） |
| `/players` | `Players` | `Players` | — | 要（authGuard） |
| `/players/:id` | `PlayerDetail` | `PlayerDetailView` | `id` | 要（authGuard） |
| `/teams` | `TeamList` | `TeamList` | — | 要（authGuard） |
| `/teams/:teamId/members` | `TeamMembers` | `TeamMembers` | `teamId` | 要（authGuard） |
| `/cost_assignment` | `CostAssignment` | `CostAssignment` | — | 要（authGuard） |
| `/settings` | `各種設定` | `Settings` | — | 要（authGuard） |
| `/teams/:teamId/season` | `SeasonPortal` | `SeasonPortal` | `teamId` | 要（authGuard） |
| `/teams/:teamId/season/games/:scheduleId` | `GameResult` | `GameResult` | `teamId`, `scheduleId` | 要（authGuard） |
| `/teams/:teamId/season/games/:scheduleId/scoresheet` | `ScoreSheet` | `ScoreSheet` | `teamId`, `scheduleId` | 要（authGuard） |
| `/games` | `試合記録` | `GamesView` | — | 要（authGuard） |
| `/games/import` | `ログ取り込み` | `GameImportView` | — | 要（authGuard） |
| `/games/:id` | `試合詳細` | `GameDetailView` | `id` | 要（authGuard） |
| `/games/:id/lineup` | `GameLineup` | `GameLineupView` | `id` | 要（authGuard） |
| `/stats` | `成績集計` | `StatsView` | — | 要（authGuard） |
| `/competitions/:id/roster/:teamId` | `CompetitionRoster` | `CompetitionRosterView` | `id`, `teamId` | 要（authGuard） |
| `/player-cards` | `PlayerCards` | `PlayerCardsView` | — | 要（authGuard） |
| `/player-cards/:id` | `PlayerCardDetail` | `PlayerCardDetailView` | `id` | 要（authGuard） |
| `/game-records` | `GameRecordList` | `GameRecordListView` | — | 要（authGuard） |
| `/game-records/:id` | `GameRecordDetail` | `GameRecordDetailView` | `id` | 要（authGuard） |
| `commissioner/stadiums` | `Stadiums` | `StadiumsView` | — | 要（requiresCommissioner） |
| `commissioner/card_sets` | `CardSets` | `CardSetsView` | — | 要（requiresCommissioner） |
| `commissioner/competitions` | `Competitions` | `CompetitionsView` | — | 要（requiresCommissioner） |
| `commissioner/users` | `Users` | `UsersView` | — | 要（requiresCommissioner） |

### リダイレクトルート

| 元パス | 遷移先 | 備考 |
|--------|--------|------|
| `commissioner/leagues` | `commissioner/competitions` | 旧パス互換 |
| `/teams/:teamId/roster` | `/teams/:teamId/season?tab=roster` | rosterタブへリダイレクト |
| `/teams/:teamId/season/player_absences` | `/teams/:teamId/season?tab=absences` | absencesタブへリダイレクト |
| `commissioner/players` | `/players` | commissioner配下を通常パスへ |
| `/:pathMatch(.*)*` | `/` | 未知パスはHomePortalへ |

---

## 2. 各画面の仕様

### 2.1 ログイン画面

- **画面名**: ログイン / LoginForm
- **ルートパス**: `/login`
- **主要機能・目的**: メールアドレス・パスワードによるログイン認証
- **使用APIエンドポイント**:
  - POST `/auth/login`（useAuth composable経由）
- **主要なcomposable/store**: `useAuth`
- **画面構成**: ロゴ・ログインフォーム（email/password）・ログインボタン
- **他画面への遷移先**: ログイン成功 → `HomePortal`（`/`）

---

### 2.2 ホームポータル

- **画面名**: ホームポータル / HomePortalView
- **ルートパス**: `/`
- **主要機能・目的**: ログイン後の入口。チームが1件の場合は自動的にSeasonPortalへリダイレクト。複数チームの場合はチーム選択へ
- **使用APIエンドポイント**:
  - GET `/teams`
- **主要なcomposable/store**: `useTeamSelectionStore`（Pinia）
- **画面構成**: チーム一覧表示 → チーム選択
- **他画面への遷移先**: `/teams/:teamId/season`（SeasonPortal）

---

### 2.3 ホーム（レガシー）

- **画面名**: ホーム / HomeView
- **ルートパス**: `/home`
- **主要機能・目的**: 大会ごとの試合サマリー表示（旧ホーム画面）
- **使用APIエンドポイント**:
  - GET `/competitions`
  - GET `/home/summary?competition_id=N`
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: 大会選択タブ・試合サマリーカード
- **他画面への遷移先**: なし（参照のみ）

---

### 2.4 監督一覧

- **画面名**: 監督一覧 / ManagerList
- **ルートパス**: `/managers`
- **主要機能・目的**: チームの監督一覧表示・追加・編集・削除
- **使用APIエンドポイント**:
  - GET `/managers`
  - DELETE `/managers/:id`
  - POST `/managers`（ManagerDialog経由）
  - PATCH `/managers/:id`（ManagerDialog経由）
- **主要なcomposable/store**: `useSnackbar`, `useI18n`
- **画面構成**: データテーブル（監督名・チーム・操作）・ManagerDialogコンポーネント・ConfirmDialog
- **他画面への遷移先**: なし

---

### 2.5 選手一覧

- **画面名**: 選手一覧 / Players
- **ルートパス**: `/players`
- **主要機能・目的**: 選手の一覧表示・検索・追加・編集・削除、選手のカード数確認
- **使用APIエンドポイント**:
  - GET `/players`
  - DELETE `/players/:id`
  - POST `/players`（PlayerDialog経由）
  - PATCH `/players/:id`（PlayerDialog経由）
- **主要なcomposable/store**: `useSnackbar`, `useI18n`, `useDisplay`
- **画面構成**: 検索フィールド・データテーブル（背番号/名前/短縮名/カード数/操作）・PlayerDialogコンポーネント・ConfirmDialog
- **他画面への遷移先**: `/players/:id`（PlayerDetailView、カード数リンクから）

---

### 2.6 選手詳細

- **画面名**: 選手詳細 / PlayerDetailView
- **ルートパス**: `/players/:id`
- **主要機能・目的**: 選手の詳細情報・所持選手カード一覧の表示・編集
- **使用APIエンドポイント**:
  - GET `/players/:id`
  - PATCH `/players/:id`（PlayerDialog経由）
- **主要なcomposable/store**: `useRoute`, `useRouter`
- **画面構成**: 選手基本情報（名前・背番号）・選手カード一覧テーブル・PlayerDialogコンポーネント
- **他画面への遷移先**: `/player-cards/:id`（PlayerCardDetailView）

---

### 2.7 チーム一覧

- **画面名**: チーム一覧 / TeamList
- **ルートパス**: `/teams`
- **主要機能・目的**: チームの一覧表示・追加・編集・削除
- **使用APIエンドポイント**:
  - GET `/teams`
  - DELETE `/teams/:id`
  - POST `/teams`（TeamDialog経由）
  - PATCH `/teams/:id`（TeamDialog経由）
- **主要なcomposable/store**: `useSnackbar`, `useI18n`
- **画面構成**: データテーブル（チーム名・略称・操作）・TeamDialogコンポーネント・ConfirmDialog
- **他画面への遷移先**: なし

---

### 2.8 チームメンバー

- **画面名**: チームメンバー / TeamMembers
- **ルートパス**: `/teams/:teamId/members`
- **主要機能・目的**: チームへの選手登録・コスト・ポジションタイプの設定
- **使用APIエンドポイント**:
  - GET `/team_registration_players`
  - GET `/teams/:id/team_players`
  - POST `/teams/:id/team_players`
  - GET `/costs`
  - GET `/player-types`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: 登録済みメンバーテーブル・選手追加UI・コスト/タイプ選択
- **他画面への遷移先**: なし

---

### 2.9 シーズンポータル

- **画面名**: シーズンポータル / SeasonPortal
- **ルートパス**: `/teams/:teamId/season`
- **主要機能・目的**: チームのシーズン管理ハブ。6つのタブでカレンダー・ロスター・欠場履歴・メンバー・オーダー・成績を管理
- **使用APIエンドポイント**:
  - GET `/teams/:id/season`
  - PATCH `/teams/:id/season`
  - PATCH `/teams/:id/season/season_schedules/:id`（試合日程更新）
  - GET `/teams/:id`
- **主要なcomposable/store**: `useTeamSelectionStore`（Pinia）
- **画面構成**:
  - `calendar` タブ: 試合カレンダー・結果入力
  - `roster` タブ: 登録選手ロスター（ActiveRosterコンポーネント）
  - `absences` タブ: 欠場履歴（PlayerAbsenceHistoryコンポーネント）
  - `members` タブ: チームメンバー
  - `lineup` タブ: 試合オーダー
  - `stats` タブ: シーズン成績
- **他画面への遷移先**:
  - `/teams/:teamId/season/games/:scheduleId`（GameResult）
  - `/teams/:teamId/season/games/:scheduleId/scoresheet`（ScoreSheet）

---

### 2.10 試合結果入力

- **画面名**: 試合結果 / GameResult
- **ルートパス**: `/teams/:teamId/season/games/:scheduleId`
- **主要機能・目的**: シーズンスケジュール単位の試合結果（スコア・スターティングメンバー等）入力
- **使用APIエンドポイント**:
  - GET `/game/:scheduleId`
  - PUT `/game/:scheduleId`
  - GET `/players`
  - GET `/teams`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: スコア入力フォーム・先発オーダーテーブル・保存ボタン
- **他画面への遷移先**:
  - `/teams/:teamId/season/games/:scheduleId/scoresheet`（ScoreSheet）
  - `/teams/:teamId/season`（SeasonPortal、戻るボタン）

---

### 2.11 スコアシート

- **画面名**: スコアシート / ScoreSheet
- **ルートパス**: `/teams/:teamId/season/games/:scheduleId/scoresheet`
- **主要機能・目的**: 試合のスコアシート（イニングごとの打順・成績）入力・管理
- **使用APIエンドポイント**:
  - GET `/game/:scheduleId`
  - PATCH `/game/:scheduleId`（先発ラインナップ更新）
  - GET `/teams/:id/team_players`
  - GET `/players`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: イニング別スコアシートグリッド・打者/投手成績入力
- **他画面への遷移先**: `/teams/:teamId/season/games/:scheduleId`（GameResult、戻るボタン）

---

### 2.12 試合一覧

- **画面名**: 試合一覧 / GamesView
- **ルートパス**: `/games`
- **主要機能・目的**: 全試合の一覧表示・大会フィルタリング
- **使用APIエンドポイント**:
  - GET `/games`（フィルタパラメータあり）
  - GET `/competitions`
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: 大会フィルター・試合一覧テーブル（日付/対戦/スコア/大会）
- **他画面への遷移先**:
  - `/games/:id`（GameDetailView）
  - `/games/import`（GameImportView）
  - `/games/:id/lineup`（GameLineupView）

---

### 2.13 試合インポート

- **画面名**: 試合インポート / GameImportView
- **ルートパス**: `/games/import`
- **主要機能・目的**: ゲームログテキストの解析・インポート
- **使用APIエンドポイント**:
  - POST `/games/parse_log`（ログ解析プレビュー）
  - POST `/games/import_log`（実際のインポート）
  - GET `/competitions`
  - GET `/competitions/:id/teams`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: テキストエリア（ログ入力）・解析プレビュー・大会/チーム選択・インポートボタン
- **他画面への遷移先**: `/games`（GamesView、インポート完了後）

---

### 2.14 試合詳細

- **画面名**: 試合詳細 / GameDetailView
- **ルートパス**: `/games/:id`
- **主要機能・目的**: 個別試合の詳細情報表示（スコア・打席結果等）
- **使用APIエンドポイント**:
  - GET `/games/:id`
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: 試合基本情報・イニング別スコア・打席結果テーブル
- **他画面への遷移先**:
  - `/games/:id/lineup`（GameLineupView）
  - `/games`（GamesView、戻るボタン）

---

### 2.15 試合ラインナップ

- **画面名**: 試合ラインナップ / GameLineupView
- **ルートパス**: `/games/:id/lineup`
- **主要機能・目的**: 試合ごとのラインナップ（打順・ポジション）表示
- **使用APIエンドポイント**:
  - GET `/games/:id/lineup`
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: ホーム/ビジターのラインナップテーブル（打順/名前/ポジション）
- **他画面への遷移先**: `/games/:id`（GameDetailView、戻るボタン）

---

### 2.16 成績集計

- **画面名**: 成績集計 / StatsView
- **ルートパス**: `/stats`
- **主要機能・目的**: 大会別の打撃・投手・チーム成績集計表示
- **使用APIエンドポイント**:
  - GET `/competitions`
  - GET `/stats/batting`（大会IDパラメータ）
  - GET `/stats/pitching`（大会IDパラメータ）
  - GET `/stats/team`（大会IDパラメータ）
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: 大会選択・タブ（打撃成績/投手成績/チーム成績）・各成績テーブル
- **他画面への遷移先**: なし

---

### 2.17 コスト割り当て

- **画面名**: コスト割り当て / CostAssignment
- **ルートパス**: `/cost_assignment`
- **主要機能・目的**: 選手カードへのコスト値割り当て管理
- **使用APIエンドポイント**:
  - GET `/cost_assignments?cost_id=N`
  - POST `/cost_assignments`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: コスト区分選択・未割り当て/割り当て済みカードテーブル・割り当てボタン
- **他画面への遷移先**: なし

---

### 2.18 設定

- **画面名**: 設定 / Settings
- **ルートパス**: `/settings`
- **主要機能・目的**: システム設定（投球スタイル・打撃スタイル・選手タイプ・バイオリズム・コスト・スケジュール）の管理
- **使用APIエンドポイント**: 各設定コンポーネント（PitchingStyle/BattingStyle/PlayerType/Biorhythm/Cost/Schedule）が個別にAPIを呼び出す
- **主要なcomposable/store**: なし（直接axios・サブコンポーネント経由）
- **画面構成**: タブ構成で各設定コンポーネントを切り替え
- **他画面への遷移先**: なし

---

### 2.19 大会ロスター

- **画面名**: 大会ロスター / CompetitionRosterView
- **ルートパス**: `/competitions/:id/roster/:teamId`
- **主要機能・目的**: 大会エントリーのロスター管理（選手カードの追加・削除・コストチェック）
- **使用APIエンドポイント**:
  - GET `/competitions/:id`
  - GET `/competitions/:id/roster`
  - GET `/competitions/:id/roster/cost_check`
  - POST `/competitions/:id/roster/players`
  - DELETE `/competitions/:id/roster/players/:id`
  - GET `/player_cards`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: 大会情報・登録済みロスターテーブル・選手カード追加UI・コストチェック表示
- **他画面への遷移先**: なし

---

### 2.20 選手カード一覧

- **画面名**: 選手カード一覧 / PlayerCardsView
- **ルートパス**: `/player-cards`
- **主要機能・目的**: 選手カードの一覧表示（テーブル/グリッド切替）・フィルタリング・ページネーション
- **使用APIエンドポイント**:
  - GET `/card_sets`
  - GET `/player_cards`（`page`, `per_page`, `card_set_id`, `card_type`, `name` パラメータ）
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**:
  - フィルタバー（カードセット選択/種別ボタン/名前検索/表示切替）
  - テーブル表示: 背番号/選手名/種別/ポジション/走力/コスト/カードセット
  - グリッド表示: PlayerCardItemコンポーネント（カード形式）
  - ページネーション（50件/ページ）
- **他画面への遷移先**: `/player-cards/:id`（PlayerCardDetailView）

---

### 2.21 選手カード詳細

- **画面名**: 選手カード詳細 / PlayerCardDetailView
- **ルートパス**: `/player-cards/:id`
- **主要機能・目的**: 選手カードの詳細情報表示・編集（基本情報・守備・特殊スキル）
- **使用APIエンドポイント**:
  - GET `/player_cards/:id`
  - PATCH `/player_cards/:id`（基本情報、守備情報、特殊スキル各セクションで個別保存）
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**:
  - カード基本情報（選手名/背番号/種別/カードセット/コスト/画像）
  - 共通能力（走力/盗塁/負傷率）
  - 投手能力（球種・コントロール等）または野手能力（打撃・守備等）
  - 守備位置テーブル
  - 特殊スキル一覧
- **他画面への遷移先**: `/player-cards`（PlayerCardsView、戻るボタン）

---

### 2.22 ゲームレコード一覧

- **画面名**: ゲームレコード一覧 / GameRecordListView
- **ルートパス**: `/game-records`
- **主要機能・目的**: ゲームレコード（IRC試合ログ）の一覧表示
- **使用APIエンドポイント**:
  - GET `/game_records`
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: ゲームレコード一覧テーブル（日付/対戦チーム/スコア/ステータス）
- **他画面への遷移先**: `/game-records/:id`（GameRecordDetailView）

---

### 2.23 ゲームレコード詳細

- **画面名**: ゲームレコード詳細 / GameRecordDetailView
- **ルートパス**: `/game-records/:id`
- **主要機能・目的**: 個別ゲームレコードの打席結果確認・修正・確定
- **使用APIエンドポイント**:
  - GET `/game_records/:id`
  - PATCH `/at_bat_records/:id`（打席結果修正）
  - POST `/game_records/:id/confirm`（レコード確定）
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: ゲーム基本情報・イニング別打席結果テーブル・結果編集モーダル・確定ボタン
- **他画面への遷移先**: `/game-records`（GameRecordListView、戻るボタン）

---

### 2.24 スタジアム管理（コミッショナー）

- **画面名**: スタジアム管理 / StadiumsView
- **ルートパス**: `/commissioner/stadiums`
- **主要機能・目的**: スタジアムの一覧表示・追加・編集（コミッショナー専用）
- **使用APIエンドポイント**:
  - GET `/stadiums`
  - POST `/stadiums`
  - PATCH `/stadiums/:id`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: スタジアム一覧テーブル・StadiumDialogコンポーネント
- **他画面への遷移先**: なし

---

### 2.25 カードセット管理（コミッショナー）

- **画面名**: カードセット管理 / CardSetsView
- **ルートパス**: `/commissioner/card_sets`
- **主要機能・目的**: カードセット（年度ごとのカードコレクション）の一覧表示・詳細確認（コミッショナー専用）
- **使用APIエンドポイント**:
  - GET `/card_sets`
  - GET `/card_sets/:id`
- **主要なcomposable/store**: なし（直接axios）
- **画面構成**: カードセット一覧テーブル・選択時の詳細パネル
- **他画面への遷移先**: なし

---

### 2.26 大会管理（コミッショナー）

- **画面名**: 大会管理 / CompetitionsView
- **ルートパス**: `/commissioner/competitions`
- **主要機能・目的**: 大会の一覧表示・追加・編集・削除（コミッショナー専用）
- **使用APIエンドポイント**:
  - GET `/competitions`
  - POST `/competitions`
  - PATCH `/competitions/:id`
  - DELETE `/competitions/:id`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: 大会一覧テーブル・CompetitionDialogコンポーネント・ConfirmDialog
- **他画面への遷移先**: `/competitions/:id/roster/:teamId`（CompetitionRosterView）

---

### 2.27 ユーザー管理（コミッショナー）

- **画面名**: ユーザー管理 / UsersView
- **ルートパス**: `/commissioner/users`
- **主要機能・目的**: ユーザーアカウントの一覧表示・追加・パスワードリセット（コミッショナー専用）
- **使用APIエンドポイント**:
  - GET `/users`
  - POST `/users`
  - PATCH `/users/:id/reset_password`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: ユーザー一覧テーブル（名前/メール/権限）・UserDialogコンポーネント・パスワードリセットボタン
- **他画面への遷移先**: なし

---

### 2.28 アクティブロスター（レガシー・ルーター未登録）

- **画面名**: アクティブロスター / ActiveRoster
- **ルートパス**: ※ルーター未登録（SeasonPortalのrosterタブ内でコンポーネントとして使用）
- **主要機能・目的**: チームの登録選手（アクティブロスター）表示・キープレイヤー設定
- **使用APIエンドポイント**:
  - GET `/teams/:id/roster`
  - POST `/teams/:id/roster`
  - POST `/teams/:id/key_player`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: 登録選手テーブル・キープレイヤー設定ボタン
- **他画面への遷移先**: SeasonPortalに組み込み

---

### 2.29 欠場履歴（レガシー・ルーター未登録）

- **画面名**: 欠場履歴 / PlayerAbsenceHistory
- **ルートパス**: ※ルーター未登録（SeasonPortalのabsencesタブ内でコンポーネントとして使用）
- **主要機能・目的**: 選手の欠場履歴確認・削除
- **使用APIエンドポイント**:
  - GET `/teams/:id/season`
  - GET `/player_absences`
  - DELETE `/player_absences/:id`
- **主要なcomposable/store**: `useSnackbar`
- **画面構成**: 欠場履歴テーブル・削除ボタン
- **他画面への遷移先**: SeasonPortalに組み込み

---

## 3. 画面遷移図（テキストベース）

```
[未認証]
  └─ /login (LoginForm)
       └─ ログイン成功 ──────────────────────────────┐
                                                      ↓
[認証済み - メインナビゲーション]                   / (HomePortalView)
                                                      │
                              ┌───────────────────────┤
                              │ チームが1件のみ         │ 複数チーム
                              ↓                        ↓
                    /teams/:teamId/season        チーム選択
                    (SeasonPortal)               (HomePortalView内)
                              │
          ┌───────────────────┼──────────────────────┐
          │ [calendarタブ]    │                       │ [rosterタブ]
          ↓                   │                       ↓
  /teams/:teamId/season/      │               ActiveRoster.vue
  games/:scheduleId           │               (コンポーネント)
  (GameResult)                │
          │              [absencesタブ]
          ↓              PlayerAbsenceHistory.vue
  /teams/:teamId/season/  (コンポーネント)
  games/:scheduleId/
  scoresheet
  (ScoreSheet)
          │
          └─ 戻る ──── /teams/:teamId/season
                        (SeasonPortal)

[グローバルナビゲーション]
  /players (Players)
      └─ /players/:id (PlayerDetailView)
              └─ /player-cards/:id (PlayerCardDetailView)
                        └─ /player-cards (PlayerCardsView)

  /teams (TeamList)
  /teams/:teamId/members (TeamMembers)

  /games (GamesView)
      ├─ /games/import (GameImportView)
      │       └─ インポート完了 → /games
      ├─ /games/:id (GameDetailView)
      │       └─ /games/:id/lineup (GameLineupView)
      └─ 戻る → /games

  /game-records (GameRecordListView)
      └─ /game-records/:id (GameRecordDetailView)
              └─ 戻る → /game-records

  /stats (StatsView)
  /cost_assignment (CostAssignment)
  /managers (ManagerList)
  /settings (Settings)

[コミッショナー専用]
  commissioner/competitions (CompetitionsView)
      └─ /competitions/:id/roster/:teamId (CompetitionRosterView)
  commissioner/stadiums (StadiumsView)
  commissioner/card_sets (CardSetsView)
  commissioner/users (UsersView)

[リダイレクト]
  commissioner/leagues ──────→ commissioner/competitions
  /teams/:teamId/roster ──────→ /teams/:teamId/season?tab=roster
  /teams/:teamId/season/
    player_absences ──────────→ /teams/:teamId/season?tab=absences
  commissioner/players ───────→ /players
  /* (未知パス) ───────────────→ / (HomePortalView)
```

---

*この文書は `src/router/index.ts` および `src/views/` 以下の全Vueファイルを直接参照して作成しました。推測による記述はありません。*
