#!/usr/bin/env bash
# gcp-init.sh — ONE-TIME GCP setup.
# - authenticates gcloud
# - creates the project (if needed)
# - enables required APIs
# - creates the GCS bucket used for remote Terraform state
# - runs `terraform init` in infra/
#
# Usage: ./bin/gcp-init.sh

set -euo pipefail

REGION="${REGION:-asia-south1}"
PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID, e.g. colab-app}"

echo ">>> Authenticating ..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
  gcloud auth login
fi

echo ">>> Ensuring project ${PROJECT_ID} exists ..."
if ! gcloud projects describe "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud projects create "${PROJECT_ID}" --name="CoLab"
fi
gcloud config set project "${PROJECT_ID}"

echo ">>> Enabling APIs ..."
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  compute.googleapis.com \
  --project="${PROJECT_ID}"

echo ">>> Setting region default ..."
gcloud config set run/region "${REGION}"
gcloud config set compute/region "${REGION}"

# Remote state bucket (must be globally unique).
TF_STATE_BUCKET="colab-tfstate-${PROJECT_ID}"
if ! gsutil ls "gs://${TF_STATE_BUCKET}" >/dev/null 2>&1; then
  echo ">>> Creating Terraform state bucket gs://${TF_STATE_BUCKET} ..."
  gsutil mb -l "${REGION}" "gs://${TF_STATE_BUCKET}"
fi

echo ">>> Bootstrapping terraform (remote backend) ..."
cd "$(dirname "$0")/../infra"
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=terraform/state"

echo ">>> GCP init complete."
echo "    Next, run ./bin/up.sh to bring the stack UP."
