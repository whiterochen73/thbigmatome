# THBIG Dugout 本番デプロイガイド（ConoHa VPS 2GB）

本書は THBIG Dugout v0.1.0 を ConoHa VPS にデプロイする手順をまとめたものです。

**構成サマリ:**
- OS: Ubuntu 24.04 LTS
- 技術スタック: Docker Compose（db/rails/frontend/parser）
- 外部公開: ポート 80（HTTP）、Nginx 経由
- SSL: v0.1.0 では非対応（IP直アクセス）

---

## 目次

1. [VPS 初期設定](#1-vps-初期設定)
2. [Docker インストール](#2-docker-インストール)
3. [アプリデプロイ](#3-アプリデプロイ)
4. [運用設定](#4-運用設定)
5. [動作確認](#5-動作確認)
6. [トラブルシューティング](#6-トラブルシューティング)

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
sudo ufw enable
sudo ufw status
```

必要に応じて HTTPS（443）も開放しておきます（SSL 導入時に使用）。

```bash
sudo ufw allow 443/tcp
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

## 3. アプリデプロイ

### 3-1. リポジトリのクローン

```bash
cd ~
git clone https://github.com/whiterochen73/multi-agent-shogun-production.git
# ※ thbigmatome・thbigmatome-front は実際のリポジトリ URL に読み替えること
git clone <thbigmatome リポジトリ URL> ~/projects/thbigmatome
git clone <thbigmatome-front リポジトリ URL> ~/projects/thbigmatome-front
git clone <thbig-irc-parser リポジトリ URL> ~/projects/thbig-irc-parser
```

あるいは既存のプロジェクトディレクトリ構成に合わせて:

```
~/projects/
├── thbigmatome/
├── thbigmatome-front/
├── thbig-irc-parser/
└── docker-compose.prod.yml   ← リポジトリルートに含まれる
```

### 3-2. 環境変数ファイルの作成

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
| `APP_HOST` | VPS の IP アドレス |
| `CORS_ALLOWED_ORIGIN` | `http://<VPS_IP>` |
| `VITE_API_BASE_URL` | `http://<VPS_IP>/api/v1` |

**注意**: `.env.production` は git にコミットしないこと。

### 3-3. Rails credentials の確認

`config/master.key` が存在し、`config/credentials.yml.enc` と対応していることを確認します。

```bash
cd ~/projects/thbigmatome
cat config/master.key  # 内容を .env.production の RAILS_MASTER_KEY に設定済みか確認
```

### 3-4. コンテナビルド・起動

```bash
cd ~/projects
docker compose -f docker-compose.prod.yml --env-file .env.production build
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

### 3-5. DB 作成・マイグレーション・seed

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

## 4. 運用設定

### 4-1. Docker の自動起動

Docker サービス自体の自動起動を確認します。

```bash
sudo systemctl enable docker
sudo systemctl status docker
```

`docker-compose.prod.yml` の各サービスに `restart: unless-stopped` が設定されているため、Docker が起動すればコンテナも自動的に再起動します。

### 4-2. 定期再起動（OOM 対策）

Rails(Puma) のメモリリーク対策として、週1回の定期再起動を設定します。

```bash
crontab -e
```

以下を追加します:

```cron
# 毎週日曜 4:00 に Rails コンテナを再起動（OOM 対策）
0 4 * * 0 cd /home/deploy/projects && docker compose -f docker-compose.prod.yml --env-file .env.production restart rails >> /var/log/rails-restart.log 2>&1
```

### 4-3. ログ管理

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

## 5. 動作確認

### 5-1. コンテナ状態確認

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production ps
```

全コンテナが `Up` 状態であることを確認します。

### 5-2. ヘルスチェック

```bash
curl http://localhost/up
# => 200 OK が返れば Rails は正常起動
```

### 5-3. ブラウザ確認

ブラウザで `http://<VPS_IP>` にアクセスし、ログイン画面が表示されることを確認します。

`.env.production` の `INITIAL_PASSWORD` で設定した初期パスワードでログインできることを確認します。

### 5-4. カード画像確認

画像が表示されない場合は ActiveStorage の状態を確認します。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production \
  exec rails bundle exec rails runner "puts ActiveStorage::Attachment.count"
```

初回デプロイ時はカードデータのインポートが必要です（別途 `import_card_data` タスクを参照）。

---

## 6. トラブルシューティング

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

2GB プランでは定期再起動の設定（4-2 参照）を必ず行うこと。

---

## 付録: 今後の改善候補

| 項目 | 優先度 | 説明 |
|------|--------|------|
| SSL/HTTPS 対応 | 中 | ドメイン取得後に Let's Encrypt + certbot で対応 |
| ドメイン設定 | 低 | `config.hosts` の有効化（production.rb の TODO コメント参照） |
| バックアップ | 中 | PostgreSQL の定期 `pg_dump` + 外部ストレージ保存 |
| カード画像 S3 移行 | 低 | ActiveStorage を S3 に移行してディスク依存を排除 |
