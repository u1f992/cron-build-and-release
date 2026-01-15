#!/bin/bash

set -euo pipefail

GIT=/usr/bin/git
GH=/usr/bin/gh
JQ=/usr/bin/jq
DATE=/usr/bin/date
TEE=/usr/bin/tee
RM=/usr/bin/rm
MKTEMP=/usr/bin/mktemp
CAT=/usr/bin/cat

REPO_NAME="${REPO_NAME:?REPO_NAME is required}"
BUILD_COMMAND="${BUILD_COMMAND:?BUILD_COMMAND is required}"
RELEASE_ASSET="${RELEASE_ASSET:?RELEASE_ASSET is required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/cron-build-and-release.log"
LOCK_FILE="${SCRIPT_DIR}/.cron-build-and-release.lock"

log() {
    echo "[$($DATE --iso-8601=seconds)] $*" | $TEE -a "$LOG_FILE"
}

cleanup() {
    local exit_code=$?

    $RM -f "$LOCK_FILE"

    if [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
        log "Removing temp directory: $WORK_DIR"
        $RM -rf "$WORK_DIR"
    fi

    exit $exit_code
}

# ====================
# Main
# ====================
trap cleanup EXIT

# Prevent concurrent execution
if [ -f "$LOCK_FILE" ]; then
    pid=$($CAT "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log "Another build process is running (PID: $pid)"
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

log "=== Build check started ==="

# Check GitHub CLI authentication
if ! $GH auth status &> /dev/null; then
    log "Error: GitHub CLI is not authenticated. Run 'gh auth login'"
    exit 1
fi

# Get head commit of main branch
log "Checking head commit of main branch..."
MAIN_COMMIT=$($GH api "repos/${REPO_NAME}/commits/main" --jq '.sha')
log "Head of main: $MAIN_COMMIT"

# Get commit of latest tag
log "Checking commit of latest tag..."
LATEST_TAG_REF=$($GH api "repos/${REPO_NAME}/git/refs/tags/latest" 2>/dev/null || echo "")
LATEST_TAG_COMMIT=""

if echo "$LATEST_TAG_REF" | $JQ -e '.object.sha' &>/dev/null; then
    LATEST_TAG_COMMIT=$(echo "$LATEST_TAG_REF" | $JQ -r '.object.sha')
    # For lightweight tags, it points directly to commit; for annotated tags, go through tag object
    TAG_OBJ=$($GH api "repos/${REPO_NAME}/git/tags/${LATEST_TAG_COMMIT}" 2>/dev/null || echo "")
    if echo "$TAG_OBJ" | $JQ -e '.object.sha' &>/dev/null; then
        LATEST_TAG_COMMIT=$(echo "$TAG_OBJ" | $JQ -r '.object.sha')
    fi
    log "Latest tag: $LATEST_TAG_COMMIT"
else
    log "Latest tag: does not exist"
fi

# Compare
if [ "$MAIN_COMMIT" = "$LATEST_TAG_COMMIT" ]; then
    log "Latest tag is at head of main. No updates."
    log "=== Build check finished ==="
    exit 0
fi

log "Updates detected. Starting build..."

# Create temp directory
WORK_DIR=$($MKTEMP -d)
log "Created temp directory: $WORK_DIR"

# Clone repository
log "Cloning repository..."
$GH repo clone "$REPO_NAME" "$WORK_DIR/repo" -- --depth 1
chmod -R 777 "$WORK_DIR/repo"
cd "$WORK_DIR/repo"

# Run build
log "Running build command..."
eval "$BUILD_COMMAND"

# Check release asset
ASSET_FILE="$WORK_DIR/repo/$RELEASE_ASSET"
if [ ! -f "$ASSET_FILE" ]; then
    log "Error: Release asset was not generated: $RELEASE_ASSET"
    exit 1
fi

log "Build completed: $ASSET_FILE"

# Update latest tag
log "Updating latest tag..."
SHORT_COMMIT=$($GIT rev-parse --short HEAD)
FULL_COMMIT=$($GIT rev-parse HEAD)
TIMESTAMP=$($DATE --iso-8601=seconds)

# Delete existing latest tag (via GitHub API)
if [ -n "$LATEST_TAG_COMMIT" ]; then
    log "Deleting existing latest tag..."
    $GH api -X DELETE "repos/${REPO_NAME}/git/refs/tags/latest" 2>/dev/null || true
fi

# Delete existing latest release
log "Deleting existing latest release..."
$GH release delete latest --repo "$REPO_NAME" --yes 2>/dev/null || true

# Create new release (tag is created simultaneously)
log "Creating new release..."
$GH release create latest \
    --repo "$REPO_NAME" \
    --target "$FULL_COMMIT" \
    --title "Latest Build ($TIMESTAMP)" \
    --notes "${FULL_COMMIT}" \
    --prerelease \
    "$ASSET_FILE"

log "Release created: https://github.com/${REPO_NAME}/releases/tag/latest"
log "=== Build check finished ==="
