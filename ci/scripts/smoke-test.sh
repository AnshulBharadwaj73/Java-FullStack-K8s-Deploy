#!/usr/bin/env bash
# Hit the deployed services through the ingress and verify they respond. Fails
# the build if any critical endpoint returns 5xx.
set -euo pipefail

ENVIRONMENT="${1:?usage: smoke-test.sh <env>}"
NAMESPACE="${HELM_NAMESPACE:-healthcare}"

# Resolve the ingress hostname from the deployed Ingress (works across envs).
INGRESS_HOST=$(kubectl get ingress -n "${NAMESPACE}" -o jsonpath='{.items[0].spec.rules[0].host}')
SCHEME="${SMOKE_SCHEME:-https}"
[ "${ENVIRONMENT}" = "dev" ] && SCHEME="http"
BASE_URL="${SCHEME}://${INGRESS_HOST}"

echo "=== Smoke test against ${BASE_URL} ==="

check() {
    local name="$1"
    local url="$2"
    local expected="$3"

    local code
    code=$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 10 "${url}")
    if [ "${code}" = "${expected}" ] || [ "${expected}" = "any-2xx-3xx-4xx" -a "${code}" -lt "500" ]; then
        echo "✅ ${name}: ${code}"
    else
        echo "❌ ${name}: ${code} (expected ${expected})"
        return 1
    fi
}

# UI homepage
check "UI homepage" "${BASE_URL}/" 200

# Gateway routing — POST /api/auth/signin should return 401 (no creds) or 400 (bad payload), not 5xx
SIGNIN_CODE=$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -X POST "${BASE_URL}/api/auth/signin" \
    -H "Content-Type: application/json" \
    -d '{"username":"smoketest","password":"x"}')
if [ "${SIGNIN_CODE}" -ge "500" ]; then
    echo "❌ Gateway → auth-service: ${SIGNIN_CODE}"
    exit 1
fi
echo "✅ Gateway → auth-service: ${SIGNIN_CODE}"

# Pod health: every deployment must have at least one Ready replica
NOT_READY=$(kubectl get deploy -n "${NAMESPACE}" -o json | \
    jq -r '.items[] | select(.status.readyReplicas < 1) | .metadata.name')
if [ -n "${NOT_READY}" ]; then
    echo "❌ Deployments not ready: ${NOT_READY}"
    kubectl get pods -n "${NAMESPACE}"
    exit 1
fi
echo "✅ All deployments Ready"

echo ""
echo "✅ Smoke test passed."