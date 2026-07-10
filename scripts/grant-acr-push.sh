#!/bin/bash
# Grants GitHub Actions service principal AcrPush on the container registry
# Run once after first infra deploy (ACR must exist first)
# Usage: ./scripts/grant-acr-push.sh <sp-object-id> <acr-name> <resource-group>

SP_OBJECT_ID=$1
ACR_NAME=$2
RG_NAME=$3

if [ -z "$SP_OBJECT_ID" ] || [ -z "$ACR_NAME" ] || [ -z "$RG_NAME" ]; then
  echo "Usage: ./scripts/grant-acr-push.sh <sp-object-id> <acr-name> <resource-group>"
  exit 1
fi

ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RG_NAME --query id -o tsv)

echo "Granting AcrPush on $ACR_NAME..."
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role AcrPush \
  --scope $ACR_ID

echo "Done. Build pipeline is ready to push images."
