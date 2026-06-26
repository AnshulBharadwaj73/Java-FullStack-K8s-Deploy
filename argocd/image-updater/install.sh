#!/usr/bin/env bash
# Installs ArgoCD Image Updater into the existing argocd namespace.
# It polls container registries and, when it finds a new image matching your
# policy, either:
#   - patches the Application's `helm.parameters` / `kustomize.images`
#     (Argo CD-only mode), OR
#   - commits a tag bump back to Git (Git write-back mode, recommended).
#
# Usage:
#   ./install.sh                    # default: latest stable
#   IMAGE_UPDATER_VERSION=v0.16.0 ./install.sh
set -euo pipefail

VERSION="${IMAGE_UPDATER_VERSION:-stable}"

echo "==> installing argocd-image-updater (${VERSION})"
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/${VERSION}/manifests/install.yaml"

kubectl -n argocd rollout status deploy argocd-image-updater --timeout=180s
echo "==> done. logs:  kubectl -n argocd logs deploy/argocd-image-updater -f"
