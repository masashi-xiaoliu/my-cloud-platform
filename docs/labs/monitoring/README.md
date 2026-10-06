# Monitoring Lab — Prometheus / Grafana / Logging

Prometheus（収集）と Grafana（可視化）で、**設定変更 → システム変化 → メトリクス変化** を自分の目で確認する。

## 開き方（Phase 8：`enable_monitoring = true` で apply 後）

| 画面 | URL（local） | ログイン |
|---|---|---|
| Grafana | http://grafana.localtest.me | `admin` / `admin-change-me`（terraform.tfvars の grafana_admin_password） |
| Prometheus | http://prometheus.localtest.me | なし |
| GKE の場合 | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80` → http://localhost:3000 | 同上 |

## 有効化チェックリスト

1. `terraform/environments/local/terraform.tfvars` に `enable_monitoring = true` → `terraform plan`（追加されるリソースを読む）→ `apply`
2. `kubernetes/overlays/dev/kustomization.yaml` の components で `../../components/monitoring` をコメント解除 → PR → Merge
3. `argocd/applications/kustomization.yaml` で `monitoring-dashboards.yaml` をコメント解除 → PR → Merge
4. Prometheus > Status > **Targets** に `serviceMonitor/mcp-dev/hello-go/0` が **UP**
5. Grafana > Dashboards に **My Cloud Platform / hello-go**

## ダッシュボードの読み方

| パネル | 何を表すか | 関連 Lab |
|---|---|---|
| Ready Pods / Pods | Deployment の desired / ready、HPA の desired | T01, T06 |
| Requests / sec | 秒間リクエスト数（Rate） | M02 |
| Error rate (5xx) | 5xx の割合（Errors） | M03, I07 |
| p95 latency / Latency p50/p95/p99 | 応答時間（Duration） | M04, T03 |
| CPU usage vs requests / limits | 実使用量と予約・上限の関係 | T02, T03 |
| CPU throttling | limit に当たって待たされた割合 | T03 |
| Memory working set vs limit | OOM までの余裕 | T05, I09 |
| Container restarts | 再起動回数 | I01, I09, I11 |
| App version running | どのバージョンが何 Pod 動いているか | T08, T10, R01 |


## 目次

- [M01: Pod を増やして Grafana で確認](#m01-pod-を増やして-grafana-で確認)
- [M02: 負荷を発生させて CPU を見る](#m02-負荷を発生させて-cpu-を見る)
- [M03: アプリケーションエラーを発生させて Error rate を見る](#m03-アプリケーションエラーを発生させて-error-rate-を見る)
- [M04: レスポンスを遅くして Response time を見る](#m04-レスポンスを遅くして-response-time-を見る)
- [M05: スクレイプ間隔を変える](#m05-スクレイプ間隔を変える)
- [M06: アラート閾値を調整する](#m06-アラート閾値を調整する)
- [M07: 保持期間（retention）と Terraform](#m07-保持期間retentionと-terraform)
- [M08: ログで調査する（Logging）](#m08-ログで調査するlogging)

---

## M01: Pod を増やして Grafana で確認

> Phase 8 以降 ｜ 所要 15 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/patch-deployment.yaml` の replicas |
| ② 変更する値 | `1` → `3` |
| ③ 予想される結果 | Ready Pods が 1 → 3、App version running の合計も 3 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順で dev に反映
2. Grafana の右上の時間範囲を `Last 15 minutes`、自動更新 `10s`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Grafana > Dashboards > **My Cloud Platform / hello-go** | Ready Pods / Pods パネル | 階段状に 3 へ |
| Prometheus > Graph | `kube_deployment_status_replicas_ready{namespace="mcp-dev"}` | 値が 3 |

### ⑥ うまくいかない場合の調査

- No data → Targets が UP か、namespace 変数が mcp-dev か

### ⑦ 復旧方法

- replicas を戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Grafana は Prometheus に PromQL を投げて結果を描いているだけ。パネルの `Edit` で式を見ると、自分で書けるようになる。

</details>

---

## M02: 負荷を発生させて CPU を見る

> Phase 8 以降 ｜ 所要 20 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `./scripts/load.sh mcp-dev <並列数>` |
| ② 変更する値 | 並列数 `2` → `6` |
| ③ 予想される結果 | Requests/sec と CPU usage が上昇、limit に達すると throttling も上昇 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `./scripts/load.sh mcp-dev 2` → 5 分観察 → `kubectl -n mcp-dev delete job loadgen` → `./scripts/load.sh mcp-dev 6`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Grafana > Dashboards > **My Cloud Platform / hello-go** | CPU usage / CPU throttling / Requests/sec | 負荷量に比例して変化 |

### ⑥ うまくいかない場合の調査

- 上がらない → loadgen Pod のログ `kubectl -n mcp-dev logs job/loadgen`

### ⑦ 復旧方法

- Job を削除

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

負荷 → CPU → （HPA があれば）Pod 数 → CPU/Pod 低下、という因果の連鎖をグラフの時間差で読み取る。

</details>

---

## M03: アプリケーションエラーを発生させて Error rate を見る

> Phase 8 以降 ｜ 所要 20 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/config.env` の `ERROR_RATE` |
| ② 変更する値 | `0` → `20`（負荷をかけながら） |
| ③ 予想される結果 | Error rate が約 20%、2 分後に `HelloGoHighErrorRate` アラートが Firing |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順で dev に反映
2. `./scripts/load.sh mcp-dev 2` で継続的にリクエストを流す

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Grafana > Dashboards > **My Cloud Platform / hello-go** | Error rate / Requests by status code | 約 20% |
| Prometheus > Alerts | HelloGoHighErrorRate | Pending → Firing |

### ⑥ うまくいかない場合の調査

- アラートが出ない → Prometheus > Status > Rules にルールがあるか（PrometheusRule が Sync されているか）

### ⑦ 復旧方法

- `ERROR_RATE=0`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

アラートの `for: 2m` は『2 分継続したら』。一瞬のスパイクで起こされないための設定（M06 で調整）。

</details>

---

## M04: レスポンスを遅くして Response time を見る

> Phase 8 以降 ｜ 所要 20 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `config.env` の `LATENCY_MS` |
| ② 変更する値 | `0` → `300` → `800` |
| ③ 予想される結果 | p95 が 0.3s → 0.8s、800 では HelloGoHighLatencyP95 が 5 分後に Firing |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順で dev に反映
2. 負荷を流しながら観察

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Grafana > Dashboards > **My Cloud Platform / hello-go** | Latency p50/p95/p99 | 設定値付近に張り付く |

### ⑥ うまくいかない場合の調査

- ヒストグラムのバケット境界（0.25, 0.5, 1）で値が丸められて見える点に注意

### ⑦ 復旧方法

- `LATENCY_MS=0`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

平均ではなくパーセンタイルを見るのは、一部の遅いユーザーを平均が隠すため。histogram_quantile はバケットから推定するため、バケット設計（metrics.go の durationBuckets）が精度を決める。

</details>

---

## M05: スクレイプ間隔を変える

> Phase 8 以降 ｜ 所要 15 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/components/monitoring/servicemonitor.yaml` の `interval` |
| ② 変更する値 | `15s` → `60s` |
| ③ 予想される結果 | グラフが粗くなり、`rate(...[1m])` が No data になることがある |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順で dev に反映

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Grafana > Dashboards > **My Cloud Platform / hello-go** | Requests/sec | 線がカクカクになる / 途切れる |

### ⑥ うまくいかない場合の調査

- rate の範囲はスクレイプ間隔の 4 倍以上が目安

### ⑦ 復旧方法

- `15s`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

間隔を長くすると Prometheus の負荷・ストレージは減るが、短い障害を見逃す。rate() の範囲より間隔が長いとデータ点が足りず計算できない。

</details>

---

## M06: アラート閾値を調整する

> Phase 8 以降 ｜ 所要 20 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/components/monitoring/prometheusrule.yaml` |
| ② 変更する値 | `> 0.05` → `> 0.01`、`for: 2m` → `for: 0m` |
| ③ 予想される結果 | わずかなエラーでも即座に発火（ノイズの多いアラート） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順で dev に反映
2. ERROR_RATE=2 で観察

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Prometheus > Alerts | HelloGoHighErrorRate | すぐ Firing |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- 元に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

鳴りすぎるアラートは無視されるようになり、本当の障害を見逃す（アラート疲れ）。『ユーザーに影響があるときだけ鳴る』閾値を、実データを見ながら決める。

</details>

---

## M07: 保持期間（retention）と Terraform

> Phase 8 以降 ｜ 所要 15 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `monitoring/prometheus/values.yaml` の `retention` |
| ② 変更する値 | `2d` → `7d` |
| ③ 予想される結果 | terraform plan に helm_release の values 変更（update in-place）が出る |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/local plan` → 差分を読む → apply

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| terraform plan | 出力 | `~ resource "helm_release" "kube_prometheus_stack"` |
| Prometheus > Status > Runtime & Build Information | Storage retention | 7d |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- `2d`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

監視基盤自体の設定もコード化しておけば、環境を作り直しても同じ監視が手に入る（80% 側の再利用）。

</details>

---

## M08: ログで調査する（Logging）

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `config.env` の `LOG_LEVEL` |
| ② 変更する値 | `info` → `debug`、エラーを起こして（ERROR_RATE）ログを絞り込む |
| ③ 予想される結果 | JSON ログを jq で絞り込める |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `kubectl -n mcp-dev logs deploy/hello-go --since=5m | jq -c 'select(.level=="ERROR")'`
2. 全 Pod 分: `kubectl -n mcp-dev logs -l app.kubernetes.io/name=hello-go --prefix --since=5m`
3. 直前に死んだコンテナ: `kubectl -n mcp-dev logs <pod> --previous`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | jq の出力 | status=500 のログだけが出る |

### ⑥ うまくいかない場合の調査

- `kubectl logs deploy/...` は 1 Pod 分しか出ない点に注意（ラベル指定で全 Pod）

### ⑦ 復旧方法

- `LOG_LEVEL=info`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

kubectl logs はノード上のファイルを読むため、Pod が消えるとログも消える。実務ではログ基盤（GKE なら Cloud Logging、OSS なら Loki）に集約する。JSON 構造化ログにしておくと、どの基盤でもフィールドで検索できる。

</details>

**🔁 発展（もう一周）**

- Future Improvements: Loki + Grafana を platform-addons に追加し、メトリクスとログを同じ画面で見る

---
