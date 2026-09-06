#!/usr/bin/env bash
# down.sh — bring the CoLab stack DOWN to $0/month.
# - backs up the database to GCS (SO data survives)
# - terraform destroy (removes Cloud SQL, secrets, Cloud Run services, images)
# - leaves the GCS backup bucket intact for the next bin/up.sh
#
# Usage: ./bin/down.sh
#
# Required values come from ./bin/.env (see bin/.env.example).

set -euo pipefail

cd "$(dirname "$0")/.." # repo root

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

echo "============================================="
echo "  CoLab DOWN — project ${PROJECT_ID}"
echo "============================================="

# 1) Backup database BEFORE destroying it
echo ">>> Backing up database to GCS ..."
./scripts/backup-db.sh

# 2) Delete the Cloud Run services (created by deploy-images.sh, not Terraform)
echo ">>> Deleting Cloud Run services ..."
gcloud run services delete http-backend --region="${REGION}" --platform=managed --quiet --project="${PROJECT_ID}" 2>/dev/null || true
gcloud run services delete ws-backend --region="${REGION}" --platform=managed --quiet --project="${PROJECT_ID}" 2>/dev/null || true
gcloud run services delete colab-fe --region="${REGION}" --platform=managed --quiet --project="${PROJECT_ID}" 2>/dev/null || true

# 3) Destroy all infrastructure (keeps the GCS backup bucket via lifecycle)
TF_STATE_BUCKET="colab-tfstate-${PROJECT_ID}"
echo ">>> terraform destroy ..."
cd infra
terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=terraform/state" >/dev/null 2>&1 \
  || (echo "Terraform not initialized. Run ./bin/gcp-init.sh." && exit 1)
terraform destroy -auto-approve
cd ..

echo ""
echo ">>> CoLab is DOWN. ~$0/month while stopped."
echo "    Data is safe in GCS. Relaunch any time with ./bin/up.sh"
