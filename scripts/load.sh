#!/usr/bin/env bash
# 負荷を発生させる（HPA / CPU / Grafana の観察用）。
#   使い方: ./scripts/load.sh [namespace] [parallelism]
set -euo pipefail
cd "$(dirname "$0")/.."
NS="${1:-mcp-dev}"; P="${2:-4}"
kubectl -n "$NS" delete job loadgen --ignore-not-found
sed "s/parallelism: 4/parallelism: $P/; s/completions: 4/completions: $P/" kubernetes/jobs/loadgen-job.yaml | kubectl -n "$NS" apply -f -
echo "負荷開始。別ターミナルで観察:"
echo "  kubectl -n $NS get hpa -w"
echo "  watch kubectl -n $NS top pods"
echo "  Grafana > Dashboards > My Cloud Platform / hello-go"
echo "停止: kubectl -n $NS delete job loadgen"
