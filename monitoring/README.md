# Monitoring Stack — Prometheus, Alertmanager, Grafana, PagerDuty

End-to-end observability for the smart-healthcare-system microservices.

```
Spring Boot services  ──/actuator/prometheus──▶  Prometheus  ──▶  Alertmanager  ──▶  PagerDuty
                                                     │
                                                     ▼
                                                  Grafana
```

## What's in here

```
monitoring/
├── prometheus/
│   ├── prometheus.yml              # scrape config (compose targets)
│   └── rules/healthcare-alerts.yml # alert rules (SLO, JVM, infra)
├── alertmanager/
│   ├── alertmanager.yml            # PagerDuty routing (default/critical/warning)
│   └── templates/pagerduty.tmpl
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/datasource.yml
│   │   └── dashboards/dashboards.yml
│   └── dashboards/healthcare-overview.json
├── docker-compose.monitoring.yml   # local stack (compose)
├── k8s/                            # raw kubernetes manifests
│   ├── 00-namespace.yaml
│   ├── 01-prometheus-rbac.yaml
│   ├── 02-prometheus-config.yaml
│   ├── 03-prometheus-rules.yaml
│   ├── 04-prometheus.yaml
│   ├── 05-alertmanager.yaml
│   ├── 06-grafana.yaml
│   └── apply-scrape-annotations.sh
└── helm/                           # kube-prometheus-stack option
    ├── kube-prometheus-stack-values.yaml
    └── servicemonitors.yaml
```

## Prerequisite — Spring Boot side

Already wired up:

- `spring-boot-starter-actuator` and `micrometer-registry-prometheus` are dependencies of every service (`*/pom.xml`).
- `management.endpoints.web.exposure.include: "*"` in each `application.yml` exposes `/actuator/prometheus`.

After pulling these changes, rebuild the service images so the new dependency is in the jars:

```bash
mvn -f auth-service/pom.xml clean package -DskipTests
# ... or, for all services in one shot:
for s in auth-service gateway-service doctor-service patient-service \
         appointment-service notification-service admin-service; do
  mvn -f "$s/pom.xml" clean package -DskipTests
done
```

Verify a service is exporting metrics:

```bash
curl -s http://localhost:8080/actuator/prometheus | head
```

---

## Option A — Run locally with Docker Compose

1. Start the application stack:

   ```bash
   docker compose up -d --build
   ```

2. Set PagerDuty routing keys (Events API v2 integration keys). Skip if you just
   want Prometheus + Grafana without paging:

   ```bash
   export PAGERDUTY_ROUTING_KEY=<your-default-key>
   export PAGERDUTY_ROUTING_KEY_CRITICAL=<your-critical-key>
   export PAGERDUTY_ROUTING_KEY_WARNING=<your-warning-key>
   export GRAFANA_ADMIN_PASSWORD=<choose-one>
   ```

3. Start the monitoring stack on the same docker network:

   ```bash
   docker compose \
     -f docker-compose.yml \
     -f monitoring/docker-compose.monitoring.yml \
     up -d
   ```

4. Open the UIs:
   - Prometheus → http://localhost:9091
   - Alertmanager → http://localhost:9093
   - Grafana → http://localhost:3000 (admin / `$GRAFANA_ADMIN_PASSWORD`)
   - cAdvisor → http://localhost:8081
   - node-exporter metrics → http://localhost:9100/metrics

5. Sanity-check scrape targets:

   ```
   http://localhost:9091/targets   # all spring-boot jobs should be UP
   http://localhost:9091/alerts    # rules should be loaded
   ```

6. Tear down:

   ```bash
   docker compose -f docker-compose.yml -f monitoring/docker-compose.monitoring.yml down
   ```

> **Network note** — the monitoring compose file expects the network created by
> the main compose project (`smart-healthcare-system-main_app-network`). If your
> compose project name differs, edit the `networks.app-network.name` field at
> the bottom of `monitoring/docker-compose.monitoring.yml`, or run both files
> together (as shown above) so Compose creates a single shared network.

---

## Option B — Run on Kubernetes (raw manifests)

For minikube / kind / any cluster, without the Prometheus Operator:

1. Create the namespace + stack:

   ```bash
   kubectl apply -f monitoring/k8s/
   ```

2. Replace the placeholder PagerDuty keys with real ones:

   ```bash
   kubectl -n monitoring create secret generic pagerduty-routing-keys \
     --from-literal=default=$PAGERDUTY_ROUTING_KEY \
     --from-literal=critical=$PAGERDUTY_ROUTING_KEY_CRITICAL \
     --from-literal=warning=$PAGERDUTY_ROUTING_KEY_WARNING \
     --dry-run=client -o yaml | kubectl apply -f -

   kubectl -n monitoring rollout restart deployment/alertmanager
   ```

3. Tell Prometheus which pods to scrape (adds annotations to each Spring Boot
   Deployment in the `healthcare` namespace):

   ```bash
   ./monitoring/k8s/apply-scrape-annotations.sh
   ```

4. Port-forward the UIs:

   ```bash
   kubectl -n monitoring port-forward svc/prometheus   9090:9090 &
   kubectl -n monitoring port-forward svc/alertmanager 9093:9093 &
   kubectl -n monitoring port-forward svc/grafana      3000:3000 &
   ```

   Then open http://localhost:9090, http://localhost:9093, http://localhost:3000.

5. Verify scrape: http://localhost:9090/targets — `kubernetes-pods` job
   should list all seven services as `UP`.

---

## Option C — Kubernetes via kube-prometheus-stack (recommended for prod)

This installs the full Prometheus Operator (Prometheus, Alertmanager, Grafana,
node-exporter, kube-state-metrics) using upstream charts.

1. Install the chart:

   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update

   helm upgrade --install kps prometheus-community/kube-prometheus-stack \
     -n monitoring --create-namespace \
     -f monitoring/helm/kube-prometheus-stack-values.yaml
   ```

2. Edit `monitoring/helm/kube-prometheus-stack-values.yaml` and replace the
   `REPLACE_ME*` PagerDuty routing keys (or supply them via `--set` /
   `--set-file` / a sealed secret).

3. Apply the ServiceMonitors + PrometheusRule so the operator knows to scrape
   the healthcare services:

   ```bash
   kubectl apply -f monitoring/helm/servicemonitors.yaml
   ```

4. Open Grafana:

   ```bash
   kubectl -n monitoring port-forward svc/kps-grafana 3000:80
   # user: admin   password: from values file
   ```

5. Open Prometheus & Alertmanager:

   ```bash
   kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
   kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093:9093
   ```

---

## PagerDuty setup (one-time)

1. In PagerDuty: **Services → New Service → Integrations → Events API v2**.
   Create three integrations (or three services) for `default`, `critical`,
   `warning`. Copy the **Integration Key** for each.
2. Either export those as the env vars shown above (compose), drop them into
   the `pagerduty-routing-keys` secret (k8s raw manifests), or set them via
   `--set` on `helm upgrade` (kube-prometheus-stack).
3. Trigger a test page by stopping a service container:

   ```bash
   docker stop auth-service           # compose
   kubectl -n healthcare scale deploy auth-service --replicas=0   # k8s
   ```

   `ServiceDown` will fire after 2 minutes and you should receive a PagerDuty
   incident. Restart the service to resolve.

---

## Bundled alerts

| Alert | Severity | Trigger |
| --- | --- | --- |
| `ServiceDown` | critical | Pod unreachable for 2m |
| `KubePodCrashLooping` | warning | >3 restarts in 10m |
| `HighHttpErrorRate` | critical | 5xx > 5% for 5m |
| `HighHttpLatencyP95` | warning | p95 > 1s for 10m |
| `JvmHeapPressure` | warning | heap > 85% for 10m |
| `HighGcPauseTime` | warning | GC > 500ms/s for 10m |
| `NodeHighCpu` | warning | node CPU > 85% for 10m |
| `NodeHighMemory` | warning | node mem > 90% for 10m |
| `NodeDiskFillingUp` | warning | fs > 85% for 10m |

Edit `monitoring/prometheus/rules/healthcare-alerts.yml` (compose), the
`prometheus-rules` ConfigMap (raw k8s), or `monitoring/helm/servicemonitors.yaml`
(kube-prometheus-stack) to tune thresholds.

---

## Grafana dashboards

`monitoring/grafana/dashboards/healthcare-overview.json` is auto-provisioned
into the **Healthcare** folder. It shows services up, RPS, error rate, p95
latency, JVM heap, and GC pause time. Add more by dropping JSON files into the
same folder (compose) or by labelling a ConfigMap with `grafana_dashboard=1`
in the kube-prometheus-stack option.

Useful community dashboards to import (Grafana → + → Import → Dashboard ID):
- **4701** — JVM (Micrometer)
- **11378** — Spring Boot Statistics
- **1860**  — Node Exporter Full
- **14282** — cAdvisor
