#!/bin/bash
set -e
dockerd --storage-driver=fuse-overlayfs &
until docker info >/dev/null 2>&1; do sleep 1; done
exec "$@"
