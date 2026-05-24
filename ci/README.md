# Jenkins CI/CD pipeline for EKS deployment

End-to-end pipeline: build → test → scan → push to ECR → deploy to EKS via Helm → smoke test. Multi-environment (dev / staging / prod) with prod approval gate and one-click rollback.

## Architecture

```
git push ──▶ Jenkins ──▶ Build (parallel) ──▶ Test ──▶ Trivy scan
                              │
                              ▼
                          Push to ECR
                              │
                              ▼
                    [prod] manual approval
                              │
                              ▼
                  helm upgrade --install --atomic
                              │
                              ▼
                         Smoke test
                              │
                              ▼
                    Slack notify success/fail
```

## Files

| Path | Purpose |
|---|---|
| [Jenkinsfile](../Jenkinsfile) | Declarative pipeline definition |
| [ci/scripts/detect-changes.sh](scripts/detect-changes.sh) | Identifies which services changed in this commit (skips unchanged builds) |
| [ci/scripts/build-images.sh](scripts/build-images.sh) | Builds all 8 Docker images with buildx + layer cache |
| [ci/scripts/scan-images.sh](scripts/scan-images.sh) | Trivy CRITICAL/HIGH vulnerability scan, fails on CRITICAL |
| [ci/scripts/push-images.sh](scripts/push-images.sh) | Logs in to ECR, creates repos if missing, pushes images |
| [ci/scripts/deploy.sh](scripts/deploy.sh) | `helm upgrade --install --atomic` to EKS |
| [ci/scripts/smoke-test.sh](scripts/smoke-test.sh) | Hits ingress endpoints + verifies all Deployments Ready |
| [helm/healthcare/values-dev.yaml](../helm/healthcare/values-dev.yaml) | Dev EKS overrides |
| [helm/healthcare/values-staging.yaml](../helm/healthcare/values-staging.yaml) | Staging EKS overrides |
| [helm/healthcare/values-prod.yaml](../helm/healthcare/values-prod.yaml) | Prod EKS overrides |

## Pipeline parameters

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `ENVIRONMENT` | choice | `dev` | `dev`, `staging`, or `prod`. Picks values file + EKS cluster. |
| `SKIP_TESTS` | bool | `false` | Skip `mvn test`. Emergency hotfix only. |
| `SKIP_SECURITY_SCAN` | bool | `false` | Skip Trivy. Use sparingly. |
| `ROLLBACK_REVISION` | string | `""` | Provide a Helm revision number (e.g., `5`) to roll back instead of deploy. |

## One-time Jenkins setup

### Required plugins

- AWS Steps (`aws-steps`)
- Credentials Binding (`credentials-binding`)
- Pipeline (`workflow-aggregator`)
- Slack Notification (optional)
- AnsiColor (`ansicolor`)
- Timestamper (`timestamper`)
- Multibranch Pipeline (recommended)

### Required Jenkins credentials

Add via *Manage Jenkins → Credentials*:

| Credential ID | Type | Contains |
|---|---|---|
| `aws-account-id` | Secret text | Your 12-digit AWS account ID (e.g., `123456789012`) |
| `aws-ecr-credentials` | AWS credentials | IAM user/role with `ecr:*` permission |
| `aws-eks-credentials` | AWS credentials | IAM user/role with `eks:DescribeCluster` and the cluster's `aws-auth` ConfigMap mapping |

### Required tools on Jenkins agent

```bash
# AWS CLI v2
aws --version

# kubectl (matching your EKS version)
kubectl version --client

# Helm v3
helm version

# Docker with buildx
docker buildx version

# Java 21 (for Spring Boot builds)
java -version

# Node 20 (for UI build)
node --version

# Maven 3.9+
mvn --version

# Trivy
trivy --version

# jq
jq --version
```

A Dockerfile-based agent (Kubernetes pod template) keeps these consistent across builds. Recommended.

### EKS access

For each environment, create the EKS cluster:
```bash
eksctl create cluster \
    --name healthcare-dev \
    --region us-east-1 \
    --node-type t3.large \
    --nodes 2
```

Then map the Jenkins IAM user/role into the cluster:
```bash
eksctl create iamidentitymapping \
    --cluster healthcare-dev \
    --region us-east-1 \
    --arn arn:aws:iam::<acct>:role/<jenkins-role> \
    --group system:masters \
    --username jenkins
```

(`system:masters` is fine for dev; restrict in prod with a custom RBAC ClusterRoleBinding.)

### Required EKS addons

Install once per cluster:

```bash
# AWS Load Balancer Controller (for ALB Ingress)
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system --set clusterName=healthcare-dev

# EBS CSI driver (for gp3 PVCs)
eksctl create addon --name aws-ebs-csi-driver --cluster healthcare-dev

# (Optional) External Secrets Operator for AWS Secrets Manager integration
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

## Image tagging strategy

```
${BRANCH_NAME}-${BUILD_NUMBER}-${GIT_SHORT_COMMIT}
```

Examples: `main-42-a3f9c1d`, `release-1.2-15-7b8e2a0`. Each build is uniquely traceable to a commit and immutable. The `:latest` tag is also pushed for the convenience of debugging but **never** referenced in deploys — production always pulls a specific tag.

## Branch strategy

| Branch | Builds | Deploys to |
|---|---|---|
| `feature/*` | yes — build + test + scan | nothing (PR check only) |
| `develop` / `main` | yes | dev, automatic |
| `release/*` | yes | staging, automatic |
| Tag `v*` | yes | prod, **manual approval required** |

Implement branch-specific defaults in the Jenkinsfile's `parameters` block, or set per-branch `ENVIRONMENT` defaults using a Multibranch Pipeline + scripted logic. The current Jenkinsfile lets the operator pick at trigger time — simplest for getting started.

## Deploying

### Normal deploy

In Jenkins UI: *Build with Parameters* → choose `ENVIRONMENT` → *Build*.

### Rollback

In Jenkins UI: *Build with Parameters* → set `ROLLBACK_REVISION` to the target revision (find with `helm history healthcare -n healthcare`) → *Build*. Skips all build/test stages and runs only `helm rollback`.

### Hotfix

In Jenkins UI: *Build with Parameters* → check `SKIP_TESTS` → *Build*. Use sparingly; the security scan still runs.

## Secrets management — production

The current chart's `secret:` block lets you ship JWT_SECRET, MONGO_URI, etc. via values. **Don't do that in prod.** Two recommended patterns:

### A. Inject at deploy time

Store secrets in AWS Secrets Manager. Add to [ci/scripts/deploy.sh](scripts/deploy.sh):

```bash
JWT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id healthcare/${ENVIRONMENT}/jwt-secret \
    --query SecretString --output text)

helm upgrade --install ... \
    --set secret.JWT_SECRET="${JWT_SECRET}" \
    --set secret.MONGO_URI="${MONGO_URI}"
```

### B. External Secrets Operator (recommended)

Install ESO once per cluster, then create an `ExternalSecret` resource that pulls from Secrets Manager. Drop the `secret:` block from `values.yaml`; ESO populates `app-secret` automatically. Rotation is automatic.

```yaml
# helm/healthcare/templates/external-secret.yaml (add this template)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets
  target:
    name: app-secret
  dataFrom:
    - extract:
        key: healthcare/{{ .Values.namespace }}/app-secret
```

## Industry-standard practices baked in

| Concern | Implementation |
|---|---|
| **Reproducibility** | Unique image tags per build, no mutable tags |
| **Idempotent deploys** | `helm upgrade --install` always works whether release exists or not |
| **Atomic rollouts** | `helm --atomic` rolls back automatically if rollout fails |
| **Pre-deploy validation** | `helm lint` + `helm template` dry-run |
| **Vulnerability gating** | Trivy fails build on CRITICAL CVEs |
| **Test reporting** | `junit` step archives JUnit XML for trends |
| **Artifact retention** | `buildDiscarder` keeps last 20 builds |
| **Observable failures** | Slack notification on failure with build URL |
| **Auditable approvals** | `input` step records who approved prod |
| **Concurrent build safety** | `disableConcurrentBuilds()` prevents race conditions |
| **Secret hygiene** | All AWS access via Jenkins credentials, never in code |
| **Build time bound** | Pipeline `timeout(45 minutes)` and stage `timeout(30 minutes)` for prod approval |
| **Layer cache** | `docker buildx` with inline cache for fast rebuilds |
| **Selective builds** | `detect-changes.sh` builds only what changed (optional optimization) |
| **One-click rollback** | `ROLLBACK_REVISION` parameter |

## Webhooks for automatic builds

Configure GitHub → Jenkins webhook for `push` and `pull_request` events. Multibranch Pipeline auto-discovers branches.

```
GitHub repo → Settings → Webhooks → Add webhook
URL: https://jenkins.example.com/github-webhook/
Content type: application/json
Events: Push, Pull request
```

## Common operations

```bash
# View pipeline history for an environment
helm history healthcare -n healthcare

# Manual deploy outside Jenkins (e.g., debugging)
./ci/scripts/deploy.sh dev main-42-a3f9c1d

# Local image scan before pushing
./ci/scripts/scan-images.sh dev-local

# Test the chart renders before committing
helm lint helm/healthcare
helm template healthcare helm/healthcare -f helm/healthcare/values-dev.yaml
```

## Migrating from "kubectl apply -f k8s/"

Once the pipeline is running, the hand-applied [k8s/](../k8s/) folder becomes redundant. Remove it after one successful prod deploy from Jenkins, or keep it around as a reference. The Helm chart is now the source of truth.