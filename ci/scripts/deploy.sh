#!/usr/bin/env bash
# Deploy the Helm chart to EKS with the given image tag.
set -euo pipefail

ENVIRONMENT="${1:?usage: deploy.sh <env> <tag>}"
TAG="${2:?usage: deploy.sh <env> <tag>}"

CHART_DIR="helm/healthcare"
RELEASE="${HELM_RELEASE:-healthcare}"
NAMESPACE="${HELM_NAMESPACE:-healthcare}"
VALUES_FILE="${CHART_DIR}/values-${ENVIRONMENT}.yaml"

if [ ! -f "${VALUES_FILE}" ]; then
    echo "❌ Values file not found: ${VALUES_FILE}"
    exit 1
fi

# Inject the image registry if provided (the dev/staging values files ship an
# empty image.repository, expecting CI to set it). Without this the image
# renders as "/shsm-<svc>:<tag>" → InvalidImageName.
REGISTRY_ARG=()
if [ -n "${ECR_REGISTRY:-}" ]; then
    REGISTRY_ARG=(--set image.repository="${ECR_REGISTRY}")
fi

echo "=== Deploying ${RELEASE} to ${ENVIRONMENT} with image tag ${TAG}${ECR_REGISTRY:+ from ${ECR_REGISTRY}} ==="
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${VALUES_FILE}" \
    "${REGISTRY_ARG[@]}" \
    --set image.tag="${TAG}" \
    --set ui.tag="${TAG}" \
    --rollback-on-failure \
    --timeout 5m \
    --history-max 10 \
    --wait

echo ""
echo "=== Rollout status ==="
kubectl get pods -n "${NAMESPACE}"
helm status "${RELEASE}" -n "${NAMESPACE}"
helm history "${RELEASE}" -n "${NAMESPACE}"
