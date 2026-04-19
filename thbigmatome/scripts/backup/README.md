# Backup Scripts

`pull_backup.sh` と `restore_dev.sh` で、本番 dump をローカル開発環境へ 2 ステップで反映できます。

## 前提

- WSL / ローカル Docker 上で実行すること
- `~/.ssh/config` に `dugout-vps` が設定済みであること
- `docker compose up -d db rails frontend parser` 済みであること
- 開発 DB を上書きするため、必要ならローカル変更データを別途退避しておくこと

## 手順

1. 本番 dump を取得

```bash
bash scripts/backup/pull_backup.sh
```

2. 最新 dump を開発 DB に投入

```bash
bash scripts/backup/restore_dev.sh
```

特定 dump を使う場合:

```bash
bash scripts/backup/restore_dev.sh ~/backups/thbigmatome/daily/thbigmatome_YYYYMMDD_HHMMSS.dump
```

## restore_dev.sh の動作

- `~/backups/thbigmatome/daily/` の最新 `.dump` を自動選択（無ければ `weekly/` を確認）
- 実行前に `yes/no` 確認
- 現在の `thbigmatome_development` を `~/backups/thbigmatome/dev_pre_restore_*.dump` に退避
- `rails` / `frontend` / `parser` を一時停止
- `pg_restore --no-owner --role=morinaga --clean --if-exists --no-privileges` を実行
- 完了後にコンテナ再起動、`players.count` と簡易 bonus query を表示

## 注意

- 本番用 `restore.sh` とは用途が異なります。ローカル開発環境では `restore_dev.sh` を使ってください
- dump ファイルは `~/backups/thbigmatome/` 配下にあり、リポジトリ管理対象ではありません
- schema migration は自動実行しません。必要ならリストア後に手動で以下を実行してください

```bash
bin/rails db:migrate
```
