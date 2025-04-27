#!/usr/bin/env bash
set -eo pipefail
# Load initial vars (resource names, etc.)
source "$(dirname "$0")/vars.sh"

_blue "\n➡️  1)  Login & subscription"
az login --use-device-code
az account set --subscription "$AZ_SUBSCRIPTION"

# Fetch the actual current subscription ID
ACTUAL_SUB=$(az account show --query id -o tsv)
_blue "🛠️  Using subscription: $ACTUAL_SUB"

_blue "\n➡️  2)  Resource group"
az group create \
  --subscription "$ACTUAL_SUB" \
  -n "$RG" -l "$LOCATION" \
  --output none

_blue "\n➡️  3)  Azure Container Registry"
az acr create \
  --subscription "$ACTUAL_SUB" \
  -n "$ACR" -g "$RG" -l "$LOCATION" \
  --sku Basic --admin-enabled true \
  --output none
az acr login \
  --subscription "$ACTUAL_SUB" \
  -n "$ACR"

_blue "\n➡️  4)  Build & push images"
docker build -t $ACR.azurecr.io/$IMG_FRONT:$TAG ./front
docker push $ACR.azurecr.io/$IMG_FRONT:$TAG
docker build -t $ACR.azurecr.io/$IMG_BACK:$TAG ./back
docker push $ACR.azurecr.io/$IMG_BACK:$TAG

_blue "\n➡️  5)  Storage account + File share"
az storage account create \
  --subscription "$ACTUAL_SUB" \
  -n "$STG" -g "$RG" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --output none

STG_KEY=$(az storage account keys list \
  --subscription "$ACTUAL_SUB" \
  -g "$RG" -n "$STG" \
  --query "[0].value" -o tsv)

az storage share-rm create \
  --subscription "$ACTUAL_SUB" \
  -g "$RG" \
  -n "$FILE_SHARE" \
  --storage-account "$STG" \
  --output none

_blue "\n➡️  6)  Container Apps Environment"
if az containerapp env show \
     --subscription "$ACTUAL_SUB" \
     -n "$CA_ENV" -g "$RG" &>/dev/null; then
  _blue "Environment '$CA_ENV' exists – skipping creation"
else
  az extension add --name containerapp --upgrade --yes
  az containerapp env create \
    --subscription "$ACTUAL_SUB" \
    -n "$CA_ENV" -g "$RG" -l "$LOCATION" \
    --output none
fi

_blue "\n➡️  7)  Attach storage to CA env"
# remove old binding if present
az containerapp env storage remove \
  --subscription "$ACTUAL_SUB" \
  -n "$CA_ENV" -g "$RG" \
  --storage-name mystorage \
  --yes || true

az containerapp env storage set \
  --subscription "$ACTUAL_SUB" \
  -n "$CA_ENV" -g "$RG" \
  --storage-name mystorage \
  --azure-file-account-name "$STG" \
  --azure-file-account-key "$STG_KEY" \
  --azure-file-share-name "$FILE_SHARE" \
  --access-mode ReadWrite \
  --output none

_blue "\n➡️  8)  Create back-end app"
az containerapp create \
  --subscription "$ACTUAL_SUB" \
  -n "$CA_BACK" -g "$RG" --environment "$CA_ENV" \
  --image "$ACR.azurecr.io/$IMG_BACK:$TAG" \
  --registry-server "$ACR.azurecr.io" \
  --target-port 8000 --ingress internal \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 1 --max-replicas 3

_blue "\n➡️  9)  Create front-end app"
az containerapp create \
  --subscription "$ACTUAL_SUB" \
  -n "$CA_FRONT" -g "$RG" --environment "$CA_ENV" \
  --image "$ACR.azurecr.io/$IMG_FRONT:$TAG" \
  --registry-server "$ACR.azurecr.io" \
  --target-port 80 --ingress external \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 1 --max-replicas 3

_blue "\n➡️ Fetching public URL"
FRONT_URL=$(az containerapp show \
  --subscription "$ACTUAL_SUB" \
  -n "$CA_FRONT" -g "$RG" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

_blue "\n✅  Deployment complete! Public URL:"
echo "https://$FRONT_URL"
