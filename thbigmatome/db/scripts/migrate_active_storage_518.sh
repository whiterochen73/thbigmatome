#!/bin/bash
# Active Storage移行スクリプト (subtask_518a)
# ローカルDB (port 5432) → Docker内DB (port 5433)
# PlayerCard IDオフセット: 483 (ローカルid+483=DockerID)

set -e

LOCAL_PSQL="psql -U morinaga -d thbigmatome_development"
DOCKER_PSQL="psql -h localhost -p 5433 -U morinaga -d thbigmatome_development"

echo "=== Active Storage移行スクリプト (subtask_518a) ==="
echo "LocalDB (5432) → DockerDB (5433)"
echo "PlayerCard IDオフセット: 483"
echo ""

# 事前確認
echo "--- 移行前 確認 ---"
echo "[LocalDB] blobsとattachments件数:"
$LOCAL_PSQL -c "SELECT COUNT(*) as blobs FROM active_storage_blobs; SELECT COUNT(*) as attachments FROM active_storage_attachments;"
echo "[DockerDB] blobsとattachments件数:"
$DOCKER_PSQL -c "SELECT COUNT(*) as blobs FROM active_storage_blobs; SELECT COUNT(*) as attachments FROM active_storage_attachments;"

echo ""
echo "--- Step 3a: blobsをCSVエクスポート→DockerDBにインポート ---"

# ローカルからCSVエクスポート
$LOCAL_PSQL -c "\COPY active_storage_blobs TO '/tmp/as_blobs.csv' CSV HEADER"
echo "blobsエクスポート完了: /tmp/as_blobs.csv"

# Docker内DBにtmpテーブル経由でINSERT (ON CONFLICT対応)
$DOCKER_PSQL <<'SQL'
CREATE TEMP TABLE tmp_blobs (LIKE active_storage_blobs INCLUDING ALL);
\COPY tmp_blobs FROM '/tmp/as_blobs.csv' CSV HEADER
INSERT INTO active_storage_blobs
  SELECT * FROM tmp_blobs
  ON CONFLICT (key) DO NOTHING;
DROP TABLE tmp_blobs;
SQL
echo "blobsインポート完了"

echo ""
echo "--- Step 3b: attachmentsをoffset変換してインポート ---"

# ローカルからattachmentsをCSVエクスポート
$LOCAL_PSQL -c "\COPY active_storage_attachments TO '/tmp/as_attachments.csv' CSV HEADER"
echo "attachmentsエクスポート完了: /tmp/as_attachments.csv"

# Docker内DBにtmpテーブル経由でoffset変換してINSERT
$DOCKER_PSQL <<'SQL'
CREATE TEMP TABLE tmp_attachments (LIKE active_storage_attachments INCLUDING ALL);
\COPY tmp_attachments FROM '/tmp/as_attachments.csv' CSV HEADER
INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
  SELECT name, record_type, (record_id + 483), blob_id, created_at
  FROM tmp_attachments
  ON CONFLICT (record_type, record_id, name, blob_id) DO NOTHING;
DROP TABLE tmp_attachments;
SQL
echo "attachmentsインポート完了"

echo ""
echo "--- Step 4: 整合性確認 ---"
$DOCKER_PSQL <<'SQL'
SELECT COUNT(*) as total_blobs FROM active_storage_blobs;
SELECT COUNT(*) as total_attachments FROM active_storage_attachments;
SELECT COUNT(*) as player_card_attachments FROM active_storage_attachments WHERE record_type = 'PlayerCard';
SQL

echo ""
echo "=== 移行完了 ==="
