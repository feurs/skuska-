#!/usr/bin/env bash
set -euo pipefail

# ───────────────────────────────┐
#  Konfigurovateľné premenné
# ───────────────────────────────┘
RG="cloudexam-rg"
LOC="westeurope"

ACR="crcloudexam1745721511"        # loginServer = $ACR.azurecr.io
IMG_TAG="v1"                       # musí zodpovedať CI buildu

POSTGRES="pg-${RG}"
PG_ADMIN="pgadmin"
PG_PASS=$(openssl rand -base64 16)

ENV_CA="cae-${RG}"
APP_CA="backend"

SWA_NAME="skuska"                  # názov Static Web App vytvorenej skôr

# ───────────────────────────────┐
#  1  Resource Group
# ───────────────────────────────┘
az group create -n "$RG" -l "$LOC"

# ───────────────────────────────┐
#  2  Container Registry
#     (ak už existuje, príkaz nič nemení)
# ───────────────────────────────┘
az acr create -n "$ACR" -g "$RG" --sku Basic --location "$LOC" --admin-enabled false
az acr login  -n "$ACR"

echo "3️⃣  Build & push backend image … preskakujem (image už stavia GitHub Action)"

# ───────────────────────────────┐
#  4  PostgreSQL Flexible Server
# ───────────────────────────────┘
az postgres flexible-server create \
  --name "$POSTGRES" \
  --resource-group "$RG" \
  --location "$LOC" \
  --admin-user "$PG_ADMIN" \
  --admin-password "$PG_PASS" \
  --tier Burstable \
  --sku-name Standard_B1ms \
  --version 16 \
  --storage-size 32 \
  --public-access 0.0.0.0-255.255.255.255

PG_HOST="$(az postgres flexible-server show -g $RG -n $POSTGRES --query fullyQualifiedDomainName -o tsv)"
DB_URL="postgresql://${PG_ADMIN}:${PG_PASS}@${PG_HOST}:5432/postgres"

# ───────────────────────────────┐
#  5  Container Apps Environment
# ───────────────────────────────┘
az containerapp env create -n "$ENV_CA" -g "$RG" -l "$LOC"

# ───────────────────────────────┐
#  6  Backend Container App
# ───────────────────────────────┘
az containerapp create \
  --name "$APP_CA" \
  --resource-group "$RG" \
  --environment "$ENV_CA" \
  --ingress external --target-port 8000 \
  --registry-server "$ACR.azurecr.io" \
  --image "$ACR.azurecr.io/backend:$IMG_TAG" \
  --env-vars DATABASE_URL="$DB_URL"

BACKEND_URL="https://$(az containerapp show -n $APP_CA -g $RG --query properties.latestReadyRevisionfqdn -o tsv)"

# ───────────────────────────────┐
#  7  Nastavíme SWA premennú
# ───────────────────────────────┘
az staticwebapp appsettings set \
   --name "$SWA_NAME" \
   --setting-names VITE_BACKEND_URL="$BACKEND_URL"

FRONTEND_URL="https://$(az staticwebapp show -n "$SWA_NAME" --query defaultHostname -o tsv)"

echo "✅  Backend:  $BACKEND_URL"
echo "✅  Front-end: $FRONTEND_URL"

