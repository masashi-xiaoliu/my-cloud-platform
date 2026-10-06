#!/usr/bin/env bash
# 「いま何が起きているか」を 1 コマンドで俯瞰する。障害対応の最初の一手。
#   使い方: ./scripts/status.sh [namespace]   (default: mcp-dev)
NS="${1:-mcp-dev}"
hr() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

hr "context";               kubectl config current-context
hr "nodes";                 kubectl get nodes -o wide
hr "argocd applications";   kubectl -n argocd get applications 2>/dev/null || echo "(Argo CD not installed)"
hr "workloads in $NS";      kubectl -n "$NS" get deploy,rs,pods,svc,ingress,hpa,pdb -o wide 2>/dev/null
hr "endpoints in $NS";      kubectl -n "$NS" get endpointslices 2>/dev/null
hr "top pods in $NS";       kubectl -n "$NS" top pods 2>/dev/null || echo "(metrics-server not ready)"
hr "recent warnings in $NS"
kubectl -n "$NS" get events --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -15
hr "http check"
host=$( [ "$NS" = mcp-prod ] && echo hello.localtest.me || echo "hello-${NS#mcp-}.localtest.me")
curl -s -m 3 -o /dev/null -w "GET http://$host/  → %{http_code} (%{time_total}s)\n" "http://$host/" || echo "curl failed"
