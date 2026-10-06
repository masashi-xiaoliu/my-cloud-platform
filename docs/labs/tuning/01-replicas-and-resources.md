# Tuning Lab 01 — Replicas と Resources

Pod の数と、CPU / メモリの requests・limits を変えて、スケジューリング・性能・安定性の変化を観察する。

## 目次

- [T01: Replica 数（replicas）](#t01-replica-数replicas)
- [T02: CPU requests](#t02-cpu-requests)
- [T03: CPU limits と throttling](#t03-cpu-limits-と-throttling)
- [T04: Memory requests](#t04-memory-requests)
- [T05: Memory limits と OOMKilled](#t05-memory-limits-と-oomkilled)

---

## T01: Replica 数（replicas）

> Phase 5 以降 ｜ 所要 15 分 ｜ 環境: dev

**What** — Deployment が維持する Pod の数。

**Why（実務でなぜ触るか）** — アクセス増への対応・可用性（1 つ落ちても他が応答）の最も基本的なレバー。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/patch-deployment.yaml` の `spec.replicas`（`# ★ LAB T01` の行） |
| ② 変更する値 | `1` → `3`（その後 `3` → `10`、最後に `1` に戻す） |
| ③ 予想される結果 | Pod が 3 個になる。ReplicaSet は新しく作られず、既存 ReplicaSet の DESIRED が 3 になる。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. 別ターミナルで `kubectl -n mcp-dev get pods -w` を実行したまま Merge すると、増える瞬間が見える

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GitHub > Pull requests | PR の Checks 欄 | CI のすべての Job が ✅ |
| Argo CD UI > `hello-go-dev` | アプリのツリー表示 | Synced / Healthy、Pod のアイコンが 3 つ |
| ターミナル | `kubectl -n mcp-dev get deploy,rs,pods` | `hello-go` が `3/3` READY、Pod 3 行が `Running` |
| ターミナル | `for i in $(seq 10); do curl -s http://hello-dev.localtest.me/; done` | 応答の `pod=` が複数種類（負荷分散されている） |
| Grafana（Phase 8〜） | Dashboard: My Cloud Platform / hello-go > Ready Pods | 1 → 3 に階段状に増える |

### ⑥ うまくいかない場合の調査

- Argo CD が OutOfSync のまま → `Refresh` を押す / Application の `Last Sync` のエラーを読む
- Pod が `Pending` → `kubectl -n mcp-dev describe pod <pod>` の Events（ノードのリソース不足 = I08 と同じ）
- 10 にすると一部 Pending になることがある → それが kind ノード 1〜2 台の『容量の限界』。T02 につながる

### ⑦ 復旧方法

- `replicas: 1` に戻して同じ手順で Merge
- `kubectl scale` で直しても Argo CD の selfHeal が Git の値に戻す点に注意（C06 で体験）

<details><summary>💡 Hint 1</summary>

Deployment → ReplicaSet → Pod の 3 階層を `kubectl get deploy,rs,pods` で同時に見ると関係がわかる。

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

replicas は ReplicaSet の DESIRED にそのまま伝わる。Pod テンプレート（image や env）が変わらないので新しい ReplicaSet は作られず、既存 ReplicaSet が Pod を追加するだけ。Service は label selector で Pod を探すため、新しい Pod が Ready になった時点で自動的に負荷分散対象になる。

</details>

**🔁 発展（もう一周）**

- `kubectl -n mcp-dev scale deploy hello-go --replicas=5` を手で実行 → 数十秒後に Argo CD が 1 に戻す様子を観察（GitOps では Git が正）
- replicas=10 のとき `kubectl describe nodes | grep -A5 'Allocated resources'` で予約済み CPU を確認

---

## T02: CPU requests

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

**What** — スケジューラが Pod を配置する際に「このくらい CPU を使う」と予約する量。`1000m = 1 コア`。

**Why（実務でなぜ触るか）** — ノードに何 Pod 載るか＝必要ノード数＝クラウド費用を決める。小さすぎると過密、大きすぎると無駄。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/patch-deployment.yaml` の `resources.requests.cpu`（`★ LAB T02`） |
| ② 変更する値 | `50m` → `500m`。さらに replicas を `5` にして再度確認 |
| ③ 予想される結果 | 1 Pod の挙動は変わらない。replicas を増やすと、ノードの割当可能 CPU を超えた分が `Pending` になる。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get pod -l app.kubernetes.io/name=hello-go -o jsonpath='{.items[*].spec.containers[0].resources}'` | requests.cpu が `500m` |
| ターミナル | `kubectl describe nodes | grep -A8 'Allocated resources'` | CPU Requests の % が増えている |
| ターミナル | `kubectl -n mcp-dev get pods`（replicas=5 のとき） | 一部が `Pending` |
| ターミナル | `kubectl -n mcp-dev describe pod <Pending の pod>` | Events に `FailedScheduling ... Insufficient cpu` |

### ⑥ うまくいかない場合の調査

- Pending の理由は必ず `describe pod` の Events に書いてある
- `kubectl top nodes` は『実使用量』、`describe nodes` は『予約量』。両者の違いを比べる

### ⑦ 復旧方法

- `50m`・replicas `1` に戻して Merge

<details><summary>💡 Hint 1</summary>

requests は『実際の使用量』ではなく『予約』。CPU をほとんど使わない Pod でも予約分は他の Pod に貸せない。

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Kubernetes のスケジューラは実使用量ではなく **requests の合計** がノードの Allocatable を超えないように配置する。したがって requests を大きくすると、アプリが暇でもノードに載る Pod 数が減る。逆に requests を実態より小さくすると過密配置になり、全 Pod が同時に CPU を使ったときに遅くなる。適正値は Grafana の CPU usage（T03 / M02）の p95 程度を目安に決める。

</details>

**🔁 発展（もう一周）**

- requests と limits を同値にすると QoS クラスが `Guaranteed` になる。`kubectl get pod -o jsonpath='{.items[0].status.qosClass}'` で確認

---

## T03: CPU limits と throttling

> Phase 8 以降 ｜ 所要 25 分 ｜ 環境: dev

**What** — コンテナが使える CPU の上限。超えようとすると殺されずに **throttling（待たされる）** される。

**Why（実務でなぜ触るか）** — 1 つの Pod が CPU を食い尽くして同じノードの他 Pod を巻き込むのを防ぐ。一方で厳しすぎると応答が遅くなる。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/patch-deployment.yaml` の `resources.limits.cpu`（`★ LAB T03`） |
| ② 変更する値 | `200m` → `50m`（極端に小さく）→ 負荷をかける → `1000m` に変えて同じ負荷 |
| ③ 予想される結果 | 50m では /burn の応答時間が大きく伸び、Grafana の CPU throttling が上がる。1000m では短くなる。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. `curl -s -w '%{time_total}s\n' 'http://hello-dev.localtest.me/burn?ms=200'` を 5 回実行して時間を記録
3. `./scripts/load.sh mcp-dev 2` で負荷をかけ、Grafana を見る

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `curl -w '%{time_total}'` の結果 | 50m のとき: ms=200 の処理に 200ms を大きく超える時間がかかる |
| Grafana | CPU usage vs requests / limits | usage が limit の線で頭打ちになる |
| Grafana | CPU throttling | 50m のときに高い値 |
| ターミナル | `kubectl -n mcp-dev get pods` | RESTARTS は増えない（CPU 超過では殺されない） |

### ⑥ うまくいかない場合の調査

- Grafana にデータがない → Phase 8 の monitoring component を有効化したか確認（M01）
- `kubectl -n mcp-dev top pods` で実使用量を直接見る

### ⑦ 復旧方法

- `200m` に戻して Merge

<details><summary>💡 Hint 1</summary>

/burn?ms=200 は『CPU を 200ms 分回す』処理。CPU が 0.05 コアしか使えないと、壁時計ではどれくらいかかる?

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

CPU limit は CFS (Completely Fair Scheduler) の quota として実装され、100ms の周期ごとに `limit × 100ms` だけ CPU を使える。50m なら 100ms 中 5ms しか使えないので、200ms 分の計算に壁時計で約 4 秒かかる。メモリと違い CPU は『圧縮可能な資源』なので、超えても殺されずに遅くなるだけ。これが『レイテンシ悪化の原因が CPU limit だった』という実務でよくある障害の正体。

</details>

**🔁 発展（もう一周）**

- limits.cpu を削除（上限なし）した場合と比較する。どちらが良いかはチームでも議論が分かれる → docs/adr に自分の結論を書く

---

## T04: Memory requests

> Phase 5 以降 ｜ 所要 15 分 ｜ 環境: dev

**What** — スケジューラが予約するメモリ量。

**Why（実務でなぜ触るか）** — CPU と同様にノード集約度とコストを決める。メモリは不足すると OOM に直結するため CPU より慎重に決める。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/patch-deployment.yaml` の `resources.requests.memory`（`★ LAB T04`） |
| ② 変更する値 | `32Mi` → `128Mi` → `512Mi`（limits も同時に `512Mi` 以上へ。requests > limits は不正） |
| ③ 予想される結果 | Pod は問題なく動く。ノードの Memory Requests の % が増える。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl describe nodes | grep -A8 'Allocated resources'` | Memory Requests が増えている |
| GitHub > Actions > CI > manifests | requests > limits にした場合 | kubeconform は通るが Argo CD の Sync で `Invalid value` エラー |

### ⑥ うまくいかない場合の調査

- `spec.containers[0].resources.requests: Invalid value: "512Mi": must be less than or equal to memory limit` → requests ≤ limits のルール

### ⑦ 復旧方法

- `32Mi` に戻して Merge

<details><summary>💡 Hint 1</summary>

わざと requests を limits より大きくしてみよう。CI は通るのに、どこで失敗する?

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

requests > limits は API Server のバリデーションで拒否される。CI の kubeconform はスキーマ（型）しか見ないため検出できず、Argo CD の Sync（= API Server への適用）時に初めて失敗する。『CI が緑でも CD で落ちる』典型例。CI に検査を追加して防ぐのが Platform の仕事（scripts/check-manifests.py に追加してみよう）。

</details>

**🔁 発展（もう一周）**

- scripts/check-manifests.py に『requests <= limits』のチェックを追加し、PR で CI が赤くなることを確認する

---

## T05: Memory limits と OOMKilled

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

**What** — コンテナが使えるメモリの上限。超えると **カーネルにプロセスを殺される（OOMKilled）**。

**Why（実務でなぜ触るか）** — メモリリークした Pod がノード全体を道連れにしないための安全装置。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/config.env` の `MEMORY_BALLAST_MB` と `kubernetes/overlays/dev/patch-deployment.yaml` の `limits.memory` |
| ② 変更する値 | ① `MEMORY_BALLAST_MB=0` → `40`（limit 64Mi 以内）② `40` → `100`（limit 超え）③ limits.memory を `256Mi` に上げる |
| ③ 予想される結果 | ① 正常 ② Pod が OOMKilled → 再起動を繰り返す ③ 再び正常 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. 各段階ごとに PR を分けて Merge し、毎回観察する

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get pods -w` | ② で STATUS が `OOMKilled` → `CrashLoopBackOff`、RESTARTS が増える |
| ターミナル | `kubectl -n mcp-dev describe pod <pod>` | `Last State: Terminated  Reason: OOMKilled  Exit Code: 137` |
| ターミナル | `kubectl -n mcp-dev logs <pod> --previous` | `memory ballast allocated` の直後でログが途切れる |
| Grafana | Memory working set vs limit / Container restarts | limit の線に張り付いた後に restarts が増える |

### ⑥ うまくいかない場合の調査

- Exit Code 137 = 128 + 9 (SIGKILL)。アプリのエラーではなく外部から殺された印
- ログにエラーが出ないのが OOM の特徴（アプリは何も言えずに殺される）

### ⑦ 復旧方法

- `MEMORY_BALLAST_MB=0` に戻す、または limit を上げて Merge
- 本番なら：まず limit を上げて復旧 → 後でリークの原因を調査、の順

<details><summary>💡 Hint 1</summary>

`kubectl describe pod` の `Last State` を見る。

</details>

<details><summary>💡 Hint 2</summary>

Exit Code 137 を検索してみよう。

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

memory は CPU と違い『圧縮不能な資源』で、上限を超えて待たせることができないため、cgroup の OOM killer がプロセスを SIGKILL する。kubelet は restartPolicy に従って再起動するが、起動のたびに同じ量を確保するので再び殺され、再起動間隔が指数的に延びる（CrashLoopBackOff）。

</details>

**🔁 発展（もう一周）**

- requests=limits（Guaranteed）と requests<limits（Burstable）でノード逼迫時にどちらが先に退避されるか調べる

---
