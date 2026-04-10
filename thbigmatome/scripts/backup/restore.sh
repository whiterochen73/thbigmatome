#!/bin/bash
# =============================================================================
# restore.sh — 本番DBリストアスクリプト
# =============================================================================
# 使用方法:
#   bash scripts/backup/restore.sh <バックアップファイル.dump>
#
# 例:
#   bash scripts/backup/restore.sh /var/backups/thbigmatome/daily/thbigmatome_20260410_020000.dump
#
# ⚠️ 警告: 実行前に必ず既存データをバックアップし、Pに確認を取ること
# =============================================================================

set -euo pipefail

DUMP_FILE="${1:-}"

if [[ -z "${DUMP_FILE}" ]]; then
    echo "使用方法: $0 <バックアップファイル.dump>"
    echo ""
    echo "利用可能なバックアップ:"
    ls -lht "${HOME}/backups/thbigmatome/daily/"*.dump 2>/dev/null || echo "  (なし)"
    ls -lht "${HOME}/backups/thbigmatome/weekly/"*.dump 2>/dev/null || echo "  (なし)"
    exit 1
fi

if [[ ! -f "${DUMP_FILE}" ]]; then
    echo "エラー: ファイルが見つかりません: ${DUMP_FILE}"
    exit 1
fi

COMPOSE_FILE="/home/deploy/projects/docker-compose.prod.yml"
DB_CONTAINER="projects-db-1"
DB_NAME="thbigmatome_production"
DB_USER="thbigmatome"

echo "=== DBリストア開始 ==="
echo "  ファイル: ${DUMP_FILE}"
echo "  DB: ${DB_NAME}"
echo ""
echo "⚠️  この操作は既存のデータを上書きします。続行しますか？ [yes/no]"
read -r CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
    echo "キャンセルしました"
    exit 0
fi

# 事前バックアップ
SAFETY_BACKUP="${HOME}/backups/thbigmatome/pre_restore_$(date '+%Y%m%d_%H%M%S').dump"
echo "事前バックアップ取得: ${SAFETY_BACKUP}"
docker exec "${DB_CONTAINER}" \
    pg_dump -U "${DB_USER}" -Fc "${DB_NAME}" \
    > "${SAFETY_BACKUP}"

echo "Railsコンテナ停止中..."
docker compose -f "${COMPOSE_FILE}" stop rails parser

echo "リストア実行中..."
docker exec -i "${DB_CONTAINER}" \
    pg_restore -U "${DB_USER}" -d "${DB_NAME}" --clean --if-exists \
    < "${DUMP_FILE}"

echo "Railsコンテナ起動中..."
docker compose -f "${COMPOSE_FILE}" start rails parser

echo ""
echo "=== リストア完了 ==="
echo "事前バックアップ: ${SAFETY_BACKUP}"
