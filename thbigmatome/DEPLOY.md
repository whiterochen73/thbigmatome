# THBIG Dugout デプロイ手順書

本書は THBIG Dugout を本番環境にデプロイする手順をまとめたものです。

**推奨構成:**
- OS: Ubuntu 24.04 LTS
- インフラ: Docker Compose（db / rails / frontend）
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
# 画像をVPSに転送（ローカルから実行）。CSV は転送しない（既定の db/import/player_cards.csv＝取り込みと同じ CSV を rails の image から読む）
scp -r /path/to/card_images/ deploy@<VPS_IP>:/home/deploy/card_images/

# まず当て先の点検（画像ファイルは使わない。全行がカードに当たるか・取り違えの疑いを数える）
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -T rails bundle exec rake import:card_image_targets < /dev/null

# インポート実行（VPSで実行）
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -e CARD_IMAGE_DIR=/home/deploy/card_images \
  rails bundle exec rake import:card_images
```

`CARD_CSV_PATH` の既定は `db/import/player_cards.csv`（`import:card_data`・`db/seeds/import_cards.rb` と同じ CSV）。別の CSV を使う時だけ `-e CARD_CSV_PATH=...` を付ける。
画像ファイルは card_source ごとに card_seq が連番である前提で CSV の card_seq と結ぶので、CSV は取り込みに使ったものと同じ版にする。
カードへの当て方は取り込みと同じ（添え字つきの名前の行は、カードが付いた基の Player に variant で当てる）。取り込みが作らなかったカードの行（card_seq 405 など）は SKIP と数えるだけで、別のカードには付けない。

rakeタスクはべき等です。再実行しても既存画像はスキップされます。

VPS上の画像配置:
```
/home/deploy/card_images/
├── 2025THBIG/trimmed/*.png
├── hachinai6.1/trimmed/*.png
├── PM2026/trimmed/*.png
├── PM2027/trimmed/*.png
└── tamayomi2/trimmed/*.png
```

### 2-4. PM の在籍カードの付け替え（PM2026 → PM2027）

在籍中の所属のカードを、現行外の PM2026 から PM2027 の同じ Player・同じ種別・同じ variant のカードへ替える。カード・コスト seed の取り込みの後に流す。

```bash
# dry-run（既定。DB は変わらない）。OUT に明細 CSV
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -T -e OUT=/tmp/swap_plan.csv rails bundle exec rake cards:swap_to_current < /dev/null

# 実行（戻し用 CSV が必須）。絞る時は TEAM_IDS=1,2 / MEMBERSHIP_IDS=10,11
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -T -e APPLY=1 -e OUT=/tmp/swap_plan.csv -e REVERT_OUT=/tmp/swap_revert.csv rails bundle exec rake cards:swap_to_current < /dev/null

# 戻す（dry-run が既定、APPLY=1 で実行）
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -T -e REVERT_CSV=/tmp/swap_revert.csv -e APPLY=1 rails bundle exec rake cards:revert_card_swap < /dev/null
```

付け替えは画面の保存と同じ経路（TeamMembershipWriter）で、各チームのシーズンの現在日に contract の変更記録を足す。検査で止まった所属は理由つきで一覧に出して飛ばす。`/tmp/swap_*.csv` はコンテナの中なので、実行後に `docker compose cp` で取り出す。

---

## 3. アップデート手順

既にデプロイ済みの環境を更新する場合:

```bash
cd ~/projects

# コード取得
git -C thbigmatome pull origin main
git -C thbigmatome-front pull origin main

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
