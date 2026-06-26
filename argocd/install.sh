#!/usr/bin/env bash
# Installs ArgoCD into the cluster, exposes it locally, and bootstraps
# the smart-healthcare-system via the "app-of-apps" pattern.
#
# Usage:
#   ./install.sh
set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"   # or pin: v2.12.4
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> 1/5  create namespace"
kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 \
  || kubectl create namespace "${ARGOCD_NAMESPACE}"

echo "==> 2/5  install ArgoCD ${ARGOCD_VERSION}"
kubectl apply -n "${ARGOCD_NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "==> 3/5  wait for the argocd-server pod to be ready (up to 5 min)"
kubectl -n "${ARGOCD_NAMESPACE}" wait deploy/argocd-server \
  --for=condition=Available --timeout=300s

echo "==> 4/5  bootstrap projects + root Application"
# Apply the AppProject first, otherwise the Applications referencing it will
# fail validation. The root app then takes over reconciliation.
kubectl apply -f "${REPO_ROOT}/argocd/projects/healthcare-project.yaml"
kubectl apply -f "${REPO_ROOT}/argocd/applications/root-app.yaml"

echo "==> 5/5  initial admin password (change immediately):"
ADMIN_PW=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
echo "    user:     admin"
echo "    password: ${ADMIN_PW:-<not generated yet — re-run in a minute>}"

cat <<EOF

============================================================
ArgoCD is up. Open the UI:
    kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8081:443
    https://localhost:8081   (accept self-signed cert)

Then watch sync state:
    kubectl -n ${ARGOCD_NAMESPACE} get applications
    argocd app list                  # if you've installed the argocd CLI

The root app should appear, sync, and create:
    - healthcare-app    → applies k8s/
    - monitoring-app    → applies monitoring/k8s/
============================================================
EOF
