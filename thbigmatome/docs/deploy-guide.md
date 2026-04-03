# THBIG Dugout 本番デプロイガイド（ConoHa VPS 2GB）

本書は THBIG Dugout v0.1.0 を ConoHa VPS にデプロイする手順をまとめたものです。

**構成サマリ:**
- OS: Ubuntu 24.04 LTS
- 技術スタック: Docker Compose（db/rails/frontend/parser）
- 外部公開: ポート 80（HTTPSリダイレクト）、443（HTTPS）、Nginx 経由
- SSL: Let's Encrypt + certbot（ドメイン: dugout.thbig.fun）

---

## 目次

1. [VPS 初期設定](#1-vps-初期設定)
2. [Docker インストール](#2-docker-インストール)
3. [SSL 証明書取得（Let's Encrypt）](#3-ssl-証明書取得lets-encrypt)
4. [アプリデプロイ](#4-アプリデプロイ)
5. [運用設定](#5-運用設定)
6. [動作確認](#6-動作確認)
7. [トラブルシューティング](#7-トラブルシューティング)
8. [カード画像のデプロイ](#8-カード画像のデプロイ)
9. [カード画像準備（PDF再生成）](#9-カード画像準備pdf再生成)

---

## 1. VPS 初期設定

### 1-1. SSH 接続

ConoHa コントロールパネルで確認した IP アドレスに接続します。

```bash
ssh root@<VPS_IP>
```

### 1-2. 一般ユーザー作成

root のまま運用しないよう、デプロイ用ユーザーを作成します。

```bash
adduser deploy
usermod -aG sudo deploy
```

### 1-3. SSH 鍵認証設定

ローカル PC で公開鍵を生成し（既にある場合はスキップ）、VPS に登録します。

```bash
# ローカルで実行
ssh-keygen -t ed25519 -C "deploy@thbig"

# 公開鍵を VPS にコピー
ssh-copy-id deploy@<VPS_IP>
```

VPS 側でパスワード認証を無効化します。

```bash
# VPS で実行
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload ssh
```

### 1-4. ファイアウォール設定

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

内部ポート（3000, 5000, 5432 等）は公開しません。

### 1-5. swap 設定（OOM 対策、必須）

2GB プランは余裕が少ないため、swap を設定します。

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永続化
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 2. Docker インストール

```bash
# 既存パッケージ削除（クリーンインストール）
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 依存パッケージ
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Docker 公式 GPG 鍵
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# リポジトリ追加
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker CE インストール
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# deploy ユーザーを docker グループに追加（sudo なしで docker を使えるよう）
sudo usermod -aG docker deploy

# 再ログインして反映
exit
ssh deploy@<VPS_IP>
```

インストール確認:

```bash
docker --version
docker compose version
```

---

## 3. SSL 証明書取得（Let's Encrypt）

### 3-1. certbot インストール

```bash
sudo apt-get update
sudo apt-get install -y certbot
```

### 3-2. 証明書の初回取得

Docker 起動前に certbot standalone モードで証明書を取得します。
（nginx コンテナが起動していない状態で実行すること）

```bash
sudo certbot certonly --standalone -d dugout.thbig.fun -d thbig.fun \
  --agree-tos --non-interactive --email your-email@example.com
```

`dugout.thbig.fun` と `thbig.fun` の両ドメインをカバーするSAN証明書が生成されます。
成功すると以下のパスに証明書が生成されます（プライマリドメイン `dugout.thbig.fun` 配下）:
- `/etc/letsencrypt/live/dugout.thbig.fun/fullchain.pem`
- `/etc/letsencrypt/live/dugout.thbig.fun/privkey.pem`

### 3-3. 証明書の自動更新設定

certbot の自動更新を cron に登録します。更新時は nginx コンテナを一時停止します。

```bash
crontab -e
```

以下を追加します:

```cron
# 毎日 3:00 に SSL 証明書の更新を確認（有効期限30日以内の場合のみ更新）
0 3 * * * certbot renew --pre-hook "cd /home/deploy/projects && docker compose -f docker-compose.prod.yml --env-file .env.production stop frontend" --post-hook "cd /home/deploy/projects && docker compose -f docker-compose.prod.yml --env-file .env.production start frontend" >> /var/log/certbot-renew.log 2>&1
```

手動で更新テストを行う場合:

```bash
sudo certbot renew --dry-run
```

---

## 4. アプリデプロイ

### 4-1. リポジトリのクローン

```bash
cd ~
mkdir -p projects && cd projects
git clone https://github.com/whiterochen73/thbigmatome.git
git clone https://github.com/whiterochen73/thbigmatome-front.git
git clone https://github.com/whiterochen73/thbig-irc-parser.git
```

あるいは既存のプロジェクトディレクトリ構成に合わせて:

```
~/projects/
├── thbigmatome/
├── thbigmatome-front/
├── thbig-irc-parser/
└── docker-compose.prod.yml   ← リポジトリルートに含まれる
```

### 4-2. 環境変数ファイルの作成

```bash
cp ~/projects/thbigmatome/.env.production.example ~/projects/.env.production
```

`.env.production` を編集し、全てのプレースホルダーを実際の値に置き換えます。

```bash
nano ~/projects/.env.production
```

| 変数名 | 値の取得方法 |
|--------|------------|
| `DB_PASSWORD` | 推測困難なランダム文字列（例: `openssl rand -hex 32` で生成） |
| `RAILS_MASTER_KEY` | `~/projects/thbigmatome/config/master.key` の内容 |
| `INITIAL_PASSWORD` | 初回ログインパスワード（任意） |
| `APP_HOST` | `dugout.thbig.fun` |
| `CORS_ALLOWED_ORIGIN` | `https://dugout.thbig.fun` |
| `VITE_API_BASE_URL` | `https://dugout.thbig.fun/api/v1` |

**注意**: `.env.production` は git にコミットしないこと。

### 4-3. Rails credentials の確認

`config/master.key` が存在し、`config/credentials.yml.enc` と対応していることを確認します。

```bash
cd ~/projects/thbigmatome
cat config/master.key  # 内容を .env.production の RAILS_MASTER_KEY に設定済みか確認
```

### 4-4. コンテナビルド・起動

```bash
cd ~/projects
docker compose -f docker-compose.prod.yml --env-file .env.production build
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

### 4-5. DB 作成・マイグレーション・seed

`docker-entrypoint` に `rails db:migrate` が含まれているため、初回起動時に自動実行されます。

キャッシュ・キュー・ケーブル用 DB を手動で作成します。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:create RAILS_ENV=production

docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:migrate RAILS_ENV=production
```

初期データ（管理ユーザー等）を投入します。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails db:seed RAILS_ENV=production
```

---

## 5. 運用設定

### 5-1. Docker の自動起動

Docker サービス自体の自動起動を確認します。

```bash
sudo systemctl enable docker
sudo systemctl status docker
```

`docker-compose.prod.yml` の各サービスに `restart: unless-stopped` が設定されているため、Docker が起動すればコンテナも自動的に再起動します。

### 5-2. 定期再起動（OOM 対策）

Rails(Puma) のメモリリーク対策として、週1回の定期再起動を設定します。

```bash
crontab -e
```

以下を追加します:

```cron
# 毎週日曜 4:00 に Rails コンテナを再起動（OOM 対策）
0 4 * * 0 cd /home/deploy/projects && docker compose -f docker-compose.prod.yml --env-file .env.production restart rails >> /var/log/rails-restart.log 2>&1
```

### 5-3. ログ管理

Docker のログローテーション設定を追加します。

```bash
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
sudo systemctl reload docker
```

ログの確認コマンド:

```bash
# Rails ログ
docker compose -f docker-compose.prod.yml --env-file .env.production logs -f rails

# 全コンテナ
docker compose -f docker-compose.prod.yml --env-file .env.production logs -f
```

---

## 6. 動作確認

### 6-1. コンテナ状態確認

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production ps
```

全コンテナが `Up` 状態であることを確認します。

### 6-2. ヘルスチェック

```bash
curl http://localhost/up
# => 200 OK が返れば Rails は正常起動
```

### 6-3. ブラウザ確認

ブラウザで `https://dugout.thbig.fun` にアクセスし、ログイン画面が表示されることを確認します。

`.env.production` の `INITIAL_PASSWORD` で設定した初期パスワードでログインできることを確認します。

### 6-4. カード画像確認

画像が表示されない場合は ActiveStorage の状態を確認します。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails runner "puts ActiveStorage::Attachment.count"
```

初回デプロイ時はカードデータのインポートが必要です（[セクション 8: カード画像のデプロイ](#8-カード画像のデプロイ) を参照）。

---

## 7. トラブルシューティング

### Rails が起動しない

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production logs rails
```

よくある原因:
- `RAILS_MASTER_KEY` が間違っている → `config/master.key` の内容を再確認
- DB 接続失敗 → `db` コンテナが起動しているか確認

### フロントエンドから API に繋がらない

- `VITE_API_BASE_URL` が正しいか確認（ビルド時に埋め込まれるため、変更時は再ビルドが必要）
- Nginx の `/api/` プロキシ設定を確認: `docker compose exec frontend nginx -t`

### メモリ不足（OOM Killer）

```bash
# メモリ使用状況確認
docker stats

# Rails コンテナを手動再起動
docker compose -f docker-compose.prod.yml --env-file .env.production restart rails
```

2GB プランでは定期再起動の設定（5-2 参照）を必ず行うこと。

---

## 8. カード画像のデプロイ

選手カード画像を本番環境にインポートする手順です。Active Storage でカード画像を PlayerCard に紐付けます。

### 8-1. 対象カードセット

| ディレクトリ名 | DB 上の CardSet 名 |
|---------------|-------------------|
| `2025THBIG` | 2025THBIG |
| `hachinai6.1` | ハチナイ6.1 |
| `PM2026` | PM2026 |
| `tamayomi2` | 球詠2 |

### 8-2. ローカル側準備

元画像は以下のディレクトリに格納されています:

```
/mnt/c/tools/multi-agent-shogun/projects/thbig/context/thbig-irc-cards/split/
├── 2025THBIG/trimmed/*.png
├── hachinai6.1/trimmed/*.png
├── PM2026/trimmed/*.png
└── tamayomi2/trimmed/*.png
```

ファイル命名規則: `p{page}_c{col}.png`（例: `p1_c3.png` = 1ページ目の3番目のカード）

開発環境用のコピーが `thbigmatome/tmp/card_images/` にも配置されています（432ファイル）。本番デプロイ時は上記の正本ディレクトリから転送してください。

CSV マッピングファイル（カード番号と選手名の対応）:

```
/home/morinaga/projects/thbig-irc-parser/data/import/player_cards.csv
```

### 8-3. VPS への転送

カード画像と CSV を VPS に転送します。

```bash
# 画像ディレクトリを VPS に転送
scp -r /mnt/c/tools/multi-agent-shogun/projects/thbig/context/thbig-irc-cards/split/ \
  deploy@<VPS_IP>:/home/deploy/card_images/

# CSV ファイルを転送
scp /home/morinaga/projects/thbig-irc-parser/data/import/player_cards.csv \
  deploy@<VPS_IP>:/home/deploy/card_images/player_cards.csv
```

VPS 側の配置:

```
/home/deploy/card_images/
├── player_cards.csv
├── 2025THBIG/trimmed/*.png
├── hachinai6.1/trimmed/*.png
├── PM2026/trimmed/*.png
└── tamayomi2/trimmed/*.png
```

### 8-4. インポート実行

VPS 上で rake タスクを実行します。環境変数 `CARD_IMAGE_DIR` と `CARD_CSV_PATH` で画像とCSVの場所を指定します。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec -e CARD_IMAGE_DIR=/home/deploy/card_images \
       -e CARD_CSV_PATH=/home/deploy/card_images/player_cards.csv \
  rails bundle exec rake import:card_images
```

rake タスクはべき等（idempotent）です。既に画像が添付済みのカードはスキップされるため、再実行しても問題ありません。

### 8-5. 確認方法

インポート結果を確認します。

```bash
# Active Storage のアタッチメント数を確認
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails runner \
  "puts \"Total attachments: #{ActiveStorage::Attachment.count}\"; puts \"Cards with image: #{PlayerCard.joins(:card_image_attachment).count} / #{PlayerCard.count}\""
```

ブラウザで `https://dugout.thbig.fun` にアクセスし、選手カード一覧画面でカード画像が表示されることを確認します。

画像が表示されない場合は `APP_HOST` 環境変数が正しく設定されているか確認してください（セクション 4-2 参照）。

---

## 9. カード画像準備（PDF再生成）

新しいカードセットが追加された場合や、既存のカード画像を再生成する場合の手順です。PDF からカード画像を切り出し、トリミングします。

### 9-1. 前提条件

以下のツールがインストールされている必要があります:

- `poppler-utils`（`pdftoppm` コマンド）
- `python3`
- `opencv-python-headless`（`trim_card_images.sh` が `~/.cardenv` に自動で venv を作成します）

```bash
# poppler-utils のインストール（Ubuntu/WSL）
sudo apt-get install -y poppler-utils
```

### 9-2. 元 PDF の場所

カードセットの PDF ファイルは以下に配置されています:

```
/mnt/c/Users/necro/Documents/to_team/player-cards/
├── 2025THBIG.pdf
├── hachinai6.1.pdf
├── PM2026.pdf
└── tamayomi2.pdf
```

### 9-3. 裁断ツール

裁断スクリプトは `thbig-irc-parser` リポジトリに配置されています:

| スクリプト | 機能 |
|-----------|------|
| `scripts/split_card_pdf.sh` | PDF を 1 ページあたり 9 枚に分割（pdftoppm + opencv で座標切り出し） |
| `scripts/trim_card_images.sh` | 余白をトリミングして最終画像を生成 |

### 9-4. 実行手順

全 4 カードセットを一括処理する場合:

```bash
cd /mnt/c/tools/multi-agent-shogun/projects/thbig

for set in 2025THBIG hachinai6.1 PM2026 tamayomi2; do
  # PDF → 9分割
  bash /home/morinaga/projects/thbig-irc-parser/scripts/split_card_pdf.sh \
    "/mnt/c/Users/necro/Documents/to_team/player-cards/${set}.pdf" \
    "context/thbig-irc-cards/split/${set}/"

  # 余白トリミング
  bash /home/morinaga/projects/thbig-irc-parser/scripts/trim_card_images.sh \
    "context/thbig-irc-cards/split/${set}/"
done
```

出力先:

```
context/thbig-irc-cards/split/{カードセット名}/trimmed/*.png
```

### 9-5. 再生成後の手順

画像の再生成が完了したら、[セクション 8: カード画像のデプロイ](#8-カード画像のデプロイ) の手順に従って VPS へ転送・インポートを行います。

---

## 付録: 今後の改善候補

| 項目 | 優先度 | 説明 |
|------|--------|------|
| ドメイン設定 | 低 | `config.hosts` の有効化（production.rb の TODO コメント参照） |
| バックアップ | 中 | PostgreSQL の定期 `pg_dump` + 外部ストレージ保存 |
| カード画像 S3 移行 | 低 | ActiveStorage を S3 に移行してディスク依存を排除 |
