# THBIG Dugout デプロイ手順書

本書は THBIG Dugout を本番環境にデプロイする手順をまとめたものです。

**推奨構成:**
- OS: Ubuntu 24.04 LTS
- インフラ: Docker Compose（db / rails / frontend / parser）
- SSL: Let's Encrypt + certbot
- ドメイン: dugout.thbig.fun

詳細なVPS初期設定手順は `docs/deploy-guide.md` を参照してください。

---

## 前提条件

- Docker / Docker Compose がインストール済み
- SSL証明書が取得済み（`/etc/letsencrypt/live/dugout.thbig.fun/`）
- リポジトリがクローン済み

```
~/projects/
├── thbigmatome/           # Rails API
├── thbigmatome-front/     # Vue 3 フロントエンド
├── thbig-irc-parser/      # 打席ログパーサー（Flask）
└── docker-compose.prod.yml
```

---

## 1. 環境変数の設定

```bash
cp thbigmatome/.env.production.example .env.production
nano .env.production
```

| 変数名 | 説明 |
|--------|------|
| `DB_PASSWORD` | PostgreSQL パスワード（`openssl rand -hex 32` で生成） |
| `RAILS_MASTER_KEY` | `thbigmatome/config/master.key` の内容 |
| `INITIAL_PASSWORD` | 初回ログインパスワード |
| `INTERNAL_API_KEY` | Clubhouse等の内部同期APIキー（`openssl rand -hex 32` などで生成、開発用デフォルト値は禁止） |
| `APP_HOST` | `dugout.thbig.fun` |
| `CORS_ALLOWED_ORIGIN` | `https://dugout.thbig.fun` |
| `VITE_API_BASE_URL` | `https://dugout.thbig.fun/api/v1` |

**注意**: `.env.production` は絶対に git にコミットしないこと。

内部APIキー交換手順:

1. `openssl rand -hex 32` で新しい `INTERNAL_API_KEY` を生成する。
2. Dugout本番の `.env.production` に同じ値を設定する。
3. Clubhouse等の同期元サービスにも同じ値を設定する。
4. `docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build rails` でRailsを再作成する。
5. 同期元から `/api/v1/internal/players?page=1&per_page=1` を呼び、200応答と `meta.total_count` を確認する。

---

## 2. 初回セットアップ

### 2-1. ビルド・起動

```bash
cd ~/projects
docker compose -f docker-compose.prod.yml --env-file .env.production build
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

### 2-2. DB作成・マイグレーション・seed

```bash
# DB作成
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:create RAILS_ENV=production

# マイグレーション
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:migrate RAILS_ENV=production

# 初期データ投入
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:seed RAILS_ENV=production
```

### 2-3. カード画像インポート

選手カード画像をActive Storageにインポートします。

```bash
# 画像とCSVをVPSに転送（ローカルから実行）
scp -r /path/to/card_images/ deploy@<VPS_IP>:/home/deploy/card_images/

# インポート実行（VPSで実行）
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -e CARD_IMAGE_DIR=/home/deploy/card_images \
       -e CARD_CSV_PATH=/home/deploy/card_images/player_cards.csv \
  rails bundle exec rake import:card_images
```

rakeタスクはべき等です。再実行しても既存画像はスキップされます。

VPS上の画像配置:
```
/home/deploy/card_images/
├── player_cards.csv
├── 2025THBIG/trimmed/*.png
├── hachinai6.1/trimmed/*.png
├── PM2026/trimmed/*.png
└── tamayomi2/trimmed/*.png
```

---

## 3. アップデート手順

既にデプロイ済みの環境を更新する場合:

```bash
cd ~/projects

# コード取得
git -C thbigmatome pull origin main
git -C thbigmatome-front pull origin main
git -C thbig-irc-parser pull origin develop

# リビルド・再起動
docker compose -f docker-compose.prod.yml --env-file .env.production build
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# マイグレーション（必要な場合）
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:migrate RAILS_ENV=production
```

---

## 4. Active Storage ボリューム

Active Storageのファイルは `rails_storage` ボリュームに永続化されます。
**コンテナ再ビルド時もデータは保持されます。**

ボリュームの確認:
```bash
docker volume ls | grep rails_storage
```

---

## 5. Nginx SSL設定

フロントエンドコンテナ内のNginxがSSL終端を行います。

- 証明書パス: `/etc/letsencrypt/live/dugout.thbig.fun/`
- docker-compose.prod.ymlで `/etc/letsencrypt` を読み取り専用マウント
- 証明書自動更新: certbot cron（`docs/deploy-guide.md` セクション3-3参照）

---

## 6. 動作確認

```bash
# コンテナ状態確認
docker compose -f docker-compose.prod.yml --env-file .env.production ps

# ヘルスチェック
curl http://localhost/up

# カード画像確認
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails runner \
  "puts \"Attachments: #{ActiveStorage::Attachment.count}\""
```

ブラウザで `https://dugout.thbig.fun` にアクセスし、ログイン画面が表示されることを確認。

---

## 7. 運用

### 定期再起動（OOM対策）

```cron
# 毎週日曜 4:00 に Rails コンテナを再起動
0 4 * * 0 cd /home/deploy/projects && docker compose -f docker-compose.prod.yml --env-file .env.production restart rails
```

### ログ確認

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production logs -f rails
```

### トラブルシューティング

詳細は `docs/deploy-guide.md` セクション7を参照。
