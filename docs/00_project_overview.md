# プロジェクト概要

## 1. プロジェクトの目的

本プロジェクトは、野球ボードゲーム「東方BIG野球」のリーグ戦・チーム運営を管理するためのWebアプリケーションである。
監督、チーム、選手、試合結果、ロースター、コストなどを管理し、コミッショナーによるリーグ運営も支援する。

## 2. 技術スタック

### バックエンド（thbigmatome）

| 項目 | 技術 | バージョン |
|------|------|-----------|
| フレームワーク | Ruby on Rails | ~> 8.0.2 |
| データベース | PostgreSQL | - |
| Webサーバー | Puma | >= 5.0 |
| JSONシリアライズ | Active Model Serializers | - |
| 認証 | bcrypt（has_secure_password） | - |
| CORS | rack-cors | - |
| デプロイ | Kamal + Docker | - |

### フロントエンド（thbigmatome-front）

| 項目 | 技術 | バージョン |
|------|------|-----------|
| フレームワーク | Vue.js 3（Composition API） | ^3.5.17 |
| 言語 | TypeScript | ~5.8.0 |
| ビルドツール | Vite | ^7.0.0 |
| UIライブラリ | Vuetify 3 | ^3.9.0 |
| ルーティング | Vue Router | ^4.5.1 |
| HTTPクライアント | Axios | ^1.10.0 |
| 国際化 | vue-i18n | ^11.1.11 |
| アイコン | Material Design Icons（@mdi/font） | ^7.4.47 |

## 3. アーキテクチャ

```
┌──────────────────┐     HTTP/JSON      ┌──────────────────┐
│  thbigmatome-front │ ◄──────────────► │   thbigmatome     │
│  (Vue.js 3 SPA)    │   /api/v1/*      │  (Rails API)      │
│  Port: 5173(dev)   │                  │  Port: 3000       │
└──────────────────┘                    └──────┬───────────┘
                                               │
                                        ┌──────▼───────────┐
                                        │   PostgreSQL      │
                                        └──────────────────┘
```

- **認証方式**: Railsセッションベース認証（Cookie + X-CSRF-Token）
- **API名前空間**: `/api/v1/`（一般）、`/api/v1/commissioner/`（コミッショナー専用）
- **ユーザーロール**: `general`（一般）、`commissioner`（コミッショナー）

## 4. データベーステーブル一覧

### コアテーブル

| テーブル名 | 用途 |
|-----------|------|
| `users` | アプリケーションユーザー（認証・ロール管理） |
| `managers` | 監督マスタ |
| `teams` | チーム |
| `players` | 選手マスタ（40+カラムの詳細データ） |
| `team_memberships` | チームと選手の所属関係（一軍/二軍、コストタイプ） |
| `team_managers` | チームと監督の関係（監督/コーチ） |

### シーズン・試合テーブル

| テーブル名 | 用途 |
|-----------|------|
| `seasons` | チームのシーズン（現在日付、キープレイヤー） |
| `season_schedules` | シーズン日程（試合結果・スコアボード・スタメン含む） |
| `season_rosters` | シーズン中のロースター変更履歴 |
| `player_absences` | 選手の離脱情報（怪我/出場停止/調整） |

### リーグテーブル（コミッショナー管理）

| テーブル名 | 用途 |
|-----------|------|
| `leagues` | リーグ |
| `league_seasons` | リーグシーズン（ステータス管理） |
| `league_games` | リーグの対戦カード |
| `league_memberships` | リーグへのチーム参加 |
| `league_pool_players` | リーグの選手プール（助っ人候補） |

### マスタデータテーブル

| テーブル名 | 用途 |
|-----------|------|
| `batting_styles` | 打撃スタイル |
| `batting_skills` | 打撃スキル（positive/negative/neutral） |
| `pitching_styles` | 投球スタイル |
| `pitching_skills` | 投球スキル（positive/negative/neutral） |
| `player_types` | 選手タイプ |
| `biorhythms` | バイオリズム（期間付き） |
| `costs` | コスト表（期間付き） |
| `cost_players` | 選手別コスト（5種類のコストタイプ） |
| `schedules` | 日程マスタ |
| `schedule_details` | 日程詳細（日付ごとの日程タイプ） |

### 中間テーブル

| テーブル名 | 用途 |
|-----------|------|
| `player_batting_skills` | 選手 ↔ 打撃スキル |
| `player_pitching_skills` | 選手 ↔ 投球スキル |
| `player_player_types` | 選手 ↔ 選手タイプ |
| `player_biorhythms` | 選手 ↔ バイオリズム |
| `catchers_players` | 選手（投手） ↔ 選手（捕手）の相性 |

## 5. APIエンドポイント一覧

### 認証

| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/v1/auth/login` | ログイン |
| POST | `/api/v1/auth/logout` | ログアウト |
| GET | `/api/v1/auth/current_user` | 現在のユーザー情報取得 |
| POST | `/api/v1/users` | ユーザー登録 |

### 監督

| メソッド | パス | 説明 |
|---------|------|------|
| GET/POST | `/api/v1/managers` | 一覧取得（ページネーション対応） / 作成 |
| GET/PATCH/DELETE | `/api/v1/managers/:id` | 詳細 / 更新 / 削除 |

### チーム

| メソッド | パス | 説明 |
|---------|------|------|
| GET/POST | `/api/v1/teams` | 一覧取得 / 作成 |
| GET/PATCH/DELETE | `/api/v1/teams/:id` | 詳細 / 更新 / 削除 |
| GET/POST | `/api/v1/teams/:team_id/team_players` | チーム選手一覧 / 登録 |
| GET | `/api/v1/teams/:team_id/team_memberships` | チームメンバーシップ一覧 |

### シーズン・試合

| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/v1/seasons` | シーズン作成 |
| GET/PATCH | `/api/v1/teams/:team_id/season` | シーズン詳細 / 現在日付更新 |
| PATCH | `/api/v1/teams/:team_id/season/season_schedules/:id` | シーズン日程更新 |
| GET/POST | `/api/v1/teams/:team_id/roster` | ロースター取得 / 更新 |
| POST | `/api/v1/teams/:team_id/key_player` | キープレイヤー設定 |
| GET/PATCH | `/api/v1/game/:id` | 試合詳細 / 結果更新 |

### 選手

| メソッド | パス | 説明 |
|---------|------|------|
| GET/POST | `/api/v1/players` | 一覧取得 / 作成 |
| GET/PATCH/DELETE | `/api/v1/players/:id` | 詳細 / 更新 / 削除 |
| GET | `/api/v1/team_registration_players` | チーム登録用選手一覧 |

### マスタデータ

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/v1/player-types` | 選手タイプ（読み取り専用※） |
| GET | `/api/v1/pitching-styles` | 投球スタイル（読み取り専用※） |
| GET | `/api/v1/pitching-skills` | 投球スキル（読み取り専用※） |
| GET | `/api/v1/batting-styles` | 打撃スタイル（読み取り専用※） |
| GET | `/api/v1/batting-skills` | 打撃スキル（読み取り専用※） |
| GET/POST/PATCH/DELETE | `/api/v1/biorhythms` | バイオリズム（CRUD可能） |

※ 5種類のマスタデータは YAML → DB 同期（`rake master_data:sync`）で管理。API経由の作成・更新・削除は 403 Forbidden を返す。

### コスト

| メソッド | パス | 説明 |
|---------|------|------|
| GET/POST | `/api/v1/costs` | コスト表一覧 / 作成 |
| GET/PATCH/DELETE | `/api/v1/costs/:id` | 詳細 / 更新 / 削除 |
| POST | `/api/v1/costs/:id/duplicate` | コスト表複製 |
| GET/POST | `/api/v1/cost_assignments` | コスト割当一覧 / 登録 |

### 日程・離脱

| メソッド | パス | 説明 |
|---------|------|------|
| GET/POST/PATCH/DELETE | `/api/v1/schedules` | 日程マスタ |
| GET | `/api/v1/schedules/:schedule_id/schedule_details` | 日程詳細一覧 |
| POST | `/api/v1/schedules/:schedule_id/schedule_details/upsert_all` | 日程詳細一括更新 |
| GET/POST/PATCH/DELETE | `/api/v1/player_absences` | 選手離脱 |

### コミッショナー（`/api/v1/commissioner/`）

| メソッド | パス | 説明 |
|---------|------|------|
| CRUD | `/commissioner/leagues` | リーグ管理 |
| GET/POST/DELETE | `/commissioner/leagues/:id/league_memberships` | リーグ参加チーム |
| CRUD | `/commissioner/leagues/:id/league_seasons` | リーグシーズン |
| POST | `/commissioner/leagues/:id/league_seasons/:id/generate_schedule` | 対戦表自動生成 |
| GET | `/commissioner/leagues/:id/league_seasons/:id/league_games` | リーグ試合一覧 / 詳細 |
| GET/POST/DELETE | `/commissioner/leagues/:id/league_seasons/:id/league_pool_players` | プール選手 |
| GET | `/commissioner/leagues/:id/teams` | リーグ内チーム |
| GET/PATCH/DELETE | `/commissioner/leagues/:id/teams/:id/team_memberships` | チームメンバー管理 |
| CRUD | `/commissioner/leagues/:id/teams/:id/team_memberships/:id/player_absences` | 離脱管理 |
| CRUD | `/commissioner/leagues/:id/teams/:id/team_managers` | チーム監督・コーチ管理 |

## 6. フロントエンド画面一覧

| パス | コンポーネント | 説明 | 認証 |
|------|--------------|------|------|
| `/login` | LoginForm | ログイン | 不要 |
| `/menu` | TopMenu | ダッシュボード（チーム選択・操作起点） | 要 |
| `/managers` | ManagerList | 監督一覧・CRUD | 要 |
| `/teams` | TeamList | チーム一覧・CRUD | 要 |
| `/teams/:teamId/members` | TeamMembers | チームメンバー登録 | 要 |
| `/players` | Players | 選手一覧・CRUD | 要 |
| `/cost_assignment` | CostAssignment | コスト割当 | 要 |
| `/settings` | Settings | 各種マスタデータ設定 | 要 |
| `/commissioner/leagues` | LeaguesView | リーグ管理 | 要（コミッショナー） |
| `/teams/:teamId/season` | SeasonPortal | シーズンポータル（カレンダー） | 要 |
| `/teams/:teamId/roster` | ActiveRoster | 出場選手登録（一軍/二軍） | 要 |
| `/teams/:teamId/season/games/:scheduleId` | GameResult | 試合結果入力 | 要 |
| `/teams/:teamId/season/games/:scheduleId/scoresheet` | ScoreSheet | スコアシート | 要 |
| `/teams/:teamId/season/player_absences` | PlayerAbsenceHistory | 離脱者履歴 | 要 |

## 7. ディレクトリ構成

### バックエンド（thbigmatome）

```
thbigmatome/
├── app/
│   ├── controllers/api/v1/     # APIコントローラー
│   │   ├── commissioner/       # コミッショナー専用コントローラー
│   │   └── ...
│   ├── models/                 # ActiveRecordモデル
│   └── serializers/            # JSONレスポンス定義
├── config/
│   └── routes.rb               # APIルーティング定義
├── db/
│   ├── schema.rb               # DBスキーマ（正本）
│   └── migrate/                # マイグレーション
└── test/                       # テスト
```

### フロントエンド（thbigmatome-front）

```
thbigmatome-front/
└── src/
    ├── views/                  # ページコンポーネント（13画面）
    │   └── commissioner/       # コミッショナー専用画面
    ├── components/             # 再利用コンポーネント
    │   ├── shared/             # 汎用コンポーネント（Select系）
    │   ├── settings/           # 設定画面用コンポーネント
    │   └── players/            # 選手編集用フォーム
    ├── layouts/                # レイアウト（DefaultLayout）
    ├── composables/            # 共有ロジック（useAuth, useSnackbar）
    ├── plugins/                # Vuetify, Axios, i18n設定
    ├── types/                  # TypeScript型定義（26ファイル）
    ├── locales/                # 翻訳ファイル（ja.json）
    └── router/                 # ルーティング・認証ガード
```

## 8. 仕様書の構成

各機能の詳細仕様は以下のドキュメントを参照。

| ファイル | 内容 |
|---------|------|
| [01_authentication.md](01_authentication.md) | 認証 |
| [02_manager_management.md](02_manager_management.md) | 監督管理 |
| [03_team_management.md](03_team_management.md) | チーム管理・メンバー登録 |
| [04_player_management.md](04_player_management.md) | 選手管理 |
| [05_master_data.md](05_master_data.md) | マスタデータ管理 |
| [06_cost_management.md](06_cost_management.md) | コスト管理・コスト割当 |
| [07_schedule_management.md](07_schedule_management.md) | 日程管理 |
| [08_season_management.md](08_season_management.md) | シーズン管理 |
| [09_roster_management.md](09_roster_management.md) | ロースター管理 |
| [10_game_management.md](10_game_management.md) | 試合結果・スコアシート |
| [11_player_absence.md](11_player_absence.md) | 選手離脱管理 |
| [12_commissioner.md](12_commissioner.md) | コミッショナー機能 |
| [13_frontend_architecture.md](13_frontend_architecture.md) | フロントエンドアーキテクチャ |
| [14_test_strategy.md](14_test_strategy.md) | テスト戦略 |
