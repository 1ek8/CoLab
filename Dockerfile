# ============================================================
# CoLab — multi-stage Dockerfile for Railway / GCP Cloud Run.
# Select the target you need:
#   --target frontend      (Next.js  / PORT env)
#   --target http-backend  (Express  / PORT env)
#   --target ws-backend    (WebSocket/ PORT env)
# ============================================================

# ---- BASE ----
FROM node:20-slim AS base
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm@10.7.1
ENV NEXT_TELEMETRY_DISABLED=1

# ---- DEPS: install the full workspace ----
FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/ ./apps/
COPY packages/ ./packages/
RUN pnpm install --frozen-lockfile

# ---- BUILD: generate Prisma client and compile everything ----
FROM deps AS build
WORKDIR /app

# NEXT_PUBLIC_* vars are inlined into the browser bundle by Next.js at build time.
ARG NEXT_PUBLIC_BACKEND_URL
ARG NEXT_PUBLIC_WS_URL
ENV NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL \
    NEXT_PUBLIC_WS_URL=$NEXT_PUBLIC_WS_URL

# --ui=stream avoids some of turborepo's .turbo/ log-dir churn which fails under
# QEMU/arm64→amd64 emulation with EINTR. We ALSO pre-create every package's .turbo/
# dir and retry once, because that EINTR is flaky and turbo aborts the build if it
# can't mkdir its log dir at all.
RUN find /app/apps /app/packages -mindepth 1 -maxdepth 1 -type d -exec mkdir -p '{}/.turbo' \; \
    && (pnpm exec turbo run build --ui=stream || pnpm exec turbo run build --ui=stream)

# ---- FRONTEND (Next.js) ----
# `next start` reads PORT and must bind 0.0.0.0 for Cloud Run.
FROM build AS frontend
WORKDIR /app/apps/colab-fe
ENV NODE_ENV=production
CMD ["sh", "-c", "HOSTNAME=0.0.0.0 PORT=${PORT:-3000} pnpm start"]

# ---- HTTP BACKEND (Express REST API) ----
FROM build AS http-backend
WORKDIR /app/apps/http-backend
ENV NODE_ENV=production
CMD ["node", "./dist/index.js"]

# ---- WEBSOCKET BACKEND ----
FROM build AS ws-backend
WORKDIR /app/apps/ws-backend
ENV NODE_ENV=production
CMD ["node", "./dist/index.js"]