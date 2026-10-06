#!/usr/bin/env bash
# Phase 5: Argo CD を手作業でインストールし、root Application (App of Apps) を登録する。
# Phase 6 以降は Terraform が Argo CD をインストールするので、root.yaml の apply だけ行う。
set -euo pipefail
cd "$(dirname "$0")/.."

if ! kubectl get ns argocd >/dev/null 2>&1; then
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
fi

kubectl apply -n argocd -f argocd/bootstrap/root.yaml

echo
echo "Argo CD UI:  kubectl -n argocd port-forward svc/argocd-server 8443:443  → https://localhost:8443"
echo "  (Terraform で入れた場合は http://argocd.localtest.me)"
echo "user: admin"
echo -n "password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
