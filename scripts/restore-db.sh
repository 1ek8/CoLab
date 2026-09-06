#!/usr/bin/env bash
# restore-db.sh — load the latest DB dump from GCS into the fresh Cloud SQL instance.
# Called by bin/up.sh after terraform apply recreates the (empty) instance.
#
# Usage: PROJECT_ID=... ./scripts/restore-db.sh

set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-asia-south1}"
BUCKET="colab-${PROJECT_ID}-backups"
LATEST="gs://${BUCKET}/latest.sql.gz"

echo ">>> Looking for backup at ${LATEST} ..."
if ! gsutil stat "${LATEST}" >/dev/null 2>&1; then
  echo ">>> No backup found. Starting with an empty database."
  exit 0
fi

echo ">>> Importing ${LATEST} into colab-db ..."
gcloud sql import sql colab-db "${LATEST}" \
  --database=colab \
  --project="${PROJECT_ID}" \
  --quiet

echo ">>> Database restore complete."
