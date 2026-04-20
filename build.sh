#!/usr/bin/env bash
# Build and push the pss-assembly-viewer image to ghcr.io.
# Sources build-time env from the canonical ../platform-portal/.env so
# secrets live in one place.
#
# Usage:
#   ./build.sh           # build, push :latest and :<git-sha>
#   ./build.sh --local   # build for the local platform (no push) — dev only

set -euo pipefail

REGISTRY="ghcr.io/ukstevem/pss-assembly-viewer"
PLATFORM="linux/arm64"
SHARED_ENV="../platform-portal/.env"

if [ ! -f "$SHARED_ENV" ]; then
  echo "Error: $SHARED_ENV not found."
  echo "Ensure platform-portal is a sibling of this repo (shared .env lives there)."
  exit 1
fi

# Source shared env for build args
set -a
# shellcheck disable=SC1090
source "$SHARED_ENV"
set +a

SHA="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"

docker buildx inspect multiarch >/dev/null 2>&1 || \
  docker buildx create --name multiarch --use
docker buildx use multiarch

COMMON_ARGS=(
  --build-arg NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
  --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-}"
  --build-arg NEXT_PUBLIC_DOC_GATEWAY_BASE_URL="${NEXT_PUBLIC_DOC_GATEWAY_BASE_URL:-}"
  --build-arg NEXT_PUBLIC_APP_URL="${NEXT_PUBLIC_APP_URL:-}"
  --build-arg NEXT_PUBLIC_DOC_SERVICE_URL="${NEXT_PUBLIC_DOC_SERVICE_URL:-}"
)

if [ "${1:-}" = "--local" ]; then
  echo "=== Building locally (no push) ==="
  docker build \
    "${COMMON_ARGS[@]}" \
    -t "$REGISTRY:dev" \
    ./app
  echo "Built: $REGISTRY:dev"
  exit 0
fi

echo "=== Building $PLATFORM image and pushing to $REGISTRY ==="
docker buildx build \
  --platform "$PLATFORM" \
  "${COMMON_ARGS[@]}" \
  -t "$REGISTRY:$SHA" \
  -t "$REGISTRY:latest" \
  --push \
  ./app

echo ""
echo "Pushed: $REGISTRY:$SHA and $REGISTRY:latest"
echo "Rollback tip: edit docker-compose.app.yml image line to pin :$SHA"
