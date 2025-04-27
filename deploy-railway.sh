#!/usr/bin/env bash
set -euo pipefail

EMAIL="dl803qo@student.tuke.sk"                     # len informačné
PROJECT="cloudexam-$(date +%s)"

echo "🔑 Railway login (browserless)…"
railway login --browserless || true

echo "🚀 Init project $PROJECT"
railway init --name "$PROJECT"
PROJECT_ID=$(railway status --json | jq -r '.projectId')

echo "🐘 PostgreSQL + volume"
railway add --database postgres --service db
railway volume add --service db --name pgdata \
                   --size 1GB --mount-path /var/lib/postgresql/data
DB_URL=$(railway variables -s db --json | jq -r '.[]|select(.key=="DATABASE_URL")|.value')

echo "🔧 Backend build & deploy"
railway link "$PROJECT_ID"
railway add --service backend
railway up  --service backend --build-filter Dockerfile.backend
BACKEND_URL=$(railway domain --service backend --port 8000 --json | jq -r '.domain')
railway variables --service backend --set DATABASE_URL="$DB_URL"
railway redeploy --service backend --yes

echo "🎨 Frontend build & deploy"
railway add --service frontend
railway variables --service frontend --set VITE_BACKEND_URL="https://$BACKEND_URL"
railway up --service frontend --build-filter Dockerfile.frontend
FRONT_URL=$(railway domain --service frontend --port 80 --json | jq -r '.domain')

echo "✅ LIVE → https://$FRONT_URL"

