#!/usr/bin/env bash
# Build all service images with the given tag. Uses docker buildx for layer caching.
set -euo pipefail

TAG="${1:?usage: build-images.sh <tag>}"
REGISTRY="${ECR_REGISTRY:-anshul9589}"

SERVICES=(gateway auth doctor patient appointment notification admin)

# Use buildx with inline cache so subsequent builds reuse layers.
docker buildx create --use --name healthcare-builder 2>/dev/null || \
    docker buildx use healthcare-builder

build_service() {
    local svc="$1"
    local context="$2"
    local image_name="$3"

    echo "=== Building ${image_name}:${TAG} ==="
    docker buildx build \
        --platform linux/amd64 \
        --tag "${image_name}:${TAG}" \
        --tag "${image_name}:latest" \
        --cache-from "type=registry,ref=${image_name}:cache" \
        --cache-to "type=inline" \
        --push \
        "${context}"
}

for svc in "${SERVICES[@]}"; do
    build_service "${svc}-service" "../../${svc}-service" "${REGISTRY}/shsm-${svc}-service"
done

build_service "ui-service" "../../ui-component" "${REGISTRY}/shsm-ui-service"

echo "=== All images built with tag ${TAG} ==="