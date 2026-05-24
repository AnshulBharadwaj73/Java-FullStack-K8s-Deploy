# healthcare Helm chart

Templated version of the manifests in [k8s/](../../k8s/). One chart, two values files (minikube / EKS), one templated Spring Boot deployment that handles all 7 services.

## Files

| Path | Purpose |
|---|---|
| [Chart.yaml](Chart.yaml) | Chart metadata |
| [values.yaml](values.yaml) | Default values (matches the `k8s/` setup) |
| [values-minikube.yaml](values-minikube.yaml) | Minikube-specific overrides |
| [values-eks.yaml](values-eks.yaml) | EKS-specific overrides (ECR, ALB, gp3) |
| [templates/](templates/) | Resource templates |

## What it deploys

24 resources total: 1 Namespace, 1 ConfigMap, 1 Secret, 1 PVC, 10 Deployments (Mongo + Kafka + 7 Spring Boot + UI), 10 Services, 1 Ingress.

## Install on minikube

```bash
# 1. Build images into minikube's daemon (Helm doesn't build, only deploys)
eval $(minikube docker-env)
for svc in gateway auth doctor patient appointment notification admin; do
  docker build -t anshul9589/shsm-${svc}-service:1.0 ./${svc}-service
done
docker build -t anshul9589/shsm-ui-service:1.0 ./ui-component

# 2. Install the chart
helm install healthcare helm/healthcare -f helm/healthcare/values-minikube.yaml

# 3. Watch rollout
kubectl get pods -n healthcare -w
```

## Install on EKS

```bash
# 1. Push images to ECR (replace 123456789012)
aws ecr get-login-password | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# 2. Edit values-eks.yaml with your account ID, domain, ACM ARN

# 3. Install
helm install healthcare helm/healthcare -f helm/healthcare/values-eks.yaml
```

## Common operations

```bash
# Render templates without applying (dry-run)
helm template healthcare helm/healthcare -f helm/healthcare/values-minikube.yaml

# Lint
helm lint helm/healthcare

# Upgrade after image rebuild — bump tag in values, then:
helm upgrade healthcare helm/healthcare -f helm/healthcare/values-minikube.yaml

# Roll back
helm history healthcare
helm rollback healthcare 1

# Uninstall everything
helm uninstall healthcare
kubectl delete namespace healthcare
```

## How to add a new Spring Boot service

Append one entry to `services:` in [values.yaml](values.yaml):

```yaml
services:
  # ...existing...
  - name: billing-service
    image: shsm-billing-service
    configKeys: [SPRING_PROFILES_ACTIVE]
    secretKeys: [MONGO_URI]
```

`helm upgrade` and you're done. No new template file, no copy-paste YAML.

## Override a single value at install time

```bash
helm install healthcare helm/healthcare \
  -f helm/healthcare/values-minikube.yaml \
  --set image.tag=1.1 \
  --set kafka.replicas=1
```

## Production secrets

Don't commit real secrets to `values.yaml`. Two common patterns:

1. **`--set` at deploy time** from CI/CD (values come from a secrets manager).
2. **External Secrets Operator** — secrets in AWS Secrets Manager / HashiCorp Vault, synced into K8s `Secret` objects automatically. Drop the `secret:` block from values and let ESO populate `app-secret`.