# THBIG Dugout — バックエンド API サーバー

東方BIG野球のチーム・選手・試合を管理するファンタジー野球管理アプリ「THBIG Dugout」のRails APIバックエンドです。

## アーキテクチャ概要

```
[thbigmatome-front]  ←HTTP→  [thbigmatome (Rails API)]  ←→  [PostgreSQL]
   Vue.js 3 + Vuetify              Rails 8.1 / port 3000           port 5433 (Docker)
                                         ↓ HTTP
                               [thbig-irc-parser (Flask)]
                                  Python / port 5000
```

モノレポ構成（`/home/morinaga/projects/` 配下）:
- `thbigmatome/` — 本リポジトリ（Rails API）
- `thbigmatome-front/` — Vue 3 フロントエンド
- `thbig-irc-parser/` — 打席ログパーサー（Flask HTTP API）

## 主な技術スタック

| 項目 | バージョン / 技術 |
|------|-----------------|
| Ruby | 3.4.7 |
| Rails | 8.1.3 (API mode) |
| DB | PostgreSQL 16 |
| Web server | Puma |
| Job queue | Solid Queue |
| Cache | Solid Cache |
| Action Cable | Solid Cable |
| Deploy | Docker Compose (production) |
| Node.js | 20.x |
| Vue.js | 3.5 |
| Vuetify | 4.0 |
| Vite | 7.x |
| TypeScript | 5.8 |

## 主な機能

- **チーム・選手管理**: チーム登録、選手カード管理、ロスター編成、コスト管理
- **試合記録**: 試合ログインポート、打席記録、投手登板記録、試合スコア
- **日程管理**: シーズン日程、大会管理、スケジュール詳細
- **スタッツ集計**: 打撃・投手・チーム成績の集計API
- **コミッショナー機能**: ユーザー管理、離脱状況横断確認、コスト確認、クールダウン確認
- **投手疲労管理**: 登板状態追跡、疲労サマリー API

## 開発環境のセットアップ

### Docker を使う（推奨）

モノレポルートの `docker-compose.yml` を使用します。

```bash
cd /home/morinaga/projects
# .env に RAILS_MASTER_KEY を設定
cp thbigmatome/config/master.key.example .env  # またはキーを直接記述

docker compose up
```

サービス起動後:
- Rails API: `http://localhost:3000`
- フロントエンド: `http://localhost:5173`
- パーサーAPI: `http://localhost:5000`

### ローカル直接セットアップ

**前提条件**

- Ruby 3.4.7 (`rbenv` 等で管理)
- PostgreSQL（ローカルまたはDockerで起動）
- Bundler

**手順**

```bash
cd thbigmatome

# 依存 gem インストール
bundle install

# 環境変数設定
# config/master.key が必要（.gitignore 対象）

# DB 作成・マイグレーション
bin/rails db:create db:migrate

# 開発サーバー起動（port 3000）
bin/rails server
```

## テスト

### バックエンド（RSpec）

```bash
bundle exec rspec

# 特定ファイル
bundle exec rspec spec/controllers/api/v1/teams_controller_spec.rb
```

### フロントエンド（Vitest）

```bash
cd ../thbigmatome-front
yarn test
```

## API ドキュメント

→ [`docs/api-endpoints.md`](docs/api-endpoints.md)

全エンドポイントは `/api/v1/` プレフィックス付き。認証は Cookie セッション方式（`before_action :authenticate_user!`）。

## デプロイ

Docker Compose を使用して本番環境にデプロイします。

```bash
cd ~/projects
docker compose -f docker-compose.prod.yml --env-file .env.production build
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

詳細は [`DEPLOY.md`](DEPLOY.md) を参照してください。
VPS初期設定を含む完全な手順は [`docs/deploy-guide.md`](docs/deploy-guide.md) を参照。
