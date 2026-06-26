# ArgoCD — GitOps for the Smart Healthcare System

ArgoCD watches this repo and keeps the cluster in sync with whatever's in Git.
You push a YAML change → ArgoCD applies it within ~3 minutes. No more
`kubectl apply` from laptops, no more "what's actually deployed?" archaeology.

## What's in here

```
argocd/
├── install.sh                              # one-shot installer + bootstrap
├── EKS.md                                  # what changes when you move to EKS
├── projects/
│   └── healthcare-project.yaml             # AppProject — scopes what apps may touch
├── applications/
│   ├── root-app.yaml                       # app-of-apps — manages the rest
│   ├── healthcare-app.yaml                 # watches k8s/   (raw manifests)
│   ├── healthcare-helm-app.yaml            # ALT: watches helm/healthcare/
│   ├── healthcare-helm-app-imageupdater.yaml  # same + auto image bumps
│   ├── monitoring-app.yaml                 # watches monitoring/k8s/
│   └── kube-prometheus-stack-app.yaml      # ALT: full Prometheus Operator chart
└── image-updater/
    └── install.sh                          # ArgoCD Image Updater installer
```

## Concepts in 60 seconds

| Object | Purpose |
| --- | --- |
| **AppProject** | A bucket. Restricts which repos, namespaces, and resource kinds the Applications inside can touch. |
| **Application** | "Watch this path in this repo, sync to this cluster + namespace." Has its own sync policy and health state. |
| **App-of-apps** | One Application whose `path:` points at a folder of *other* Application manifests. Bootstrapping it creates the rest — you never touch `kubectl apply` for new apps again. |
| **Sync** | ArgoCD reconciles Git → cluster. Can be manual or `automated`. |
| **Self-heal** | If someone manually changes the cluster, ArgoCD reverts it back to Git. |
| **Prune** | Resources removed from Git are deleted from the cluster on the next sync. |

## Install

```bash
./argocd/install.sh
```

That script:
1. Creates the `argocd` namespace.
2. Applies the upstream ArgoCD install manifests.
3. Waits for `argocd-server` to be ready.
4. Applies the AppProject and the root Application.
5. Prints the initial admin password.

After it finishes, the root app pulls in `healthcare-app` and `monitoring-app`,
which then sync your existing manifests onto the cluster.

## Open the UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8081:443
# https://localhost:8081  (accept the self-signed cert)
# user:     admin
# password: from the install script output, or:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
```

## CLI (optional but useful)

```bash
brew install argocd

# log in via the port-forward above
argocd login localhost:8081 --insecure

argocd app list
argocd app get healthcare-app
argocd app sync healthcare-app                 # force an immediate sync
argocd app diff healthcare-app                 # see what's drifted
argocd app rollback healthcare-app <REV>       # roll back to an earlier sync
```

## Day-2 workflow

1. Edit any file under [k8s/](../k8s/) or [monitoring/k8s/](../monitoring/k8s/).
2. `git commit && git push`.
3. ArgoCD detects the change on its next poll (default 3 min) and applies it.
4. Watch the Application turn green in the UI.

Don't run `kubectl apply -f k8s/` by hand once ArgoCD owns the app —
`selfHeal: true` will revert it within seconds anyway.

## Choosing between raw manifests and Helm

You have both. They cover the same workloads — pick one:

| | `healthcare-app.yaml` (raw) | `healthcare-helm-app.yaml` (Helm) |
| --- | --- | --- |
| Source | [k8s/](../k8s/) folder | [helm/healthcare/](../helm/healthcare/) chart |
| Per-env config | edit YAML directly | `values-dev.yaml`, `values-eks.yaml`, … |
| Image-tag rotation | edit YAML | `--set image.tag=$SHA` from CI, or ArgoCD Image Updater |
| Use when | learning / simple env | promoting through dev → staging → prod |

If you want to switch to Helm, delete `healthcare-app.yaml` from the repo
(or move it elsewhere) and ArgoCD will prune the duplicate.

## Connecting to a private repo

The repo URL in every Application is currently `https://…/Java-FullStack-K8s-Deploy.git`.
If it's private, give ArgoCD credentials once:

```bash
# personal access token with `repo` scope
argocd repo add https://github.com/AnshulBharadwaj73/Java-FullStack-K8s-Deploy.git \
  --username AnshulBharadwaj73 --password <PAT>
```

Or declaratively, with a Secret in the `argocd` namespace labelled
`argocd.argoproj.io/secret-type: repository`. See ArgoCD docs.

## Uninstall

```bash
# delete the apps first so finalizers run cleanly
kubectl -n argocd delete application --all
kubectl -n argocd delete appproject healthcare
kubectl delete -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

## Why this matters for your project

You've already hit the "I pushed an image but the cluster is still running the
old one" problem. With ArgoCD + immutable image tags
(`anshul9589/shsm-auth-service:<git-sha>`):

1. CI builds the image, tags it `:$SHA`, pushes to Docker Hub.
2. CI does **one** `sed` to bump the tag in `k8s/06-auth-service.yaml`
   (or `--set image.tag=$SHA` in the Helm values file) and commits.
3. ArgoCD picks up the new tag → kubelet sees a new image reference →
   pulls the new digest → deploys.

No more `kubectl set image` from laptops. No more wondering whether `:latest`
actually re-pulled. Every deploy is a Git commit you can `git revert`.
