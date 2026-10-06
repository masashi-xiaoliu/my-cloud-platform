#!/usr/bin/env bash
# Phase 3: kind クラスタと Ingress Controller (Traefik) を「手作業で」作る。
# Phase 6 ではこれと同じことを Terraform で行い、違いを比べる。
set -euo pipefail
cd "$(dirname "$0")/.."

if kind get clusters | grep -qx my-cloud-platform; then
  echo "cluster my-cloud-platform already exists"
else
  kind create cluster --config scripts/kind-config.yaml
fi

helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update traefik >/dev/null
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --set service.type=NodePort \
  --set ports.web.nodePort=30080 \
  --set ports.websecure.nodePort=30443 \
  --set ingressClass.isDefaultClass=true \
  --wait

kubectl get nodes -o wide
kubectl -n traefik get pods,svc
echo "✅ cluster ready. 次: make local-deploy"
