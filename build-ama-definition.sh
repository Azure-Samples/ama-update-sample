#!/usr/bin/env bash

set -e

if [ -z "$PUBLISHER_PREFIX" ]; then
    echo "PUBLISHER_PREFIX is not set"
    exit 1
fi

if [ -z "$PUBLISHER_RESOURCE_GROUP" ]; then
    echo "PUBLISHER_RESOURCE_GROUP is not set"
    exit 1
fi

if [ -z "$DOCKER_IMAGE_TAG" ]; then
    echo "DOCKER_IMAGE_TAG is not set"
    exit 1
fi


# get current az subscription id
PUBLISHER_SUBSCRIPTION=$(az account show --query id -o tsv)

tmpDir=$(mktemp -d)
cp -r ./ama/definition/bicep/* $tmpDir

# replace variables (Linux, MacOS compatible)
sed -i.bak "s/PUBLISHER_PREFIX/$PUBLISHER_PREFIX/g" $tmpDir/mainTemplate.bicep
sed -i.bak "s/PUBLISHER_RESOURCE_GROUP/$PUBLISHER_RESOURCE_GROUP/g" $tmpDir/mainTemplate.bicep
sed -i.bak "s/PUBLISHER_SUBSCRIPTION/$PUBLISHER_SUBSCRIPTION/g" $tmpDir/mainTemplate.bicep
sed -i.bak "s/DOCKER_IMAGE_TAG/$DOCKER_IMAGE_TAG/g" $tmpDir/mainTemplate.bicep

rm $tmpDir/*.bak

# build
az bicep build --file $tmpDir/mainTemplate.bicep --outdir ./ama/definition/arm

# remove temp dir
rm -rf $tmpDir

# build zip file
cd ./ama/definition/arm
rm -f ../appDefinition.zip
zip ../appDefinition.zip *
cd ../../..

# upload zip file to storage account

az storage blob upload \
    --account-name ${PUBLISHER_PREFIX}storage \
    --container-name "appdefinition" \
    --auth-mode login \
    --overwrite \
    --name "appDefinition.zip" \
    --file "./ama/definition/appDefinition.zip"