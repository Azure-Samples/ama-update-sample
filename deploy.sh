#!/usr/bin/env bash

set -e

# function to echo in green
function info() {
    echo -e "\033[0;32m$1\033[0m"
}

# function to add a secret to a key vault
function addSecret() {
    local secretName=$1
    local secretValue=$2
    local prefix=$3

    az keyvault secret set \
        --vault-name ${prefix}keyvault \
        --name $secretName \
        --value $secretValue
}

function getFunctionKey() {
    local functionName=$1

    info "Doing up to 20 attempts to retrieve the function key for $functionName..."

    local attempts=20
    local sleepTime=30
    set +e
    while [ $attempts -gt 0 ]; do
        functionKey=$(az functionapp keys list --resource-group ${RESOURCE_GROUP_NAME} --name $functionName --query "functionKeys.default" --output tsv)
        if [ -z "$functionKey" ]; then
            info "Function key not found, retrying in ${sleepTime}s..."
            sleep $sleepTime
            attempts=$((attempts-1))
        else
            info "Function key found"
            break
        fi
    done
    set -e
}

# require RESOURCE_GROUP_NAME, LOCATION and APPLIANCE_RESOURCE_PROVIDER_OBJECT_ID
if [ -z "$RESOURCE_GROUP_NAME" ]; then
    echo "RESOURCE_GROUP_NAME is not set"
    exit 1
fi

if [ -z "$LOCATION" ]; then
    echo "LOCATION is not set"
    exit 1
fi

if [ -z "$APPLIANCE_RESOURCE_PROVIDER_OBJECT_ID" ]; then
    echo "APPLIANCE_RESOURCE_PROVIDER_OBJECT_ID is not set"
    exit 1
fi

azSubInfo=$(az account show)
info "Current azure subscription:"
info "$azSubInfo"

if [ -z "$NO_REDEPLOY" ]; then
    # get self principalId
    principalId=$(az ad signed-in-user show --query id -o tsv)
    
    tag=$(date +%s)

    echo $RESOURCE_GROUP_NAME > .resourceGroupName

    info "Deploying bicep file..."
    az deployment sub create \
        --no-prompt \
        --name "ama-update-sample" \
        --location $LOCATION \
        --template-file ./publisher/iac/main.bicep \
        --parameters \
            tag=$tag \
            principalId=$principalId \
            resourceGroupName=$RESOURCE_GROUP_NAME \
            applianceResourceProviderObjectId=$APPLIANCE_RESOURCE_PROVIDER_OBJECT_ID
fi

# get output from deployment
prefix=$(az deployment sub show --name "ama-update-sample" --query properties.outputs.prefix.value -o tsv)

info "Prefix: $prefix"

tag=$(az deployment sub show --name "ama-update-sample" --query properties.outputs.tag.value -o tsv)

info "Tag: $tag"

acrName="${prefix}acr"

if [ -z "$NO_REDEPLOY" ]; then
    info "Waiting 60s for resources to be available..."
    sleep 60

    info "Logging in to ACR..."
    az acr login --name $acrName

    info "Building and pushing docker image..."
    DOCKER_IMAGE_TAG=$tag ACR_NAME=$acrName DOCKER_PUSH=true ./build-docker.sh
fi

webhookFunctionName="${prefix}webhook"
functionKey=""
getFunctionKey $webhookFunctionName
webhookFunctionKey=$functionKey
webhookFunctionUrl="https://${webhookFunctionName}.azurewebsites.net/api?code=${webhookFunctionKey}"

setCommandUrlFunctionName="${prefix}setcommandurl"
functionKey=""
getFunctionKey $setCommandUrlFunctionName
setCommandUrlFunctionKey=$functionKey

info "Adding the key to key vault..."

secretValue="https://${setCommandUrlFunctionName}.azurewebsites.net/api/setcommandurl?code=${setCommandUrlFunctionKey}"

addSecret "setcommandurlurl" $secretValue $prefix

eventsFunctionName="${prefix}events"
functionKey=""
getFunctionKey $eventsFunctionName
eventsFunctionKey=$functionKey

info "Adding the key to key vault..."

secretValue="https://${eventsFunctionName}.azurewebsites.net/api/events?code=${eventsFunctionKey}"

addSecret "eventsurl" $secretValue $prefix


info "Creating acr pull token..."
pullTokenName="pullToken"
pullToken=$(az acr token create \
    --name pullToken \
    --registry $acrName \
    --scope-map "_repositories_pull" \
    --query "credentials.passwords[0].value" \
    --output tsv)


info "Adding the pull token to key vault..."
acrServer=$(az acr show --name $acrName --query loginServer --output tsv)

addSecret "registry" $acrServer $prefix
addSecret "registryUsername" $pullTokenName $prefix
addSecret "registryPassword" $pullToken $prefix

info "Building the Azure Managed App definition..."
DOCKER_IMAGE_TAG=${tag} PUBLISHER_PREFIX=${prefix} PUBLISHER_RESOURCE_GROUP=${RESOURCE_GROUP_NAME} ./build-ama-definition.sh

info "Getting the 'Owner' role id..."
ownerRoleId=$(az role definition list --name Owner --query [].name --output tsv)

info "Getting app definition URL from blob storage..."

containerName="appdefinition"
blobName="appDefinition.zip"
accountName="${prefix}storage"

appDefinitionUrl=$(az storage blob url \
    --account-name ${accountName} \
    --container-name ${containerName} \
    --auth-mode login \
    --name ${blobName} \
    --output tsv)

# tomorrow's date
os=$(uname -s)
if [ "$os" == "Darwin" ]; then
    expiryDate=$(date -v+1d '+%Y-%m-%dT%H:%M:%SZ')
else
    expiryDate=$(date -d "+1 day" '+%Y-%m-%dT%H:%M:%SZ')
fi

blobQuerystring=$(az storage blob generate-sas \
    --account-name ${accountName} \
    --container-name ${containerName} \
    --name ${blobName} \
    --as-user \
    --auth-mode login \
    --permissions r \
    --expiry ${expiryDate} \
    --output tsv)

appDefinitionFullUrl="${appDefinitionUrl}?${blobQuerystring}"

info "Deploying the Azure Managed App..."

az deployment group create \
    --name "ama-update-sample-definition" \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file ./ama-definition-deploy.json \
    --parameters \
        applicationName="ama-update-sample" \
        _artifactsLocation=$appDefinitionFullUrl \
        notificationUrl=$webhookFunctionUrl
