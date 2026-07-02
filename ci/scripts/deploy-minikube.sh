#!/usr/bin/env bash
# Deploy the healthcare stack to the local minikube cluster.
#
# Two modes:
#   1) Build images locally and load into minikube (no registry needed). Default.
#   2) Pull from Docker Hub (REGISTRY_PULL=true) — use when CI has pushed new tags.
#
# Usage:
#   ./deploy-minikube.sh                              # build + load + deploy
#   ./deploy-minikube.sh --tag 0fb854a                # specific tag
#   REGISTRY_PULL=true ./deploy-minikube.sh --tag latest
#
# Env:
#   NAMESPACE    target namespace          (default: healthcare)
#   RELEASE      helm release name         (default: healthcare)
#   NAMESPACE_PROFILE  minikube profile name (default: minikube)
set -euo pipefail

NAMESPACE="${NAMESPACE:-healthcare}"
RELEASE="${RELEASE:-healthcare}"
PROFILE="${MINIKUBE_PROFILE:-minikube}"
REGISTRY_NS="${REGISTRY_NS:-anshul9589}"   # docker hub username/org
PREFIX="${PREFIX:-shsm-}"

TAG=""
SERVICES_ARG=""
REGISTRY_PULL="${REGISTRY_PULL:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)     TAG="$2"; shift 2 ;;
    --service) SERVICES_ARG="$2"; shift 2 ;;
    *) echo "unknown flag: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo dev)}"

# ────────────────────────────────────────────────────────────────
# 1. Verify minikube is up
# ────────────────────────────────────────────────────────────────
if ! minikube -p "${PROFILE}" status >/dev/null 2>&1; then
  echo "==> starting minikube profile '${PROFILE}'"
  minikube -p "${PROFILE}" start \
    --cpus 4 --memory 8192 \
    --addons ingress,metrics-server
fi
kubectl config use-context "${PROFILE}"

# ────────────────────────────────────────────────────────────────
# 2. Acquire images
# ────────────────────────────────────────────────────────────────
SERVICES=(
  gateway-service:gateway-service
  auth-service:auth-service
  doctor-service:doctor-service
  patient-service:patient-service
  appointment-service:appointment-service
  notification-service:notification-service
  admin-service:admin-service
  ui-service:ui-component
)

if [[ "${REGISTRY_PULL}" == "true" ]]; then
  echo "==> pulling images from registry (tag=${TAG})"
  for entry in "${SERVICES[@]}"; do
    name="${entry%%:*}"
    image="${REGISTRY_NS}/${PREFIX}${name}:${TAG}"
    [[ -n "${SERVICES_ARG}" && "${SERVICES_ARG}" != "${name}" ]] && continue
    docker pull "${image}"
    minikube -p "${PROFILE}" image load "${image}"
  done
else
  echo "==> building images locally and loading into minikube (tag=${TAG})"
  for entry in "${SERVICES[@]}"; do
    name="${entry%%:*}"
    ctx="${entry##*:}"
    [[ -n "${SERVICES_ARG}" && "${SERVICES_ARG}" != "${name}" ]] && continue
    image="${REGISTRY_NS}/${PREFIX}${name}:${TAG}"
    echo ">>> docker build ${image}  (context: ${ctx})"
    docker build --platform linux/amd64 -t "${image}" "./${ctx}"
    echo ">>> minikube image load ${image}"
    minikube -p "${PROFILE}" image load "${image}"
  done
fi

# ────────────────────────────────────────────────────────────────
# 3. Helm upgrade --install
# ────────────────────────────────────────────────────────────────
echo "==> helm upgrade --install ${RELEASE}"
helm upgrade --install "${RELEASE}" ./helm/healthcare \
  -n "${NAMESPACE}" --create-namespace \
  -f ./helm/healthcare/values.yaml \
  -f ./helm/healthcare/values-minikube.yaml \
  --set image.tag="${TAG}" \
  --set image.repository="${REGISTRY_NS}" \
  --set ui.tag="${TAG}" \
  --atomic --timeout 5m --wait

# ────────────────────────────────────────────────────────────────
# 4. Show what landed + how to reach it
# ────────────────────────────────────────────────────────────────
echo
echo "==> deployed pods:"
kubectl -n "${NAMESPACE}" get pods

INGRESS_IP=$(minikube -p "${PROFILE}" ip)
HOST="$(grep -E '^\s*host:' helm/healthcare/values-minikube.yaml | awk '{print $2}' | head -1)"
HOST="${HOST:-healthcare.local}"

cat <<EOF

============================================================
Deployed.
  Profile:   ${PROFILE}
  Tag:       ${TAG}
  Namespace: ${NAMESPACE}

Reach the app:
  echo "${INGRESS_IP} ${HOST}" | sudo tee -a /etc/hosts    # one-time
  open http://${HOST}                                       # browser

Or skip the hosts hack with port-forward:
  kubectl -n ${NAMESPACE} port-forward svc/gateway-service 8080:8080
  curl http://localhost:8080/actuator/health
============================================================
EOF
