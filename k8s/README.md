# Kubernetes manifests — minikube local run

Single namespace `healthcare`. One `app-config` ConfigMap, one `app-secret` Secret. MongoDB and Kafka run as single-replica Deployments (Kafka in KRaft mode, matching `docker-compose.yml`). External traffic enters via the `healthcare-ingress` Ingress; the UI also has a NodePort fallback at `31000`.

No Role/RoleBinding — none of the workloads call the Kubernetes API.

## Files

| # | File | Purpose |
|---|------|---------|
| 00 | `00-namespace.yaml` | `healthcare` namespace |
| 01 | `01-configmap.yaml` | Non-secret env (Kafka, mail, mongo host) |
| 02 | `02-secret.yaml` | JWT secret, mongo creds, mail password |
| 03 | `03-mongodb.yaml` | Mongo Deployment + PVC + Service |
| 04 | `04-kafka.yaml` | Kafka KRaft Deployment + Service |
| 05 | `05-gateway-service.yaml` | API gateway |
| 06 | `06-auth-service.yaml` | Auth |
| 07 | `07-doctor-service.yaml` | Doctor |
| 08 | `08-patient-service.yaml` | Patient |
| 09 | `09-appointment-service.yaml` | Appointment |
| 10 | `10-notification-service.yaml` | Notification |
| 11 | `11-admin-service.yaml` | Admin |
| 12 | `12-ui-service.yaml` | UI (NodePort 31000) |
| 13 | `13-ingress.yaml` | nginx Ingress on `healthcare.local` |

## Run on minikube

```bash
# 1. Start minikube and enable ingress
minikube start --memory=6g --cpus=4
minikube addons enable ingress

# 2. Build images into minikube's docker daemon (so imagePullPolicy: IfNotPresent works)
eval $(minikube docker-env)
docker build -t anshul9589/shsm-gateway-service:latest      ./gateway-service
docker build -t anshul9589/shsm-auth-service:latest         ./auth-service
docker build -t anshul9589/shsm-doctor-service:latest       ./doctor-service
docker build -t anshul9589/shsm-patient-service:latest      ./patient-service
docker build -t anshul9589/shsm-appointment-service:latest  ./appointment-service
docker build -t anshul9589/shsm-notification-service:latest ./notification-service
docker build -t anshul9589/shsm-admin-service:latest        ./admin-service
docker build -t anshul9589/shsm-ui-service:latest           ./ui-component

# 3. Apply manifests in order
kubectl apply -f k8s/

# 4. Add host entry for ingress
echo "$(minikube ip) healthcare.local" | sudo tee -a /etc/hosts

# 5. Access:
#    UI       — http://healthcare.local/        or http://$(minikube ip):31000
#    Gateway  — http://healthcare.local/api
#    Admin    — http://healthcare.local/admin
```

## Notes

- Update the `MAIL_SERVER_PASSWORD` in [02-secret.yaml](02-secret.yaml) before applying — it's a placeholder.
- Older partial manifests (`appointment-service.yml`, `kafka-deploy.yml`, `kafka-ui.yml`, `mongo-deploy.yml`, `ui-frontend.yml`) are superseded by the numbered files; remove them if no longer needed.
- Single-replica Mongo/Kafka is fine for local dev; scaling Kafka requires switching to a StatefulSet with stable per-pod node IDs.
