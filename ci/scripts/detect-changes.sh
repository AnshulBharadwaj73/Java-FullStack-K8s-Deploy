#!/usr/bin/env bash
# Print a comma-separated list of services whose code changed in this commit
# range. Empty output means "rebuild everything" (e.g., chart or CI changes).
set -euo pipefail

BASE_REF="${CHANGE_TARGET:-${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-HEAD~1}}"
HEAD_REF="${GIT_COMMIT:-HEAD}"

CHANGED_FILES=$(git diff --name-only "${BASE_REF}" "${HEAD_REF}" 2>/dev/null || git diff --name-only HEAD~1 HEAD)

# Force full rebuild if chart/CI/shared files changed
if echo "$CHANGED_FILES" | grep -qE '^(helm/|ci/|Jenkinsfile|docker-compose\.yml)'; then
    echo ""   # empty = build all
    exit 0
fi

CHANGED_SERVICES=()
for svc in gateway auth doctor patient appointment notification admin; do
    if echo "$CHANGED_FILES" | grep -q "^${svc}-service/"; then
        CHANGED_SERVICES+=("${svc}")
    fi
done
if echo "$CHANGED_FILES" | grep -q "^ui-component/"; then
    CHANGED_SERVICES+=("ui")
fi

(IFS=,; echo "${CHANGED_SERVICES[*]}")