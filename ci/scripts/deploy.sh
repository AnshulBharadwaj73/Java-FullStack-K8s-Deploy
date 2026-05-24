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

echo "=== Deploying ${RELEASE} to ${ENVIRONMENT} with image tag ${TAG} ==="

helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${VALUES_FILE}" \
    --set image.tag="${TAG}" \
    --set ui.tag="${TAG}" \
    --atomic \
    --timeout 15m \
    --history-max 10 \
    --wait

echo ""
echo "=== Rollout status ==="
kubectl get pods -n "${NAMESPACE}"
helm status "${RELEASE}" -n "${NAMESPACE}"
helm history "${RELEASE}" -n "${NAMESPACE}"