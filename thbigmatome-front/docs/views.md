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
- `src/views/CostAssignment.vue`
- `src/views/Settings.vue`
- `src/views/CompetitionRosterView.vue`
- `src/views/PlayerCardsView.vue`
- `src/views/PlayerCardDetailView.vue`
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
| `/competitions/:id/roster/:teamId` | `CompetitionRoster` | `CompetitionRosterView` | `id`, `teamId` | 要（authGuard） |
| `/player-cards` | `PlayerCards` | `PlayerCardsView` | — | 要（authGuard） |
| `/player-cards/:id` | `PlayerCardDetail` | `PlayerCardDetailView` | `id` | 要（authGuard） |
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
- **主要機能・目的**: ログイン後の入口。コミッショナーはダッシュボード（CommissionerDashboard）を出す。それ以外はチームが1件なら SeasonPortal をその場に埋め込み、2件以上ならチーム切り替えのタブの下に SeasonPortal を置く
- **使用APIエンドポイント**: なし（チームは `useAuth` がログイン時に `useTeamSelectionStore` へ読み込み済み）
- **主要なcomposable/store**: `useTeamSelectionStore`（Pinia）, `useAuth`
- **ヘッダーバー**: コミッショナーとチーム0件は `route.meta.title`（ホーム）。チームを出している時は、埋め込んだ SeasonPortal が宣言するチーム名＋「シーズン」
- **画面構成**: `PageLayout`（コミッショナー: ダッシュボード / チーム0件: 空状態 `AsyncState`（コミッショナーへの問い合わせを示す））。SeasonPortal は自分の骨格を持つので二重に包まない。チーム2件以上のタブだけは下余白を詰めた `PageLayout` に置く
- **他画面への遷移先**: `/teams/:teamId/season`（SeasonPortal、埋め込み）

---

### 2.3 ホーム（レガシー）

- **画面名**: ホーム / HomeView
- **ルートパス**: `/home`
- **主要機能・目的**: 大会ごとの試合サマリー表示（旧ホーム画面）
- **使用APIエンドポイント**:
  - GET `/competitions`
  - GET `/home/summary?competition_id=N`
- **主要なcomposable/store**: なし（直接axios）
- **ヘッダーバー**: `route.meta.title`（ホーム（旧））
- **画面構成**: `PageLayout`（大会選択・試合サマリーカード）
- **他画面への遷移先**: なし（参照のみ）。直近の試合結果の行は、行き先の画面（`/games/:id`）が無くなったのでリンクにしていない（cmd_1795）
- **備考**: 成績サマリーの元になる集計（`/home/summary`）は、パーサー経由で入った打席を使う。旧ホームを残すか消すかは未決

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
- **主要なcomposable/store**: `useRoute`, `useRouter`, `useAppBarTitle`
- **ヘッダーバー**: タイトル=選手名、サブタイトル=`#背番号`、戻り先=「← 選手一覧」（`/players`）。取得前・取得失敗でも戻り先は出る
- **画面構成**: `PageLayout` ＋ `AsyncState`（読み込み=スケルトン、失敗=アラート＋再読み込み）。基本情報（背番号・選手名・略称・所属作品）・コスト表・選手カード一覧テーブルを1枚のカードに収め、PlayerDialog で編集
- **他画面への遷移先**: `/player-cards/:id`（PlayerCardDetailView）、`/players`（バーの戻り先）

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
- **主要なcomposable/store**: `useSnackbar`, `useAppBarTitle`
- **ヘッダーバー**: 単独の画面として開いた時（props に `teamId` が無い）のみ、タイトル=チーム名（`GET /teams/:id`）、サブタイトル=チーム編成、戻り先=「← シーズン」。シーズンのタブ・試合日ページへ埋め込まれた時（`teamId` を props で受ける）はバーを変えず、骨格（`PageLayout`）も持たず中身だけを出す
- **画面構成**: 違反表示・選手追加UI（ポジション絞り込み・選手選択・カード版・追加ボタン）・メンバー表（人数/コストのゲージ付き）・保存/キャンセル。表は `AsyncState` で包み、読み込み中は「選手が登録されていません」を出さず、取得失敗はアラート＋再読み込み
- **他画面への遷移先**: `/teams/:teamId/season`（バーの戻り先）

---

### 2.9 シーズンポータル

- **画面名**: シーズンポータル / SeasonPortal
- **ルートパス**: `/teams/:teamId/season`
- **主要機能・目的**: チームのシーズン管理ハブ。タブでカレンダー・ロスター・欠場履歴・メンバー・昇降格履歴を管理（オーダー・成績のタブは非表示にしていたが、成績の分は cmd_1795 で記述ごと削除）
- **使用APIエンドポイント**:
  - GET `/teams/:id/season`
  - PATCH `/teams/:id/season/season_schedules/:id`（試合日程更新）
  - GET `/teams/:id`
- **主要なcomposable/store**: `useTeamSelectionStore`（Pinia）
- **画面構成**:
  - `calendar` タブ: 試合カレンダー・結果入力
  - `roster` タブ: 登録選手ロスター（ActiveRosterコンポーネント）
  - `absences` タブ: 欠場履歴（PlayerAbsenceHistoryコンポーネント）
  - `members` タブ: チームメンバー
  - `lineup` タブ: 試合オーダー
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

### 2.12 （欠番）試合一覧

廃止済み（cmd_1795）。画面 `/games`（GamesView）を削除した。番号は他の節の参照を保つため欠番にしている。

---

### 2.13 （欠番）試合インポート

廃止済み（cmd_1791）。IRC ログを取り込む画面 `/games/import`（GameImportView）と、裏の `POST /games/parse_log`・`POST /games/import_log` を削除した。番号は他の節の参照を保つため欠番にしている。

---

### 2.14 （欠番）試合詳細

廃止済み（cmd_1795）。画面 `/games/:id`（GameDetailView）を削除した。番号は他の節の参照を保つため欠番にしている。

---

### 2.15 （欠番）試合ラインナップ

廃止済み（cmd_1795）。画面 `/games/:id/lineup`（GameLineupView）と、裏の `/games/:game_id/lineup` API を削除した。番号は他の節の参照を保つため欠番にしている。

---

### 2.16 （欠番）成績集計

廃止済み（cmd_1795）。画面 `/stats`（StatsView）と、裏の `/stats/batting|pitching|team` API を削除した。番号は他の節の参照を保つため欠番にしている。

---

### 2.17 コスト割り当て

- **画面名**: コスト割り当て / CostAssignment
- **ルートパス**: `/cost_assignment`
- **主要機能・目的**: 選手カードへのコスト値割り当て管理
- **使用APIエンドポイント**:
  - GET `/cost_assignments?cost_id=N`
  - POST `/cost_assignments`
- **主要なcomposable/store**: `useSnackbar`
- **ヘッダーバー**: `route.meta.title`（コスト登録）
- **画面構成**: `PageLayout`（wide）の1枚のカード。コスト一覧の選択・選手ごとのコスト入力表・保存。取得失敗はアラート＋再読み込み、保存の成否はスナックバー
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
- **ヘッダーバー**: タイトル=大会名、サブタイトル=大会ロスター、戻り先=「← 大会管理」（`/commissioner/competitions`）
- **画面構成**: `PageLayout`（wide）。コストサマリー・コスト超過アラート・タブ（ロスター/昇降格履歴）・1軍/2軍の登録済みロスターテーブル・選手追加ダイアログ。ロスターの取得失敗はアラート＋再読み込み
- **他画面への遷移先**: `/commissioner/competitions`（バーの戻り先）

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
- **主要機能・目的**: 選手カードの詳細情報表示・編集（基本情報・守備値・特徴/能力）
- **使用APIエンドポイント**:
  - GET `/player_cards/:id`
  - PATCH `/player_cards/:id`（基本情報・守備値・特徴/能力の各編集ダイアログで個別保存）
- **主要なcomposable/store**: `useAppBarTitle`
- **ヘッダーバー**: タイトル=選手名、サブタイトル=`#背番号 ・ カードセット名`、戻り先=「← 選手カード」（`/player-cards`）。取得前・取得失敗でも戻り先は出る
- **画面構成**: `PageLayout` ＋ `AsyncState`。1枚のカードに次を積む
  - 基本情報（種別チップ・画像・走力/バント/盗塁開始・終了/怪我レベル/利き腕・打席/スタミナ/バイオリズム・クローザー等のフラグ）
  - 守備値テーブル
  - 特徴・能力（特徴と能力のチップ、固有特徴テキスト `unique_traits`、怪我特徴）
  - コスト一覧（現行コストを強調）
  - 投球P列（投手のみ）・打撃結果表
- **他画面への遷移先**: `/player-cards`（PlayerCardsView、バーの戻り先）

---

### 2.22 （欠番）ゲームレコード一覧

廃止済み（cmd_1795）。画面 `/game-records`（GameRecordListView）を削除した。番号は他の節の参照を保つため欠番にしている。

---

### 2.23 （欠番）ゲームレコード詳細

廃止済み（cmd_1795）。画面 `/game-records/:id`（GameRecordDetailView）と AtBatCard を削除した。番号は他の節の参照を保つため欠番にしている。

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
