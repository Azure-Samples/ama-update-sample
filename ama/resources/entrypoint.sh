#!/usr/bin/env bash

az login --identity

echo "Resource group: ${resourceGroupName}"

az deployment group create \
    --resource-group ${resourceGroupName} \
    --template-file ./main.bicep