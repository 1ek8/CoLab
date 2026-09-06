#!/usr/bin/env bash
# deploy-images.sh — build + push the 3 Docker images, then create/update the
# Cloud Run services. Called by bin/up.sh (initial deploy) and developers.
# Cloud Build (git auto-deploy) mirrors these steps in cloudbuild.yaml.
#
# Usage: PROJECT_ID=... REGION=... [IMAGE_TAG=...] ./scripts/deploy-images.sh
#
# Ordering matters:
#   1. build+deploy http-backend, then ws-backend   (no external URL needed)
#   2. read their real Cloud Run URLs from gcloud
#   3. build+deploy colab-fe with those URLs inlined (Next.js bakes
#      NEXT_PUBLIC_* into the browser bundle at build time)
#   4. update http-backend's ALLOWED_ORIGINS with the real frontend URL

set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-asia-south1}"
IMAGE_REGION="${IMAGE_REGION:-$REGION}"
TAG="${IMAGE_TAG:-latest}"
REPO="colab-images"
PREFIX="${IMAGE_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}"

cd "$(dirname "$0")/.." # repo root

# CORS / secrets flags shared by every service deploy.
SECRETS="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest"

# ---- 1) Build + deploy the two backends (no external URLs needed) ----
# Cloud Run only supports linux/amd64; the dev Mac is arm64, so pin the platform.
PLATFORM="linux/amd64"

echo ">>> Building + deploying http-backend ..."
docker build --platform="${PLATFORM}" --target=http-backend --tag="${PREFIX}/http-backend:${TAG}" .
docker push "${PREFIX}/http-backend:${TAG}"
gcloud run deploy http-backend \
  --image="${PREFIX}/http-backend:${TAG}" \
  --region="${REGION}" --platform=managed --allow-unauthenticated --port=3001 \
  --cpu=1 --memory=512Mi --min-instances=0 --max-instances=10 \
  --set-secrets="${SECRETS}" \
  --set-env-vars=NODE_ENV=production \
  --project="${PROJECT_ID}"

echo ">>> Building + deploying ws-backend ..."
docker build --platform="${PLATFORM}" --target=ws-backend --tag="${PREFIX}/ws-backend:${TAG}" .
docker push "${PREFIX}/ws-backend:${TAG}"
gcloud run deploy ws-backend \
  --image="${PREFIX}/ws-backend:${TAG}" \
  --region="${REGION}" --platform=managed --allow-unauthenticated --port=8080 \
  --cpu=1 --memory=512Mi --min-instances=1 --max-instances=5 \
  --no-use-http2 \
  --set-secrets="${SECRETS}" \
  --set-env-vars=NODE_ENV=production \
  --project="${PROJECT_ID}"

# ---- 2) Read the real backend URLs back from Cloud Run ----
HTTP_URL="$(gcloud run services describe http-backend --region="${REGION}" --platform=managed --format="value(status.url)")"
WS_URL_HTTP="$(gcloud run services describe ws-backend --region="${REGION}" --platform=managed --format="value(status.url)")"
WS_URL="$(echo "${WS_URL_HTTP}" | sed 's/^https:/wss:/')"
echo "    http-backend : ${HTTP_URL}"
echo "    ws-backend   : ${WS_URL}"

# ---- 3) Build + deploy the frontend with those URLs baked in ----
echo ">>> Building frontend with backend URLs ..."
docker build \
  --platform="${PLATFORM}" \
  --target=frontend \
  --build-arg=NEXT_PUBLIC_BACKEND_URL="${HTTP_URL}" \
  --build-arg=NEXT_PUBLIC_WS_URL="${WS_URL}" \
  --tag="${PREFIX}/colab-fe:${TAG}" \
  .
docker push "${PREFIX}/colab-fe:${TAG}"

echo ">>> Deploying colab-fe ..."
gcloud run deploy colab-fe \
  --image="${PREFIX}/colab-fe:${TAG}" \
  --region="${REGION}" --platform=managed --allow-unauthenticated --port=3000 \
  --cpu=1 --memory=512Mi --min-instances=0 --max-instances=10 \
  --set-env-vars=NEXT_PUBLIC_BACKEND_URL="${HTTP_URL}",NEXT_PUBLIC_WS_URL="${WS_URL}",NODE_ENV=production \
  --project="${PROJECT_ID}"

# ---- 4) Point http-backend's CORS allowlist at the real frontend URL ----
FE_URL="$(gcloud run services describe colab-fe --region="${REGION}" --platform=managed --format="value(status.url)")"
gcloud run services update http-backend \
  --region="${REGION}" --platform=managed \
  --set-env-vars=ALLOWED_ORIGINS="${FE_URL}" \
  --project="${PROJECT_ID}"

# ---- 5) Ensure public access (--allow-unauthenticated can be flaky mid-pipeline) ----
for svc in http-backend ws-backend colab-fe; do
  gcloud run services add-iam-policy-binding "${svc}" \
    --region="${REGION}" --platform=managed \
    --member=allUsers --role=roles/run.invoker \
    --project="${PROJECT_ID}" >/dev/null 2>&1 || true
done

echo ""
echo ">>> DONE. Frontend live at: ${FE_URL}"
echo "    (http API): ${HTTP_URL} | (ws): ${WS_URL}"