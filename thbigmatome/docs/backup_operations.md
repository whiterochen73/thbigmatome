# 本番DB バックアップ運用設計書

最終更新日: 2026-05-12

> ⚠️ 本番リストアは **P確認後に実施**すること。

## 概要

| 項目 | 内容 |
|------|------|
| 対象DB | thbigmatome_production (PostgreSQL 16) |
| 実行方式 | VPS上のcronジョブ → `docker compose exec db pg_dump` |
| 実行タイミング | 毎日 02:00 (JST) |
| 世代管理 | 日次: 7世代 / 週次 (日曜): 4世代 |
| バックアップ保存先 | `/home/deploy/backups/thbigmatome/` (VPS上: deployユーザーホーム) |
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
ls -lh /home/deploy/backups/thbigmatome/daily/
ls -lh /home/deploy/backups/thbigmatome/weekly/

# ログ確認
tail -50 /home/deploy/backups/thbigmatome/backup.log

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
ls -lht /home/deploy/backups/thbigmatome/daily/

# リストアスクリプト実行（対話式）
bash /home/deploy/projects/thbigmatome/scripts/backup/restore.sh \
     /home/deploy/backups/thbigmatome/daily/thbigmatome_YYYYMMDD_HHMMSS.dump
```

スクリプトが自動的に以下を行う:
1. 戻すダンプを最後まで読めることを確認（`pg_restore -f /dev/null` で全量を読む。目録だけの `--list` では途中で切れたダンプを見逃す。読めなければ何も触らずに止まる）
2. リストア前の事前バックアップを取得（`~/backups/thbigmatome/pre_restore_*.dump`。読めることまで確認）
3. railsコンテナを停止
4. `public` スキーマを `drop schema public cascade; create schema public;` で作り直す（1 トランザクション）
5. `--clean` なしの `pg_restore --single-transaction --exit-on-error` でリストア
6. `schema_migrations` の最大 version と件数を表示
7. railsコンテナを再起動

**`pg_restore --clean` で戻さない理由**: `--clean` は表ごとに DROP を流すので、ダンプより新しい表（v1.0.0 の `team_membership_changes` など）が他の表を FK で参照していると DROP が失敗し、一部の表だけ戻って一部は新しいまま残る中途半端な状態になる（リハーサルで 25 件のエラー）。スキーマごと作り直せば、ダンプより新しい表も含めて全部消えて戻る。`public` 以外のスキーマと DB 自体は触らない。

途中で失敗するとその場で止まり、**railsコンテナは停止したまま**になる（壊れた DB につながない）。`public` を作り直した後の失敗なら DB は空か不完全なので、表示される事前バックアップを同じスクリプトで戻す。

環境変数で挙動を変えられる:

| 変数 | 意味 | 既定 |
|------|------|------|
| `COMPOSE_FILE` | 停止・起動に使う compose ファイル | `/home/deploy/projects/docker-compose.prod.yml` |
| `COMPOSE_ENV_FILE` | compose に `--env-file` で渡すファイル | なし |
| `STOP_SERVICES` | 止めるサービス（空白区切り） | `rails` |
| `DB_CONTAINER` / `DB_NAME` / `DB_USER` | DB コンテナ・DB 名・ロール | `projects-db-1` / `thbigmatome_production` / `thbigmatome` |
| `SAFETY_BACKUP_DIR` | 事前バックアップの置き場 | `~/backups/thbigmatome` |
| `NO_RESTART=1` | リストア後にサービスを起動しない | 起動する |

アプリのコードも古いバージョンへ戻す時（例: v1.0.0 から戻す）は、`NO_RESTART=1` で戻してコードを戻してから起動する。新しいコードのまま rails を起動すると、entrypoint の `db:prepare` が新しい migration を流し直す。

```bash
cd ~/projects
NO_RESTART=1 STOP_SERVICES="frontend rails" COMPOSE_ENV_FILE=.env.production \
  bash thbigmatome/scripts/backup/restore.sh ~/backups/thbigmatome/pre_v1_<TS>.dump
# コードとイメージを戻してから
docker compose -f docker-compose.prod.yml --env-file .env.production up -d rails frontend
```

`ssh dugout-vps bash -s < restore.sh` のように stdin でスクリプトを流す形では使わない（確認の入力が stdin から読まれる）。ファイルとして置いて実行する。

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
