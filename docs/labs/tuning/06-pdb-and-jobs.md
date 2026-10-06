# Tuning Lab 06 — PDB / Job / CronJob

メンテナンス時の可用性と、常駐しない処理の扱い。

## 目次

- [T15: PodDisruptionBudget と drain](#t15-poddisruptionbudget-と-drain)
- [T19: Job / CronJob](#t19-job--cronjob)

---

## T15: PodDisruptionBudget と drain

> Phase 5 以降 ｜ 所要 25 分 ｜ 環境: dev（worker ノード 1 台以上）

**What** — ノードのメンテナンスなど『自発的な中断』時に、最低限維持する Pod 数。

**Why（実務でなぜ触るか）** — GKE の自動アップグレードでノードが順に drain される。PDB がないと全 Pod が同時に消えうる。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/kustomization.yaml` の components に `../../components/pdb`、`kubernetes/components/pdb/pdb.yaml` の `minAvailable` |
| ② 変更する値 | replicas=1・minAvailable=1 で worker を drain → replicas=2 にして再度 drain |
| ③ 予想される結果 | replicas=1 では drain が `Cannot evict pod` で止まる。replicas=2 では 1 つずつ退避され、成功する |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. `kubectl get pods -n mcp-dev -o wide` で Pod が載っているノードを確認
3. `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=60s`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | drain の出力 | `error when evicting ... would violate the pod's disruption budget`（replicas=1） |
| ターミナル | `kubectl -n mcp-dev get pdb` | `ALLOWED DISRUPTIONS` が 0 / 1 |

### ⑥ うまくいかない場合の調査

- drain が終わらない → PDB を確認

### ⑦ 復旧方法

- `kubectl uncordon <node>`（忘れると以後そのノードに Pod が載らない）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

drain は Eviction API を使い、PDB に違反する退避を拒否する。replicas=1 で minAvailable=1 だと永遠に退避できず、クラスタのアップグレードを妨げる。『PDB は replicas ≥ 2 とセットで』が実務の鉄則。

</details>

**🔁 発展（もう一周）**

- `maxUnavailable: 1` 形式の PDB と比べる

---

## T19: Job / CronJob

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

**What** — 一度だけ・定期的に実行して終了する処理。

**Why（実務でなぜ触るか）** — DB マイグレーション、バッチ、定期レポート、外形監視など Web 案件でも頻出（Laravel の schedule:run など）。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/jobs/smoke-cronjob.yaml` の `schedule`、`kubernetes/jobs/loadgen-job.yaml` の `parallelism` |
| ② 変更する値 | ① CronJob を apply（毎分）② `schedule: */5 * * * *` ③ hello-go を壊した状態（I03）で CronJob の結果を見る |
| ③ 予想される結果 | ① 毎分 Job が作られ Completed ③ Job が Failed になる（外形監視として機能する） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `kubectl -n mcp-dev apply -f kubernetes/jobs/smoke-cronjob.yaml`
2. `kubectl -n mcp-dev get cronjob,jobs,pods -w`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get jobs` | COMPLETIONS が `1/1` |
| ターミナル | `kubectl -n mcp-dev logs job/<job名>` | `SMOKE_OK` |

### ⑥ うまくいかない場合の調査

- Failed の Job: `kubectl -n mcp-dev describe job <name>` / `logs`

### ⑦ 復旧方法

- `kubectl -n mcp-dev delete cronjob smoke`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

CronJob はスケジュールごとに Job を作り、Job は Pod を作って完了を待つ。`concurrencyPolicy: Forbid` は前回が終わっていなければ次を作らない設定（重複実行防止）。履歴保持数を設定しないと Pod が溜まり続ける。

</details>

**🔁 発展（もう一周）**

- CronJob を overlays/dev に入れて GitOps 管理にする
- 失敗した Job を Prometheus（`kube_job_status_failed`）でアラートにする

---
