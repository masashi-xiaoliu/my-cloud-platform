# Troubleshooting Guide

## 0. まず全体を見る

```bash
./scripts/status.sh mcp-dev        # nodes / argocd apps / workloads / endpoints / top / warnings / http
kubectl config current-context     # ← 今どのクラスタを触っているか（kind? GKE?）
```

## 1. 症状から引く

| 症状 | 最初のコマンド | よくある原因 | Lab |
|---|---|---|---|
| Pod が `Pending` | `kubectl describe pod <p>`（Events） | requests 過大 / ノード不足 / PVC 未割当 / taint | I08, T02 |
| `ImagePullBackOff` / `ErrImagePull` | `kubectl describe pod <p>` | タグが存在しない / Private レジストリの認証 / NAT なし | I02, G05 |
| `CrashLoopBackOff` | `kubectl logs <p> --previous` | 設定エラー / 起動時例外 / OOM | I01, I06, I12 |
| `OOMKilled`（Exit 137） | `kubectl describe pod <p>`（Last State） | memory limit 不足 / リーク | I09, T05 |
| Running だが `0/1` | `kubectl describe pod <p>`（Readiness probe failed） | probe の path / port / 起動遅延 | I05, T11 |
| RESTARTS が増え続ける | `kubectl describe pod <p>`（Liveness probe failed） | liveness の設定 / デッドロック | I11 |
| 502 / 503（Ingress 経由） | `kubectl get endpointslices` / `describe svc` | targetPort / selector / Ready な Pod なし | I03, I04 |
| 404（Ingress 経由） | `kubectl get ingress` / `get ingressclass` | host / ingressClassName / path | I10, T14 |
| 一部だけ 500 | Grafana Error rate / `logs \| jq` | アプリの不具合 / 外部依存 | I07, I15 |
| 遅い | Grafana latency / throttling / `kubectl top pods` | CPU limit / 外部 API / リトライ | T03, T09 |
| Argo CD `OutOfSync` のまま | Argo CD > Refresh / App Details | 自動 Sync なし（prod）/ Sync エラー | I14, C05 |
| Argo CD `Degraded` | ツリーで赤いリソース | Pod が起動していない | I02, I01 |
| Argo CD `ComparisonError` | App Details > CONDITIONS | kustomize build 失敗 / ブランチ・パス | I14 |
| CI ❌ | PR > Checks > Details > 赤い Step | テスト / fmt / YAML / tf fmt | I13, C02 |
| `terraform apply` 失敗 | エラーメッセージ / `terraform plan` 再実行 | 権限 / API 未有効 / クォータ / 依存順 | GCP Lab |

## 2. 外から内へ（ネットワークの切り分け）

```text
① DNS        nslookup hello-dev.localtest.me                    → 127.0.0.1 ?
② Ingress    curl -i -H 'Host: hello-dev.localtest.me' http://127.0.0.1/
             kubectl -n traefik logs deploy/traefik
③ Service    kubectl -n mcp-dev port-forward svc/hello-go 18080:80   → curl localhost:18080
④ Endpoint   kubectl -n mcp-dev get endpointslices -o wide
⑤ Pod        kubectl -n mcp-dev port-forward pod/<p> 18081:8080    → curl localhost:18081
⑥ アプリ     kubectl -n mcp-dev logs <p>
```
③ が失敗して ⑤ が成功 → Service / Endpoint の問題。⑤ も失敗 → Pod / アプリの問題。

## 3. コマンド早見表

```bash
# 状態
kubectl -n mcp-dev get deploy,rs,pods,svc,ingress,hpa,pdb -o wide
kubectl -n mcp-dev get pods --show-labels
kubectl -n mcp-dev get events --sort-by=.lastTimestamp | tail -20

# 詳細
kubectl -n mcp-dev describe pod <p>          # Events / Last State / Probe
kubectl -n mcp-dev get pod <p> -o yaml       # 実際に適用された spec
kubectl -n mcp-dev rollout status deploy/hello-go
kubectl -n mcp-dev rollout history deploy/hello-go

# ログ
kubectl -n mcp-dev logs <p> [--previous] [-f]
kubectl -n mcp-dev logs -l app.kubernetes.io/name=hello-go --prefix --since=10m
kubectl -n mcp-dev logs deploy/hello-go | jq -c 'select(.level=="ERROR")'

# 中から確認（distroless にはシェルがないので一時 Pod / debug コンテナ）
kubectl -n mcp-dev run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
kubectl -n mcp-dev debug -it <p> --image=busybox:1.36 --target=hello-go

# リソース
kubectl top nodes ; kubectl -n mcp-dev top pods
kubectl describe nodes | grep -A8 "Allocated resources"

# 最終形の YAML（Git 側）
kustomize build kubernetes/overlays/dev | less

# Argo CD
kubectl -n argocd get applications
kubectl -n argocd get application hello-go-dev -o jsonpath='{.status.conditions}'
```

## 4. 復旧の原則
1. **止血を優先**：原因究明の前に Rollback（[R01](labs/recovery/README.md)）してよい
2. **GitOps では Git を直す**：`kubectl edit` / `rollout undo` は selfHeal で戻される（R03）
3. **1 回に 1 つだけ変える**
4. **記録する**：`docs/experiments/` と障害報告書
