#!/usr/bin/env bash
set -euo pipefail

# ───────────────────────────────┐
#  KONFIGURÁCIA
# ───────────────────────────────┘
RG="cloudexam-rg"
LOC="westeurope"                   # frontend + ACR + Container Apps
ACR="crcloudexam1745721511"        # už vytvorený registry
IMG_TAG="v1"                       # tag, ktorý pushuje GitHub Action

# ► PostgreSQL — použijeme povolený región northeurope
PG_REGION="northeurope"
POSTGRES="pg-${RG}-$(date +%s)"    # unikátny názov
PG_ADMIN="pgadmin"
PG_PASS=$(openssl rand -base64 16)

# ► Container Apps
ENV_CA="cae-${RG}"
APP_CA="backend"

# ► Static Web Apps (vytvorená skôr)
SWA_NAME="skuska"

# ───────────────────────────────┐
#  0  Zaregistruj potrebné providery
# ───────────────────────────────┘
echo "🔑  Registering resource providers (一次)…"
for p in Microsoft.ContainerRegistry Microsoft.DBforPostgreSQL \
         Microsoft.App Microsoft.OperationalInsights; do
  az provider register -n $p --wait
done

# ───────────────────────────────┐
#  1  Resource Group
# ───────────────────────────────┘
az group create -n "$RG" -l "$LOC"

# ───────────────────────────────┐
#  2  ACR (idempotent)
# ───────────────────────────────┘
az acr create -n "$ACR" -g "$RG" --sku Basic --location "$LOC" --admin-enabled false
az acr login  -n "$ACR"

echo "3️⃣  Build & push backend image … preskakujem (image pripraví GitHub Action)"

# ───────────────────────────────┐
#  4  PostgreSQL Flexible Server
#     (len ak ešte neexistuje)
# ───────────────────────────────┘
if ! az postgres flexible-server show -g "$RG" -n "$POSTGRES" &>/dev/null; then
  echo "🐘  Creating PostgreSQL server $POSTGRES in $PG_REGION…"
  az postgres flexible-server create \
       --name "$POSTGRES" \
       --resource-group "$RG" \
       --location "$PG_REGION" \
       --admin-user "$PG_ADMIN" \
       --admin-password "$PG_PASS" \
       --tier Burstable \
       --sku-name Standard_B1ms \
       --version 16 \
       --storage-size 32 \
       --create-default-database Disabled \
       --public-access 0.0.0.0-255.255.255.255
else
  echo "🐘  PostgreSQL server $POSTGRES already exists – skipping create."
fi

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

BACKEND_URL=$(az containerapp show -n $APP_CA -g $RG --query properties.latestReadyRevisionfqdn -o tsv)
echo "✅  Backend running at: https://$BACKEND_URL"

# ───────────────────────────────┐
#  7  Update Static Web App env var
# ───────────────────────────────┘
az staticwebapp appsettings set \
   --name "$SWA_NAME" \
   --setting-names VITE_BACKEND_URL="https://${BACKEND_URL}"

FRONT_URL=$(az staticwebapp show -n "$SWA_NAME" --query defaultHostname -o tsv)
echo -e "\n🎉  Front-end URL (HTTPS): https://${FRONT_URL}\n"

