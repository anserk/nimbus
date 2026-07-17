#!/bin/bash
# Grants GitHub Actions service principal the minimum roles needed to deploy infra
# Run once when setting up a new environment or after resource group recreation
# Usage: ./scripts/grant-pipeline-roles.sh <subscription-id> <resource-group> <sp-object-id>

SUBSCRIPTION_ID=$1
RG_NAME=$2
SP_OBJECT_ID=$3
LOCATION=$4

if [ -z "$SUBSCRIPTION_ID" ] || [ -z "$RG_NAME" ] || [ -z "$SP_OBJECT_ID" ]; then
  echo "Usage: ./scripts/grant-pipeline-roles.sh <subscription-id> <resource-group> <sp-object-id>"
  exit 1
fi


echo "Granting Contributor on $RG_NAME..."
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME

echo "Granting User Access Administrator on $RG_NAME..."
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME

echo "Done."
