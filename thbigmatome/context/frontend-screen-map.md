# THBIG Dugout フロントエンド画面構成マップ

**最終更新**: 2026-03-20
**対象**: thbigmatome-front (`/home/morinaga/projects/thbigmatome-front/`)
**ルーター定義**: `src/router/index.ts`

---

## 画面一覧

### 共通

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/login` | Login | `LoginForm.vue` | ログイン画面 | 不要 |
| `/` | ホーム | `HomePortalView.vue` | ホームポータル（現行） | 要 |
| `/home` | — | `HomeView.vue` | ホーム（旧版） | 要 |
| `/settings` | 各種設定 | `Settings.vue` | ユーザー設定 | 要 |

### チーム管理

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/teams` | TeamList | `TeamList.vue` | チーム一覧 | 要 |
| `/teams/:teamId/members` | TeamMembers | `TeamMembers.vue` | チームメンバー登録 | 要 |
| `/teams/:teamId/roster` | — | リダイレクト → SeasonPortal `?tab=roster` | 旧ロースター画面 | — |

### シーズン管理（チーム配下）

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/teams/:teamId/season` | SeasonPortal | `SeasonPortal.vue` | シーズンポータル（カレンダー・ロースター・離脱タブ） | 要 |
| `/teams/:teamId/season/games/:scheduleId` | **GameResult** | **`GameResult.vue`** | **試合結果入力**（★シーズン管理の中核） | 要 |
| `/teams/:teamId/season/games/:scheduleId/scoresheet` | ScoreSheet | `ScoreSheet.vue` | スコアシート | 要 |
| `/teams/:teamId/season/player_absences` | — | リダイレクト → SeasonPortal `?tab=absences` | 旧離脱管理画面 | — |

### 試合記録（パーサー連携・全体閲覧用）

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/games` | 試合記録 | `GamesView.vue` | 試合一覧（パーサー取り込み後の全試合） | 要 |
| `/games/import` | ログ取り込み | `GameImportView.vue` | IRCログからの試合インポート | 要 |
| `/games/:id` | 試合詳細 | `GameDetailView.vue` | 試合詳細閲覧（打席データ表示） | 要 |
| `/games/:id/lineup` | GameLineup | `GameLineupView.vue` | オーダー確認 | 要 |

### 選手

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/players` | Players | `Players.vue` | 選手一覧 | 要 |
| `/players/:id` | PlayerDetail | `PlayerDetailView.vue` | 選手詳細 | 要 |
| `/player-cards` | PlayerCards | `PlayerCardsView.vue` | 選手カード一覧 | 要 |
| `/player-cards/:id` | PlayerCardDetail | `PlayerCardDetailView.vue` | 選手カード詳細 | 要 |

### コスト・成績

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/cost_assignment` | CostAssignment | `CostAssignment.vue` | コスト登録 | 要 |
| `/stats` | 成績集計 | `StatsView.vue` | 成績集計 | 要 |
| `/competitions/:id/roster/:teamId` | CompetitionRoster | `CompetitionRosterView.vue` | 大会ロースター | 要 |

### パーサーレビュー

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/game-records` | GameRecordList | `GameRecordListView.vue` | パーサーレビュー一覧 | 要 |
| `/game-records/:id` | GameRecordDetail | `GameRecordDetailView.vue` | パーサーレビュー詳細 | 要 |

### コミッショナー（管理者専用）

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `commissioner/dashboard` | CommissionerDashboard | `commissioner/CommissionerDashboardView.vue` | コミッショナーダッシュボード | 要+コミッショナー |
| `commissioner/competitions` | Competitions | `commissioner/CompetitionsView.vue` | 大会管理 | 要+コミッショナー |
| `commissioner/stadiums` | Stadiums | `commissioner/StadiumsView.vue` | 球場管理 | 要+コミッショナー |
| `commissioner/card_sets` | CardSets | `commissioner/CardSetsView.vue` | カードセット管理 | 要+コミッショナー |
| `commissioner/users` | Users | `commissioner/UsersView.vue` | ユーザー管理 | 要+コミッショナー |
| `commissioner/leagues` | — | リダイレクト → `/commissioner/competitions` | 旧リーグ画面 | — |
| `commissioner/players` | — | リダイレクト → `/players` | 選手管理の統合先 | — |

### 監督

| ルート | name | View | 用途 | 認証 |
|--------|------|------|------|------|
| `/managers` | 監督一覧 | `ManagerList.vue` | 監督一覧 | 要+コミッショナー |

---

## 紛らわしい画面の区別

### GameResult.vue vs GameDetailView.vue

| | GameResult.vue | GameDetailView.vue |
|---|---|---|
| **ルート** | `/teams/:teamId/season/games/:scheduleId` | `/games/:id` |
| **用途** | シーズン管理からの**試合結果入力**（編集画面） | パーサー取り込み後の**試合詳細閲覧**（読み取り専用） |
| **アクセス元** | SeasonPortal → カレンダーの試合日クリック | GamesView → 試合一覧クリック |
| **パラメータ** | teamId + scheduleId（チーム日程ベース） | id（game_idベース） |
| **データソース** | `/game/:scheduleId` API | `/games/:id` API |
| **編集機能** | あり（保存ボタン） | なし（閲覧のみ） |

### SeasonPortal.vue のタブ構成

SeasonPortal.vue はタブで複数機能を統合している:
- カレンダータブ（デフォルト）
- ロースタータブ（`?tab=roster`、旧 `ActiveRoster.vue` を統合）
- 離脱管理タブ（`?tab=absences`、旧 `PlayerAbsenceHistory.vue` を統合）

---

## レガシーView（未使用）

以下のViewファイルは存在するがルーターから直接参照されていない:

| View | 状況 |
|------|------|
| `ActiveRoster.vue` | SeasonPortalのロースタータブに統合済み。リダイレクトあり |
| `PlayerAbsenceHistory.vue` | SeasonPortalの離脱タブに統合済み。リダイレクトあり |
