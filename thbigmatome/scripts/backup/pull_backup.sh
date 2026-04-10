#!/bin/bash
# =============================================================================
# pull_backup.sh — WSL（ローカル）からVPS上のバックアップを取得
# =============================================================================
# 実行方法: WSL上で実行
#   bash scripts/backup/pull_backup.sh
#   bash scripts/backup/pull_backup.sh --dry-run
#
# 前提: ssh_config に dugout-vps エントリを設定しておくこと
#   Host dugout-vps
#     HostName dugout.thbig.fun
#     User thbigmatome
#     IdentityFile ~/.ssh/id_ed25519_dugout
# =============================================================================

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY-RUN] 実際には転送しません"
fi

VPS_HOST="dugout-vps"
VPS_BACKUP_ROOT="/var/backups/thbigmatome"
LOCAL_BACKUP_ROOT="${HOME}/backups/thbigmatome"

mkdir -p "${LOCAL_BACKUP_ROOT}/daily" "${LOCAL_BACKUP_ROOT}/weekly"

RSYNC_OPTS="-avz --progress"
if $DRY_RUN; then
    RSYNC_OPTS="${RSYNC_OPTS} --dry-run"
fi

echo "=== VPS → ローカル バックアップ同期 ==="
echo "  VPS:   ${VPS_HOST}:${VPS_BACKUP_ROOT}/"
echo "  Local: ${LOCAL_BACKUP_ROOT}/"
echo ""

# 日次バックアップを同期
echo "--- 日次バックアップ ---"
rsync ${RSYNC_OPTS} \
    "${VPS_HOST}:${VPS_BACKUP_ROOT}/daily/" \
    "${LOCAL_BACKUP_ROOT}/daily/"

# 週次バックアップを同期
echo "--- 週次バックアップ ---"
rsync ${RSYNC_OPTS} \
    "${VPS_HOST}:${VPS_BACKUP_ROOT}/weekly/" \
    "${LOCAL_BACKUP_ROOT}/weekly/"

echo ""
echo "=== 同期完了 ==="
echo "ローカル保存先: ${LOCAL_BACKUP_ROOT}"
ls -lh "${LOCAL_BACKUP_ROOT}/daily/" 2>/dev/null || true
ls -lh "${LOCAL_BACKUP_ROOT}/weekly/" 2>/dev/null || true
