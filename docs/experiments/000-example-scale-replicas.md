# Experiment 000: replicas を 1 → 3 → 10 に変える（記入例）

- Date: 2026-10-10
- Lab ID: T01
- Environment: dev (kind, worker 1 台)
- PR: #12, #13

## Objective
replicas を変えたとき、Deployment / ReplicaSet / Pod がそれぞれどう変化するか確認する。

## Current Configuration
`kubernetes/overlays/dev/patch-deployment.yaml`
```yaml
spec:
  replicas: 1
```

## Change
```diff
-  replicas: 1
+  replicas: 3
```
（その後 3 → 10）

## Prediction
- Pod が 3 個になる。新しい ReplicaSet は作られない（Pod テンプレートが変わらないため）
- 10 にすると、kind のノード容量では全部は載らないかもしれない

## Execution
1. `git switch -c lab/T01-replicas-3` → 変更 → PR #12 → CI ✅ → Merge
2. Argo CD で Refresh
3. `kubectl -n mcp-dev get deploy,rs,pods -w`

## Observation
```text
NAME                       READY   UP-TO-DATE   AVAILABLE
deployment.apps/hello-go   3/3     3            3
NAME                                 DESIRED   CURRENT   READY
replicaset.apps/hello-go-7d9c5b8f6   3         3         3
```
- Merge から 3/3 になるまで約 70 秒（うち Argo CD の検知待ちが約 50 秒）
- 10 のとき: 10 Pod すべて Running（requests 50m × 10 = 500m で収まった）← 予想外れ

## Verification
- Argo CD: Synced / Healthy、ツリーに Pod 3 つ
- `curl` 10 回で pod 名が 3 種類
- Grafana Ready Pods: 1 → 3

## Why?
requests が 50m と小さいため、10 Pod でもノードの Allocatable（約 2 CPU）に収まった。Pending になるかどうかは「Pod 数」ではなく「requests の合計」で決まる。

## Troubleshooting
なし

## Recovery
replicas: 1 に戻す PR #14 → Merge → 1/1 を確認（約 60 秒）

## Lessons Learned
- ReplicaSet が増えるのは Pod テンプレートが変わったときだけ
- Pending の判断基準は requests → 次は T02 で requests を 500m にして同じ実験をする
- Argo CD の検知待ちが反映時間の大半 → C08 でポーリング間隔を試す
