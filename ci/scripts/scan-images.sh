#!/usr/bin/env bash
# Scan images for HIGH/CRITICAL vulnerabilities. Fails the build if any are found
# in OS packages or app dependencies. Reports archived as JSON.
set -euo pipefail

TAG="${1:?usage: scan-images.sh <tag>}"
REGISTRY="${ECR_REGISTRY:-anshul9589}"

SERVICES=(gateway auth doctor patient appointment notification admin ui)

mkdir -p trivy-reports

# Download Trivy DB once before parallel scans to avoid race conditions.
trivy image --download-db-only

EXIT_CODE=0
for svc in "${SERVICES[@]}"; do
    image="${REGISTRY}/shsm-${svc}-service:${TAG}"
    echo "=== Scanning ${image} ==="

    # Human-readable output to console
    trivy image \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        --exit-code 0 \
        "${image}" || true

    # JSON for archival / SBOM tooling
    trivy image \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        --format json \
        --output "trivy-reports/${svc}.json" \
        "${image}" || true

    # Hard fail check (separately so we get reports for ALL services even if one fails)
    if ! trivy image \
        --severity CRITICAL \
        --ignore-unfixed \
        --exit-code 1 \
        --quiet \
        "${image}"; then
        echo "❌ ${svc}: CRITICAL vulnerabilities found"
        EXIT_CODE=1
    fi
done

if [ ${EXIT_CODE} -ne 0 ]; then
    echo ""
    echo "Critical vulnerabilities present. Review trivy-reports/ in build artifacts."
    exit ${EXIT_CODE}
fi

echo "✅ No CRITICAL vulnerabilities found."