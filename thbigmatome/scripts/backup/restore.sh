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
# 戻し方:
#   生きている DB に pg_restore --clean を当てるのではなく、public スキーマを
#   drop schema public cascade; create schema public; で作り直してから、
#   --clean なしで pg_restore する。--clean は表ごとに DROP を流すため、
#   ダンプより新しい表（例: v1.0.0 の team_membership_changes）が他の表を
#   FK で参照していると DROP が失敗し、一部だけ戻った中途半端な状態で終わる。
#   スキーマごと作り直せば、ダンプより新しい表も含めて全部消えて確実に戻る。
#   （public 以外のスキーマは触らない。DB 自体も他の DB も残る）
#
# 環境変数（省略時は本番の値。検証用にコンテナ名などを差し替えられる）:
#   COMPOSE_FILE        停止・起動に使う compose ファイル
#   COMPOSE_ENV_FILE    compose に --env-file で渡すファイル（省略可）
#   STOP_SERVICES       リストア中に止めるサービス（空白区切り。既定: rails）
#   DB_CONTAINER        DB コンテナ名
#   DB_NAME / DB_USER   DB 名・ロール
#   SAFETY_BACKUP_DIR   事前バックアップの置き場（既定: ~/backups/thbigmatome）
#   NO_RESTART=1        リストア後にサービスを起動しない（コードを戻してから
#                       起動したい時。戻し忘れると entrypoint の db:prepare が
#                       新しい migration を流し直す）
#
# 途中で失敗したら、その場で止まる（サービスは止めたまま）。失敗時に表示する
# 事前バックアップから、同じ手順で戻せる。
#
# ssh 越しに stdin でスクリプトを流す（bash -s < restore.sh）形では使わない。
# 確認の入力が stdin から読まれるため。ファイルとして置いて実行する。
#
# ⚠️ 警告: 実行前に必ず既存データをバックアップし、Pに確認を取ること
# =============================================================================

set -Eeuo pipefail

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

COMPOSE_FILE="${COMPOSE_FILE:-/home/deploy/projects/docker-compose.prod.yml}"
COMPOSE_ENV_FILE="${COMPOSE_ENV_FILE:-}"
STOP_SERVICES="${STOP_SERVICES:-rails}"
DB_CONTAINER="${DB_CONTAINER:-projects-db-1}"
DB_NAME="${DB_NAME:-thbigmatome_production}"
DB_USER="${DB_USER:-thbigmatome}"
SAFETY_BACKUP_DIR="${SAFETY_BACKUP_DIR:-${HOME}/backups/thbigmatome}"
NO_RESTART="${NO_RESTART:-0}"

COMPOSE=(docker compose -f "${COMPOSE_FILE}")
if [[ -n "${COMPOSE_ENV_FILE}" ]]; then
    COMPOSE+=(--env-file "${COMPOSE_ENV_FILE}")
fi

# 失敗時: public スキーマを作り直した後なら、DB が空・中途半端でありうることを知らせる。
# サービスは止めたままにする（壊れた DB に rails をつながない）。
SCHEMA_DROPPED=0
SAFETY_BACKUP="${SAFETY_BACKUP_DIR}/pre_restore_$(date '+%Y%m%d_%H%M%S').dump"
on_error() {
    local rc=$?
    echo "" >&2
    echo "エラー: リストアが失敗しました（終了コード ${rc}）。ここで中断します。" >&2
    if [[ "${SCHEMA_DROPPED}" == "1" ]]; then
        echo "  public スキーマは作り直し済みで、DB は空または不完全な可能性があります。" >&2
        echo "  サービスは停止したままです。事前バックアップ ${SAFETY_BACKUP} から同じ手順で戻せます。" >&2
    else
        echo "  public スキーマにはまだ触れていません（DB は元のままです）。" >&2
    fi
    exit "${rc}"
}
trap on_error ERR

echo "=== DBリストア開始 ==="
echo "  ファイル: ${DUMP_FILE}"
echo "  DB: ${DB_NAME}"
echo ""

# 戻すダンプが読めることを、何かを壊す前に確かめる
echo "ダンプの読み取り確認..."
docker exec -i "${DB_CONTAINER}" pg_restore -l < "${DUMP_FILE}" > /dev/null

echo "⚠️  この操作は既存のデータを上書きします。続行しますか？ [yes/no]"
read -r CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
    echo "キャンセルしました"
    exit 0
fi

# 事前バックアップ（読めることまで確かめる。壊れた退避では保険にならない）
mkdir -p "${SAFETY_BACKUP_DIR}"
echo "事前バックアップ取得: ${SAFETY_BACKUP}"
docker exec "${DB_CONTAINER}" \
    pg_dump -U "${DB_USER}" -Fc "${DB_NAME}" \
    < /dev/null > "${SAFETY_BACKUP}"
docker exec -i "${DB_CONTAINER}" pg_restore -l < "${SAFETY_BACKUP}" > /dev/null

echo "サービス停止中: ${STOP_SERVICES}"
# shellcheck disable=SC2086  # 空白区切りの複数サービスとして展開する
"${COMPOSE[@]}" stop ${STOP_SERVICES} < /dev/null

echo "public スキーマを作り直し中..."
# 1 トランザクションで落として作る。途中で失敗したら何も変わらない。
# （cascade で落ちる全オブジェクトの NOTICE は件数が多いので出さない）
# PUBLIC への USAGE とコメントは PostgreSQL 16 の既定の public スキーマに合わせるため。
# （所有者だけは接続ロールのまま。アプリは同じロールで動くので実害はない）
SCHEMA_DROPPED=1
docker exec -e PGOPTIONS="-c client_min_messages=warning" "${DB_CONTAINER}" \
    psql -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 --single-transaction \
    -c "drop schema public cascade" \
    -c "create schema public" \
    -c "grant usage on schema public to public" \
    -c "comment on schema public is 'standard public schema'" \
    < /dev/null

echo "リストア実行中..."
# --clean は付けない。--single-transaction で、途中のエラーはその場で中断する。
docker exec -i "${DB_CONTAINER}" \
    pg_restore -U "${DB_USER}" -d "${DB_NAME}" --single-transaction --exit-on-error \
    < "${DUMP_FILE}"

echo "リストア結果:"
docker exec "${DB_CONTAINER}" \
    psql -U "${DB_USER}" -d "${DB_NAME}" -Atc \
    "select 'schema_migrations: max=' || max(version) || ' count=' || count(*) from schema_migrations" \
    < /dev/null

if [[ "${NO_RESTART}" == "1" ]]; then
    echo "NO_RESTART=1 のためサービスは停止したままです。コードを戻してから起動してください。"
else
    echo "サービス起動中: ${STOP_SERVICES}"
    # shellcheck disable=SC2086
    "${COMPOSE[@]}" start ${STOP_SERVICES} < /dev/null
fi

echo ""
echo "=== リストア完了 ==="
echo "事前バックアップ: ${SAFETY_BACKUP}"
