#!/bin/bash
set -euo pipefail
# Build DevContainer images locally with versions from versions.env
# Usage: ./build-local.sh [infrastructure|backend|frontend|local]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_ENV="$DEVCONTAINER_DIR/versions.env"

# Load versions from versions.env
if [ ! -f "$VERSIONS_ENV" ]; then
  echo "Error: versions.env not found at $VERSIONS_ENV"
  exit 1
fi

# Parse versions.env into build args
BUILD_ARGS=""
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  [[ "$key" =~ ^#.*$ ]] && continue
  [[ -z "$key" ]] && continue

  BUILD_ARGS="$BUILD_ARGS --build-arg ${key}=${value}"
done < "$VERSIONS_ENV"

# Add non-version args
BUILD_ARGS="$BUILD_ARGS --build-arg TZ=${TZ:-UTC}"

# Determine which image to build
IMAGE_TYPE="${1:-local}"

case "$IMAGE_TYPE" in
  infrastructure|backend|frontend|local)
    DOCKERFILE="$DEVCONTAINER_DIR/dockerfiles/Dockerfile.${IMAGE_TYPE}"
    IMAGE_NAME="devcontainer-${IMAGE_TYPE}:local"
    ;;
  *)
    echo "Usage: $0 [infrastructure|backend|frontend|local]"
    echo "Default: local"
    exit 1
    ;;
esac

echo "Building ${IMAGE_NAME} from ${DOCKERFILE}"
echo "Using versions from: $VERSIONS_ENV"

# Build the image
docker build \
  -f "$DOCKERFILE" \
  -t "$IMAGE_NAME" \
  $BUILD_ARGS \
  "$DEVCONTAINER_DIR"

echo ""
echo "✅ Build complete: ${IMAGE_NAME}"
echo ""
echo "To run:"
echo "  docker run -it --rm ${IMAGE_NAME} /bin/bash"
