#!/usr/bin/env bash
# 環境を削除する。GCP は課金が止まるまで責任を持って確認すること。
#   使い方: ./scripts/destroy.sh local   … kind クラスタ削除（Terraform 管理なら terraform destroy）
#           ./scripts/destroy.sh gcp <project_id>
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
  local)
    if [ -f terraform/environments/local/terraform.tfstate ]; then
      terraform -chdir=terraform/environments/local destroy
    else
      kind delete cluster --name my-cloud-platform
    fi ;;
  gcp)
    PROJECT="${2:?project_id required}"
    echo "⚠ GCP dev 環境 ($PROJECT) を削除します。"
    echo "  先に Kubernetes の LoadBalancer Service / PVC を消さないと、LB やディスクが残ることがあります。"
    read -rp "続けますか? (yes/no) " ans; [ "$ans" = yes ] || exit 1
    kubectl delete ns mcp-dev mcp-staging mcp-prod --ignore-not-found --wait=true || true
    terraform -chdir=terraform/environments/dev destroy -var="project_id=$PROJECT"
    echo "== 残存リソース確認（すべて空になるのが理想）=="
    gcloud compute forwarding-rules list --project "$PROJECT"
    gcloud compute disks list --project "$PROJECT"
    gcloud container clusters list --project "$PROJECT"
    gcloud sql instances list --project "$PROJECT" 2>/dev/null || true
    ;;
  *) echo "usage: $0 local | gcp <project_id>"; exit 1 ;;
esac
