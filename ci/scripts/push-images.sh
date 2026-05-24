#!/usr/bin/env bash
# Push all service images to ECR. Assumes AWS credentials are exported.
set -euo pipefail

TAG="${1:?usage: push-images.sh <tag>}"
REGISTRY="${ECR_REGISTRY:?ECR_REGISTRY must be set}"
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-${REGISTRY}}"
AWS_REGION="${AWS_REGION:-us-east-1}"

SERVICES=(gateway auth doctor patient appointment notification admin ui)

# Login to ECR
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${REGISTRY}"

# Ensure repos exist (idempotent)
for svc in "${SERVICES[@]}"; do
    aws ecr describe-repositories --repository-names "shsm-${svc}-service" --region "${AWS_REGION}" 2>/dev/null || \
        aws ecr create-repository \
            --repository-name "shsm-${svc}-service" \
            --image-scanning-configuration scanOnPush=true \
            --region "${AWS_REGION}"
done

for svc in "${SERVICES[@]}"; do
    src="${SOURCE_NAMESPACE}/shsm-${svc}-service:${TAG}"
    dest="${REGISTRY}/shsm-${svc}-service"
    echo "=== Retagging ${src} → ${dest}:${TAG} ==="
    docker tag "${src}" "${dest}:${TAG}"
    docker tag "${src}" "${dest}:latest"
    docker push "${dest}:${TAG}"
    docker push "${dest}:latest"
done

echo "✅ All images pushed."