#!/usr/bin/env bash
# Adds Prometheus scrape annotations to all Spring Boot deployments in the
# `healthcare` namespace so the kubernetes-pods scrape job picks them up.
#
# Usage: ./apply-scrape-annotations.sh
set -euo pipefail

NAMESPACE="${NAMESPACE:-healthcare}"
SERVICES=(
  gateway-service
  auth-service
  doctor-service
  patient-service
  appointment-service
  notification-service
  admin-service
)

for svc in "${SERVICES[@]}"; do
  echo "annotating $svc"
  kubectl -n "$NAMESPACE" patch deployment "$svc" \
    --type=merge \
    -p '{"spec":{"template":{"metadata":{"annotations":{
          "prometheus.io/scrape":"true",
          "prometheus.io/path":"/actuator/prometheus",
          "prometheus.io/port":"8080"
        }}}}}'
done
