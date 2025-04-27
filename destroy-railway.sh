#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID=$(railway status --json | jq -r '.projectId')
[ -z "$PROJECT_ID" ] && { echo "No Railway project linked."; exit 1; }
railway delete "$PROJECT_ID" --yes
echo "🗑 Railway project $PROJECT_ID zmazaný."

