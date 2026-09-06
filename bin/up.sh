#!/usr/bin/env bash
# up.sh — bring the CoLab stack UP (idempotent / re-runnable).
# - terraform apply (creates Cloud SQL, secrets, Cloud Run services, bucket)
# - restores the latest DB dump from GCS (if any)
# - applies prisma migrations (safety net)
# - builds + pushes images and deploys to Cloud Run
#
# Usage: ./bin/up.sh
#
# Required project-specific values come from ./bin/.env (created from .env.example).

set -euo pipefail

cd "$(dirname "$0")/.." # repo root

# Load project-level config (PROJECT_ID, JWT_SECRET, DB_PASSWORD).
if [[ -f bin/.env ]]; then
  set -a
  source bin/.env
  set +a
else
  echo "Missing bin/.env. Create it from bin/.env.example first."
  exit 1
fi

export REGION="${REGION:-asia-south1}"
export PROJECT_ID
export TF_VAR_project_id="${PROJECT_ID}"
export TF_VAR_region="${REGION}"
export TF_VAR_jwt_secret="${JWT_SECRET}"
export TF_VAR_db_password="${DB_PASSWORD}"

echo "============================================="
echo "  CoLab UP — project ${PROJECT_ID} (${REGION})"
echo "============================================="

# 1) Apply infrastructure
TF_STATE_BUCKET="colab-tfstate-${PROJECT_ID}"
echo ">>> terraform apply ..."
cd infra
terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=terraform/state" >/dev/null 2>&1 \
  || (echo "Run ./bin/gcp-init.sh first." && exit 1)
terraform apply -auto-approve
cd ..

# 2) Restore latest DB backup (if exists) into the fresh instance
echo ">>> Restoring database (if backup exists) ..."
./scripts/restore-db.sh

# 3) Prisma migrations as a safety net
echo ">>> Applying prisma migrations ..."
DB_HOST="$(cd infra && terraform output -raw database_ip)"
export DATABASE_URL="postgresql://colab-user:${DB_PASSWORD}@${DB_HOST}:5432/colab"
(
  cd packages/db
  npx prisma migrate deploy
)

# 4) Build + push images + deploy to Cloud Run
echo ">>> Deploying images ..."
./scripts/deploy-images.sh

echo ""
echo ">>> CoLab is UP. Use bin/down.sh to shut it down."
