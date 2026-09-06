#!/usr/bin/env bash
# backup-db.sh — dump the running Cloud SQL DB and upload to GCS.
# Called by bin/down.sh before tearing everything down (so data survives).
#
# Usage: PROJECT_ID=... REGION=... ./scripts/backup-db.sh

set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-asia-south1}"
DB_INSTANCE="colab-db"
BUCKET="colab-${PROJECT_ID}-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
DUMP="colab-${STAMP}.sql.gz"

echo ">>> Backing up Cloud SQL instance ${DB_INSTANCE} ..."
gcloud sql export sql "${DB_INSTANCE}" \
  "gs://${BUCKET}/${DUMP}" \
  --database=colab \
  --project="${PROJECT_ID}" \
  --quiet

echo ">>> Uploaded to gs://${BUCKET}/${DUMP}"

# Keep a stable pointer "latest" so restore-db.sh always knows which dump to use.
# gsutil cannot copy onto itself if the object already matches; force it.
LATEST="gs://${BUCKET}/latest.sql.gz"
gsutil cp "gs://${BUCKET}/${DUMP}" "${LATEST}" --force >/dev/null 2>&1 || \
gsutil cp "gs://${BUCKET}/${DUMP}" "${LATEST}"

echo ">>> Updated pointer: ${LATEST}"
echo ">>> Backup complete."
