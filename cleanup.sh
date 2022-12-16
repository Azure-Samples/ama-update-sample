#!/usr/bin/env bash

set -e


if [ -z "$RESOURCE_GROUP_NAME" ]; then
    # try to load the value from .resourceGroupName file
    RESOURCE_GROUP_NAME=$(cat .resourceGroupName)
fi

# require RESOURCE_GROUP_NAME
if [ -z "$RESOURCE_GROUP_NAME" ]; then
    echo "RESOURCE_GROUP_NAME is not set"
    exit 1
fi

echo "Deleting resource group $RESOURCE_GROUP_NAME"
az group delete --name $RESOURCE_GROUP_NAME --no-wait