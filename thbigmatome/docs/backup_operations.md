# 本番DB バックアップ運用設計書

> ⚠️ 本番デプロイは **P確認後に実施**すること（現在: 未デプロイ）

## 概要

| 項目 | 内容 |
|------|------|
| 対象DB | thbigmatome_production (PostgreSQL 16) |
| 実行方式 | VPS上のcronジョブ → `docker compose exec db pg_dump` |
| 実行タイミング | 毎日 02:00 (JST) |
| 世代管理 | 日次: 7世代 / 週次 (日曜): 4世代 |
| バックアップ保存先 | `~/backups/thbigmatome/` (VPS上: deployユーザーホーム) |
| ローカル取得 | rsync経由でWSLに手動pull |

## ディレクトリ構成

```
/home/deploy/backups/thbigmatome/
├── daily/
│   ├── thbigmatome_20260410_020000.dump   # 最新7件保持
│   └── ...
├── weekly/
│   ├── thbigmatome_weekly_20260406_020000.dump  # 最新4件保持
│   └── ...
├── backup.log     # 実行ログ
└── cron.log       # cron実行ログ
```

## スクリプト一覧

| スクリプト | 場所 | 用途 |
|-----------|------|------|
| `backup_daily.sh` | `scripts/backup/` | バックアップ本体（cron実行） |
| `pull_backup.sh` | `scripts/backup/` | WSLからVPSのバックアップをrsyncでpull |
| `restore.sh` | `scripts/backup/` | VPS上でのリストア実行 |
| `cron.d/backup` | `scripts/backup/cron.d/` | cronジョブ設定ファイル |

---

## デプロイ状況（2026-04-10 完了済み）

### 実施済み内容

```bash
# VPS (deploy@dugout.thbig.fun) 上で実施済み:
# ✅ バックアップディレクトリ作成
mkdir -p ~/backups/thbigmatome/daily ~/backups/thbigmatome/weekly

# ✅ スクリプト配置（rsync転送済み）
~/projects/thbigmatome/scripts/backup/backup_daily.sh
~/projects/thbigmatome/scripts/backup/restore.sh
~/projects/thbigmatome/scripts/backup/pull_backup.sh

# ✅ cronインストール（deploy ユーザー crontab）
crontab ~/projects/thbigmatome/scripts/backup/cron.d/backup

# ✅ 手動実行確認: 428K のダンプ生成確認
# ✅ WSL pull確認: rsync で 428K 取得成功
```

### 環境固有パラメータ（確認済み）

| パラメータ | 値 |
|-----------|-----|
| DBコンテナ名 | `projects-db-1` |
| VPSタイムゾーン | JST (Asia/Tokyo) |
| デプロイユーザー | `deploy` |
| バックアップ先 | `/home/deploy/backups/thbigmatome/` |
| cronスケジュール | 毎日 02:00 JST |

### WSLからのpull設定（設定済み）

`~/.ssh/config` 追記済み:

```
Host dugout-vps
  HostName dugout.thbig.fun
  User deploy
  IdentityFile ~/.ssh/id_ed25519_thbig
  StrictHostKeyChecking accept-new
```

実行:
```bash
bash scripts/backup/pull_backup.sh          # 実際に取得
bash scripts/backup/pull_backup.sh --dry-run # 確認のみ
```

---

## バックアップ確認方法

### VPS上で確認

```bash
# バックアップ一覧
ls -lh /var/backups/thbigmatome/daily/
ls -lh /var/backups/thbigmatome/weekly/

# ログ確認
tail -50 /var/backups/thbigmatome/backup.log

# ファイルの整合性確認（pg_restore --list）
docker compose -f ~/projects/docker-compose.prod.yml \
  exec db pg_restore --list /tmp/check.dump 2>&1 | head -20
# ※ ファイルをコンテナ内に一時コピーしてから実行
```

### WSLからpull後の確認

```bash
bash scripts/backup/pull_backup.sh
ls -lh ~/backups/thbigmatome/daily/
```

---

## リストア手順

> ⚠️ 実行前に必ずPに確認を取り、メンテナンス告知を行うこと

### 前提条件チェック

- [ ] バックアップファイルが正常に存在する
- [ ] Pへの確認が取れている
- [ ] ユーザー向けメンテナンス告知済み

### リストア実行

```bash
# VPS上で実行
# 利用可能なバックアップを確認
ls -lht /var/backups/thbigmatome/daily/

# リストアスクリプト実行（対話式）
bash /home/thbigmatome/projects/thbigmatome/scripts/backup/restore.sh \
     /var/backups/thbigmatome/daily/thbigmatome_YYYYMMDD_HHMMSS.dump
```

スクリプトが自動的に以下を行う:
1. リストア前の事前バックアップを取得
2. rails/parserコンテナを停止
3. `pg_restore --clean --if-exists` でリストア
4. rails/parserコンテナを再起動

### リストア後の確認

```bash
# Railsコンテナが起動しているか確認
docker compose -f ~/projects/docker-compose.prod.yml ps

# ヘルスチェック
curl -s https://dugout.thbig.fun/api/v1/health || echo "要確認"
```

---

## 障害対応

| 症状 | 原因 | 対処 |
|------|------|------|
| backup.logにエラー | コンテナ名不一致 | `docker compose ps` でコンテナ名確認→スクリプト修正 |
| cronが動かない | cronサービス停止 | `sudo systemctl status cron` 確認 |
| ディスク不足 | バックアップ蓄積 | 世代数を減らすか手動削除 |
| rsync失敗 | SSH鍵未設定 | `~/.ssh/config` とSSH鍵を確認 |

---

*作成: 2026-04-10 / subtask_980a (cmd_980)*
