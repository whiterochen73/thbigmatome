#!/bin/bash
# =============================================================================
# restore_dev.sh — pull 済み本番 dump をローカル開発 DB に投入
# =============================================================================
# 使用方法:
#   bash scripts/backup/restore_dev.sh
#   bash scripts/backup/restore_dev.sh /home/morinaga/backups/thbigmatome/daily/foo.dump
#
# 手順:
#   1. scripts/backup/pull_backup.sh で dump を取得
#   2. このスクリプトで thbigmatome_development にリストア
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_ROOT="$(cd "${APP_ROOT}/.." && pwd)"
LOCAL_BACKUP_ROOT="${HOME}/backups/thbigmatome"
DB_NAME="thbigmatome_development"
DB_USER="morinaga"
STOP_CANDIDATES=(rails frontend parser)
STOPPED_SERVICES=()
RESTORE_COMPLETED=false
FAILURE_LOGGED=false

log() {
  echo "[restore_dev] $*"
}

fail() {
  FAILURE_LOGGED=true
  echo "[restore_dev] ERROR: $*" >&2
  exit 1
}

pick_latest_dump() {
  local latest=""
  latest="$(find "${LOCAL_BACKUP_ROOT}/daily" -maxdepth 1 -type f -name '*.dump' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
  if [[ -z "${latest}" ]]; then
    latest="$(find "${LOCAL_BACKUP_ROOT}/weekly" -maxdepth 1 -type f -name '*.dump' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
  fi
  printf '%s\n' "${latest}"
}

ensure_local_docker_context() {
  local ctx
  ctx="$(docker context show 2>/dev/null || true)"
  if [[ -n "${ctx}" && "${ctx}" != "default" && "${ctx}" != "desktop-linux" ]]; then
    fail "docker context='${ctx}' です。ローカル Docker 以外での実行を避けるため中断します。"
  fi
}

ensure_db_running() {
  cd "${APP_ROOT}"
  if ! docker compose ps --status running db >/dev/null 2>&1; then
    fail "docker compose の db service が起動していません。先に 'docker compose up -d db' を実行してください。"
  fi
  if ! docker compose exec -T db pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
    fail "開発 DB (${DB_NAME}) に接続できません。db service の状態を確認してください。"
  fi
}

stop_services() {
  cd "${APP_ROOT}"
  local running
  mapfile -t running < <(docker compose ps --services --status running 2>/dev/null)
  for service in "${STOP_CANDIDATES[@]}"; do
    if printf '%s\n' "${running[@]}" | grep -qx "${service}"; then
      STOPPED_SERVICES+=("${service}")
    fi
  done

  if [[ ${#STOPPED_SERVICES[@]} -gt 0 ]]; then
    log "一時停止: ${STOPPED_SERVICES[*]}"
    docker compose stop "${STOPPED_SERVICES[@]}"
  else
    log "停止対象コンテナはありません"
  fi
}

restart_services() {
  cd "${APP_ROOT}"
  if [[ ${#STOPPED_SERVICES[@]} -gt 0 ]]; then
    log "再起動: ${STOPPED_SERVICES[*]}"
    docker compose start "${STOPPED_SERVICES[@]}"
    STOPPED_SERVICES=()
  fi
}

cleanup() {
  local exit_code=$?
  restart_services
  if [[ ${exit_code} -ne 0 && "${RESTORE_COMPLETED}" != "true" && "${FAILURE_LOGGED}" != "true" ]]; then
    echo "[restore_dev] ERROR: リストア処理は失敗しました。" >&2
  fi
  exit ${exit_code}
}

trap cleanup EXIT

DUMP_FILE="${1:-}"
if [[ -z "${DUMP_FILE}" ]]; then
  DUMP_FILE="$(pick_latest_dump)"
fi

if [[ -z "${DUMP_FILE}" ]]; then
  fail "dump ファイルが見つかりません。先に 'bash scripts/backup/pull_backup.sh' を実行してください。"
fi

if [[ ! -f "${DUMP_FILE}" ]]; then
  fail "dump ファイルが存在しません: ${DUMP_FILE}"
fi

ensure_local_docker_context
ensure_db_running

if [[ "${DUMP_FILE}" != "${LOCAL_BACKUP_ROOT}/"* ]]; then
  fail "想定外の dump パスです: ${DUMP_FILE}"
fi

mkdir -p "${LOCAL_BACKUP_ROOT}"
SAFETY_BACKUP="${LOCAL_BACKUP_ROOT}/dev_pre_restore_$(date '+%Y%m%d_%H%M%S').dump"

log "=== 開発 DB リストア ==="
log "dump: ${DUMP_FILE}"
log "target DB: ${DB_NAME}"
echo "開発 DB を上書きします。yes/no"
if ! IFS= read -r CONFIRM; then
  fail "確認入力を受け取れませんでした。対話モードで再実行してください。"
fi
if [[ "${CONFIRM}" != "yes" ]]; then
  log "キャンセルしました"
  exit 0
fi

cd "${APP_ROOT}"

log "事前バックアップ取得: ${SAFETY_BACKUP}"
docker compose exec -T db pg_dump -U "${DB_USER}" -Fc "${DB_NAME}" > "${SAFETY_BACKUP}"

stop_services

log "既存接続を切断中..."
docker compose exec -T db psql -U "${DB_USER}" -d postgres -v ON_ERROR_STOP=1 -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" >/dev/null

log "pg_restore 実行中..."
if ! docker compose exec -T db pg_restore \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  --no-owner \
  --role="${DB_USER}" \
  --clean \
  --if-exists \
  --no-privileges \
  < "${DUMP_FILE}"; then
  fail "pg_restore に失敗しました"
fi

PLAYERS_COUNT="$(docker compose exec -T db psql -U "${DB_USER}" -d "${DB_NAME}" -At -c "SELECT COUNT(*) FROM players;")"
YUYUKO_MATCHES="$(docker compose exec -T db psql -U "${DB_USER}" -d "${DB_NAME}" -At -F '|' -c "SELECT pc.id, p.id, p.name, COALESCE(pc.variant, ''), cs.name FROM player_cards pc JOIN players p ON p.id = pc.player_id LEFT JOIN card_sets cs ON cs.id = pc.card_set_id WHERE p.name LIKE '%幽々子%' OR COALESCE(pc.variant, '') = '楼閣' ORDER BY pc.id LIMIT 5;")"

RESTORE_COMPLETED=true
log "=== リストア完了 ==="
log "事前バックアップ: ${SAFETY_BACKUP}"
log "投入 dump: ${DUMP_FILE}"
log "sanity: players.count=${PLAYERS_COUNT}"
if [[ -n "${YUYUKO_MATCHES}" ]]; then
  log "bonus: 楼閣/幽々子候補"
  printf '%s\n' "${YUYUKO_MATCHES}"
else
  log "bonus: 楼閣/幽々子候補は見つかりませんでした"
fi
