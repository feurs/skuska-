
#!/usr/bin/env bash
set -e
source "$(dirname "$0")/vars.sh"
echo "Deleting resource group $RG ..."
az group delete -n "$RG" --yes --no-wait
