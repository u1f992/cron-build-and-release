#!/bin/bash

set -euo pipefail

DOCKER=/usr/bin/docker
DEVCONTAINER=/usr/bin/devcontainer
JQ=/usr/bin/jq
GREP=/usr/bin/grep
TAIL=/usr/bin/tail
TIMEOUT=/usr/bin/timeout

WORKSPACE_FOLDER="${1:?Usage: run-in-devcontainer.sh <workspace-folder> <command>}"
COMMAND="${2:?Usage: run-in-devcontainer.sh <workspace-folder> <command>}"

CONTAINER_NAME=""
BASE_IMAGE_NAME=""
IMAGE_NAME=""

cleanup() {
    local exit_code=$?

    if [ -n "$CONTAINER_NAME" ]; then
        echo "Removing container: $CONTAINER_NAME"
        $DOCKER rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi

    if [ -n "$IMAGE_NAME" ]; then
        echo "Removing image: $IMAGE_NAME"
        $DOCKER rmi -f "$IMAGE_NAME" 2>/dev/null || true
    fi
    if [ -n "$BASE_IMAGE_NAME" ]; then
        echo "Removing base image: $BASE_IMAGE_NAME"
        $DOCKER rmi -f "$BASE_IMAGE_NAME" 2>/dev/null || true
    fi

    exit $exit_code
}

trap cleanup EXIT

cd "$WORKSPACE_FOLDER"

# Build devcontainer image
echo "Building devcontainer image..."
BUILD_OUTPUT=$($DEVCONTAINER build --workspace-folder . 2>&1)
echo "$BUILD_OUTPUT"
BUILD_JSON=$(echo "$BUILD_OUTPUT" | $GREP -E '^\{' | $TAIL -1)

if [ -z "$BUILD_JSON" ]; then
    echo "Error: Failed to parse devcontainer build output"
    exit 1
fi

OUTCOME=$(echo "$BUILD_JSON" | $JQ -r '.outcome')
if [ "$OUTCOME" != "success" ]; then
    echo "Error: devcontainer build failed"
    exit 1
fi

BASE_IMAGE_NAME=$(echo "$BUILD_JSON" | $JQ -r '.imageName[0]')
echo "Base image name: $BASE_IMAGE_NAME"

# Start devcontainer
# Workaround for devcontainer CLI issue (https://github.com/devcontainers/cli/issues/430)
echo "Starting devcontainer (phase 1: create container)..."
$TIMEOUT 10 $DEVCONTAINER up --workspace-folder . 2>&1 || true

echo "Starting devcontainer (phase 2: get container info)..."
DEVCONTAINER_OUTPUT=$($DEVCONTAINER up --workspace-folder . 2>&1)
echo "$DEVCONTAINER_OUTPUT"
DEVCONTAINER_JSON=$(echo "$DEVCONTAINER_OUTPUT" | $GREP -E '^\{' | $TAIL -1)

if [ -z "$DEVCONTAINER_JSON" ]; then
    echo "Error: Failed to parse devcontainer output"
    exit 1
fi

OUTCOME=$(echo "$DEVCONTAINER_JSON" | $JQ -r '.outcome')
if [ "$OUTCOME" != "success" ]; then
    echo "Error: devcontainer up failed"
    exit 1
fi

CONTAINER_NAME=$(echo "$DEVCONTAINER_JSON" | $JQ -r '.containerId')
IMAGE_NAME=$($DOCKER inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "")
echo "Container ID: $CONTAINER_NAME"
echo "Image name: $IMAGE_NAME"

# Run command inside devcontainer
echo "Running command inside devcontainer..."
$DEVCONTAINER exec --workspace-folder . bash -c "$COMMAND"
