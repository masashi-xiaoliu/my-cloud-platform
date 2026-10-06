# Tuning Lab 02 — HPA（オートスケール）

負荷に応じて Pod 数が自動で変わる仕組みを、設定値を変えながら観察する。

## 目次

- [T06: HPA（Horizontal Pod Autoscaler）](#t06-hpahorizontal-pod-autoscaler)

---

## T06: HPA（Horizontal Pod Autoscaler）

> Phase 8 以降 ｜ 所要 40 分 ｜ 環境: dev

**What** — CPU 使用率などのメトリクスに応じて replicas を自動で増減する仕組み。

**Why（実務でなぜ触るか）** — 「アクセスが増えたら自動で増やす」は案件要件として頻出（Case Study CR-1）。設定値次第で費用と安定性が大きく変わる。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | ① `kubernetes/overlays/dev/kustomization.yaml` の `components` で `../../components/hpa` を有効化 ② `kubernetes/overlays/dev/patch-deployment.yaml` の `replicas` 行を削除 ③ `kubernetes/components/hpa/hpa.yaml` の `minReplicas` / `maxReplicas` / `averageUtilization` / `stabilizationWindowSeconds` |
| ② 変更する値 | 有効化（min 1 / max 5 / 70%）→ 負荷 → `maxReplicas: 5 → 2` → 負荷 → `averageUtilization: 70 → 30` → 負荷 |
| ③ 予想される結果 | 負荷をかけると CPU が 70% を超え、Pod が段階的に最大 5 まで増える。負荷を止めると 60 秒程度待ってから減る。max=2 では 2 で頭打ち。30% ではより早く・多く増える。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. 前提: metrics-server が動いている（`kubectl top pods` が値を返す）
2. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
3. ターミナル A: `kubectl -n mcp-dev get hpa -w`
4. ターミナル B: `./scripts/load.sh mcp-dev 4`
5. ターミナル C: `watch kubectl -n mcp-dev top pods`
6. Job 完了後（または `kubectl -n mcp-dev delete job loadgen`）、スケールインまでの時間を計測

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get hpa` | TARGETS が `xx%/70%`（`<unknown>` ではない）、REPLICAS が増減 |
| ターミナル | `kubectl -n mcp-dev describe hpa hello-go` | Events に `New size: N; reason: cpu resource utilization above target` |
| Grafana | Pods (desired / ready / HPA) | 負荷に合わせて階段状に増え、遅れて減る |
| Argo CD UI > `hello-go-dev` | Application | HPA 有効後も Synced（replicas 綱引きが起きていない） |

### ⑥ うまくいかない場合の調査

- TARGETS が `<unknown>` → metrics-server が動いていない / Pod に CPU requests がない（使用率は requests に対する % で計算される）
- Pod が増えたり減ったりを繰り返す → Argo CD が replicas を戻している（patch-deployment.yaml の replicas 行を消し忘れ。CI の check-manifests が検出するはず）
- 増えた Pod が Pending → ノード容量不足（T02）。クラウドなら Cluster Autoscaler の出番（G01 発展）

### ⑦ 復旧方法

- components から hpa を外し、replicas 行を戻して Merge

<details><summary>💡 Hint 1</summary>

HPA の使用率は『requests に対する %』。requests を 2 倍にすると同じ負荷でも % は半分になる。

</details>

<details><summary>💡 Hint 2</summary>

スケールインが遅いのは意図的。どの設定が関係している?

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

HPA は 15 秒ごとに `desired = ceil(current × 現在の使用率 / 目標使用率)` を計算する。スケールアウトは即座だが、スケールインは `stabilizationWindowSeconds` の間の最大推奨値を採用するため遅れる（バタつき防止）。目標値を下げるほど余裕を持った（＝高コストな）運用になる。requests を変えると使用率の分母が変わるため、HPA と requests はセットで調整する。

</details>

**🔁 発展（もう一周）**

- `stabilizationWindowSeconds: 0` にしてバタつき（flapping）を観察する
- Case Study CR-1 で本番相当の値を設計して ADR に残す

---
