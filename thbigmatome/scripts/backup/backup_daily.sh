#!/bin/bash
# =============================================================================
# backup_daily.sh — 本番DBバックアップスクリプト
# =============================================================================
# 実行方法: VPS上のプロジェクトルートで実行
#   /home/thbigmatome/projects/scripts/backup/backup_daily.sh
#
# スケジュール: cronにより毎日 02:00 実行（cron.d/backup 参照）
#
# バックアップ先:
#   /var/backups/thbigmatome/daily/   — 日次 (7世代)
#   /var/backups/thbigmatome/weekly/  — 週次 (4世代、日曜日のみ)
# =============================================================================

set -euo pipefail

# --- 設定 ---
BACKUP_ROOT="/var/backups/thbigmatome"
DAILY_DIR="${BACKUP_ROOT}/daily"
WEEKLY_DIR="${BACKUP_ROOT}/weekly"
LOG_FILE="${BACKUP_ROOT}/backup.log"

DAILY_KEEP=7
WEEKLY_KEEP=4

COMPOSE_FILE="/home/thbigmatome/projects/docker-compose.prod.yml"
ENV_FILE="/home/thbigmatome/projects/.env.production"
DB_CONTAINER="thbigmatome-db-1"   # docker compose ps で確認すること
DB_NAME="thbigmatome_production"
DB_USER="thbigmatome"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
WEEKDAY=$(date '+%u')   # 1=月 ... 7=日

# --- ログ関数 ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# --- ディレクトリ確保 ---
mkdir -p "${DAILY_DIR}" "${WEEKLY_DIR}"

log "=== バックアップ開始 ==="

# --- pg_dump 実行（コンテナ内で実行）---
DAILY_FILE="${DAILY_DIR}/thbigmatome_${TIMESTAMP}.dump"

log "pg_dump 開始: ${DAILY_FILE}"

docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" \
    exec -T db \
    pg_dump -U "${DB_USER}" -Fc "${DB_NAME}" \
    > "${DAILY_FILE}"

DUMP_SIZE=$(du -sh "${DAILY_FILE}" | cut -f1)
log "pg_dump 完了: ${DUMP_SIZE}"

# --- 週次バックアップ（日曜日のみコピー）---
if [ "${WEEKDAY}" = "7" ]; then
    WEEKLY_FILE="${WEEKLY_DIR}/thbigmatome_weekly_${TIMESTAMP}.dump"
    cp "${DAILY_FILE}" "${WEEKLY_FILE}"
    log "週次コピー: ${WEEKLY_FILE}"
fi

# --- 世代管理: 古いファイルを削除 ---
log "世代管理: 日次 ${DAILY_KEEP}世代, 週次 ${WEEKLY_KEEP}世代"

# 日次: 新しい順に DAILY_KEEP 件残す
ls -t "${DAILY_DIR}"/*.dump 2>/dev/null | tail -n "+$((DAILY_KEEP + 1))" | while read -r f; do
    log "削除(日次): ${f}"
    rm -f "${f}"
done

# 週次: 新しい順に WEEKLY_KEEP 件残す
ls -t "${WEEKLY_DIR}"/*.dump 2>/dev/null | tail -n "+$((WEEKLY_KEEP + 1))" | while read -r f; do
    log "削除(週次): ${f}"
    rm -f "${f}"
done

log "=== バックアップ完了 ==="

# --- 一覧表示 ---
log "--- 日次バックアップ一覧 ---"
ls -lh "${DAILY_DIR}"/*.dump 2>/dev/null | awk '{print $5, $9}' | tee -a "${LOG_FILE}" || true

log "--- 週次バックアップ一覧 ---"
ls -lh "${WEEKLY_DIR}"/*.dump 2>/dev/null | awk '{print $5, $9}' | tee -a "${LOG_FILE}" || true
