#!/usr/bin/env bash
# SonarQube / SonarCloud scanner. Handles both Java (Maven) and Node services.
#
# Usage:
#   ./sonar-scan.sh <service-name>          # scan one service
#   ./sonar-scan.sh all                     # scan every service in sequence
#
# Env vars (required):
#   SONAR_HOST_URL   e.g. https://sonarcloud.io  OR  http://localhost:9000
#   SONAR_TOKEN      auth token from Sonar UI -> My Account -> Security
#
# Env vars (optional):
#   SONAR_ORG        SonarCloud organisation key (only for SonarCloud, not self-hosted)
#   SONAR_QUALITY_GATE_WAIT   true|false   default: true (fails build on QG failure)
#   SKIP_TESTS       true|false             default: false
#
# Examples:
#   SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=xxx ./sonar-scan.sh auth-service
#   SONAR_HOST_URL=https://sonarcloud.io SONAR_TOKEN=xxx SONAR_ORG=myorg ./sonar-scan.sh all

set -euo pipefail

SERVICE="${1:?usage: sonar-scan.sh <service-name|all>}"

: "${SONAR_HOST_URL:?SONAR_HOST_URL is required}"
: "${SONAR_TOKEN:?SONAR_TOKEN is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

QG_WAIT="${SONAR_QUALITY_GATE_WAIT:-true}"
SKIP_TESTS="${SKIP_TESTS:-false}"
ORG_ARG=()
[[ -n "${SONAR_ORG:-}" ]] && ORG_ARG=("-Dsonar.organization=${SONAR_ORG}")

# ───────────────────────────────────────────────────────────────
# Per-service definitions
# ───────────────────────────────────────────────────────────────
JAVA_SERVICES=(
  gateway-service
  auth-service
  doctor-service
  patient-service
  appointment-service
  notification-service
  admin-service
)
NODE_SERVICES=(ui-service)

is_java() {
  for s in "${JAVA_SERVICES[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}
is_node() {
  for s in "${NODE_SERVICES[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

# ───────────────────────────────────────────────────────────────
# Scan one Java service via Maven plugin (jacoco + sonar)
# ───────────────────────────────────────────────────────────────
scan_java() {
  local svc="$1"
  local dir="${svc}"
  local project_key="shsm:${svc}"

  echo
  echo "============================================================"
  echo "  Sonar (Maven): ${svc}"
  echo "============================================================"

  local TEST_FLAG=""
  [[ "${SKIP_TESTS}" == "true" ]] && TEST_FLAG="-DskipTests"

  # Order matters:
  #   prepare-agent → attaches the JaCoCo Java agent so surefire-run tests are instrumented
  #   verify        → compiles + runs tests
  #   report        → reads exec data, writes jacoco.xml
  #   sonar:sonar   → uploads source + coverage report to SonarQube
  (cd "${dir}" && mvn -B -ntp \
      clean \
      org.jacoco:jacoco-maven-plugin:0.8.12:prepare-agent \
      verify ${TEST_FLAG} \
      org.jacoco:jacoco-maven-plugin:0.8.12:report \
      sonar:sonar \
      -Dsonar.host.url="${SONAR_HOST_URL}" \
      -Dsonar.token="${SONAR_TOKEN}" \
      -Dsonar.projectKey="${project_key}" \
      -Dsonar.projectName="${svc}" \
      -Dsonar.qualitygate.wait="${QG_WAIT}" \
      -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
      "${ORG_ARG[@]}")
}

# ───────────────────────────────────────────────────────────────
# Scan UI via sonar-scanner CLI
# ───────────────────────────────────────────────────────────────
scan_node() {
  local svc="ui-service"
  local dir="ui-component"

  echo
  echo "============================================================"
  echo "  Sonar (Node):  ${svc}"
  echo "============================================================"

  # Run lint + tests + coverage so Sonar has data to report
  (cd "${dir}"
    npm ci
    npm run lint --if-present || true
    if [[ "${SKIP_TESTS}" != "true" ]]; then
      npm test --if-present -- --coverage --watchAll=false || true
    fi)

  # sonar-scanner reads ui-component/sonar-project.properties
  docker run --rm \
    --network=host \
    -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
    -e SONAR_TOKEN="${SONAR_TOKEN}" \
    -v "${REPO_ROOT}/${dir}:/usr/src" \
    sonarsource/sonar-scanner-cli:5.0 \
    -Dsonar.qualitygate.wait="${QG_WAIT}" \
    "${ORG_ARG[@]}"
}

# ───────────────────────────────────────────────────────────────
# Dispatch
# ───────────────────────────────────────────────────────────────
if [[ "${SERVICE}" == "all" ]]; then
  for s in "${JAVA_SERVICES[@]}"; do scan_java "$s"; done
  for s in "${NODE_SERVICES[@]}"; do scan_node;     done
elif is_java "${SERVICE}"; then
  scan_java "${SERVICE}"
elif is_node "${SERVICE}"; then
  scan_node
else
  echo "Unknown service: ${SERVICE}"
  echo "Known: ${JAVA_SERVICES[*]} ${NODE_SERVICES[*]} all"
  exit 1
fi

echo
echo "============================================================"
echo "  Sonar scan complete."
echo "  View results: ${SONAR_HOST_URL}/projects"
echo "============================================================"
