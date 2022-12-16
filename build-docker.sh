#!/usr/bin/env bash

if [ -z "$ACR_NAME" ]; then
    echo "ACR_NAME is not set"
    exit 1
fi

if [ -z "$DOCKER_IMAGE_TAG" ]; then
    echo "DOCKER_IMAGE_TAG is not set"
    exit 1
fi

DOCKER_REGISTRY="${ACR_NAME}.azurecr.io"
DOCKER_IMAGE_NAME_BASE="ama-update-sample"

function build_docker() {
    local FUNCTION_NAME=$1
    local FUNCTION_PATH=$2

    local DOCKER_IMAGE_NAME="${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME_BASE}-${FUNCTION_NAME}:${DOCKER_IMAGE_TAG}"
    
    echo "Building docker image ${DOCKER_IMAGE_NAME}..."
    docker build --platform linux/amd64 -t "${DOCKER_IMAGE_NAME}" --build-arg FUNCTION_PATH="${FUNCTION_PATH}" .

    # if DOCKER_PUSH is not empty then push the image
    if [ ! -z "$DOCKER_PUSH" ]; then
        echo "Pushing docker image ${DOCKER_IMAGE_NAME}..."
        docker push "${DOCKER_IMAGE_NAME}"
    fi
}

build_docker "commands" "ama/commands"
build_docker "deployment" "publisher/deployment"
build_docker "events" "publisher/events"
build_docker "setcommandurl" "publisher/setcommandurl"
build_docker "webhook" "publisher/webhook"

# build the docker image for AMA resources
RESOURCES_DOCKER_IMAGE_NAME="${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME_BASE}-resources:${DOCKER_IMAGE_TAG}"
echo "Building docker image ${RESOURCES_DOCKER_IMAGE_NAME}..."
docker build \
    --platform linux/amd64 \
    -t "${RESOURCES_DOCKER_IMAGE_NAME}" \
    -f ./ama/resources/Dockerfile \
    ./ama/resources

# if DOCKER_PUSH is not empty then push the image
if [ ! -z "$DOCKER_PUSH" ]; then
    echo "Pushing docker image ${RESOURCES_DOCKER_IMAGE_NAME}..."
    docker push "${RESOURCES_DOCKER_IMAGE_NAME}"
fi