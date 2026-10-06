# Tuning Lab 04 — Image / Rolling Update / Probe / Shutdown

デプロイの中で何が起きているかを分解して観察する。Rollback は [Recovery Lab](../recovery/README.md)。

## 目次

- [T08: Docker Image のタグ（v1.0.0 → v1.1.0 → v999.0.0）](#t08-docker-image-のタグv100--v110--v99900)
- [T10: Rolling Update 戦略（maxSurge / maxUnavailable）](#t10-rolling-update-戦略maxsurge--maxunavailable)
- [T11: Probe（startup / readiness / liveness）](#t11-probestartup--readiness--liveness)
- [T12: Graceful shutdown（terminationGracePeriodSeconds）](#t12-graceful-shutdownterminationgraceperiodseconds)

---

## T08: Docker Image のタグ（v1.0.0 → v1.1.0 → v999.0.0）

> Phase 5 以降 ｜ 所要 30 分 ｜ 環境: dev

**What** — どのバージョンのアプリを動かすかを決める値。

**Why（実務でなぜ触るか）** — デプロイとは本質的に『動かすイメージのタグを変えること』。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/kustomization.yaml` の `images[0].newTag`（通常は deploy.yml が書き換える） |
| ② 変更する値 | ① Actions > Build を version=`v1.1.0` で実行（自動で dev に反映）② 手で PR を作り `newTag: v999.0.0` |
| ③ 予想される結果 | ① Pod が v1.1.0 に入れ替わる ② 新しい Pod が `ImagePullBackOff`。ただし古い Pod は残り、サービスは止まらない |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. ① GitHub > Actions > **Build** > Run workflow > version: `v1.1.0` > Run（[CI/CD Lab C04](../cicd/README.md) 参照）
2. ① Build 完了後、自動で Deploy ジョブが走り、main に `deploy(dev): hello-go v1.0.0 -> v1.1.0` コミットが入る
3. ② ブランチを切り、`newTag: v999.0.0` に書き換えて PR → Merge（※ deploy.yml を使うとガードレールで止まる。それも確認する）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GitHub > Packages > hello-go | タグ一覧 | ① `v1.1.0` が存在する |
| ターミナル | `curl http://hello-dev.localtest.me/` | ① `version=v1.1.0` |
| ターミナル | `kubectl -n mcp-dev get pods` | ② 新 Pod が `ErrImagePull` → `ImagePullBackOff`、旧 Pod は `Running` |
| Argo CD UI > `hello-go-dev` | Application | ② `Progressing` のまま（やがて Degraded） |
| GitHub > Actions > Deploy | image_tag=v999.0.0 で手動実行 | `Guardrail - image exists in registry` で ❌ |

### ⑥ うまくいかない場合の調査

- `kubectl -n mcp-dev describe pod <pod>` の Events: `Failed to pull image ... not found`
- → 詳細は [Incident Lab I02](../incident/I02-imagepullbackoff.md)

### ⑦ 復旧方法

- [Recovery Lab R01](../recovery/README.md)（Rollback workflow で revert）で復旧する

<details><summary>💡 Hint 1</summary>

maxUnavailable: 0 の設定が、②で『サービスが止まらなかった』理由に関係している。

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Rolling Update は新 Pod が Ready になってから旧 Pod を消す。`maxUnavailable: 0` のため、新 Pod が永遠に Ready にならなくても旧 Pod は残り続け、サービスは継続する（ただし更新は止まったまま）。`progressDeadlineSeconds`（既定 600 秒）を過ぎると Deployment は `ProgressDeadlineExceeded` になり Argo CD は Degraded を表示する。

</details>

**🔁 発展（もう一周）**

- `maxUnavailable: 1, maxSurge: 0` に変えて同じことをすると何が起きるか予想 → 実験（T10）

---

## T10: Rolling Update 戦略（maxSurge / maxUnavailable）

> Phase 5 以降 ｜ 所要 30 分 ｜ 環境: dev

**What** — 新旧 Pod の入れ替え方を決めるパラメータ。

**Why（実務でなぜ触るか）** — 無停止デプロイと、デプロイ中の一時的なリソース増のトレードオフ。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/base/deployment.yaml` の `strategy.rollingUpdate`（`★ LAB T10`）※ base を変えると全環境に影響する。dev で試すなら overlay の patch に strategy を追加する |
| ② 変更する値 | replicas=4 の状態で ① `maxSurge: 1, maxUnavailable: 0`（既定）② `maxSurge: 0, maxUnavailable: 1` ③ `type: Recreate` |
| ③ 予想される結果 | ① Pod 数は最大 5、Ready は常に 4 ② Pod 数は最大 4、Ready は一時的に 3 ③ 全 Pod が一度消えてから作られる（ダウンタイムあり） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. 各設定で APP_MESSAGE を変えて（T07）更新を発生させる
2. 別ターミナルで `while true; do curl -s -o /dev/null -w '%{http_code}\n' http://hello-dev.localtest.me/; sleep 0.2; done` を流し続ける

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get pods -w` | Pod の増減の順番が予想どおり |
| ターミナル | `kubectl -n mcp-dev rollout status deploy/hello-go` | `successfully rolled out` |
| curl ループ | ステータスコードの列 | ①② は 200 のみ、③ は 502/503 が混ざる |
| Grafana | App version running | 新旧バージョンが重なる時間帯がある（①②） |

### ⑥ うまくいかない場合の調査

- ① でも 502 が出る → readinessProbe と graceful shutdown（T12）が関係

### ⑦ 復旧方法

- 既定値（①）に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

maxSurge は『一時的に何個多く作ってよいか』、maxUnavailable は『一時的に何個減ってよいか』。前者はリソース（＝ノード余力）を、後者は可用性を消費する。Recreate はスキーマ変更などで新旧の同時稼働が許されない場合に使う。

</details>

**🔁 発展（もう一周）**

- `kubectl -n mcp-dev rollout history deploy/hello-go` で ReplicaSet の世代を見る

---

## T11: Probe（startup / readiness / liveness）

> Phase 5 以降 ｜ 所要 30 分 ｜ 環境: dev

**What** — Kubernetes が Pod の状態を判断するためのヘルスチェック。

**Why（実務でなぜ触るか）** — Probe の設定ミスは『動いているのにトラフィックが来ない』『正常なのに再起動される』障害の常連。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/base/deployment.yaml` の probes（`★ LAB T11`）と `kubernetes/overlays/dev/config.env` の `STARTUP_DELAY_SECONDS` |
| ② 変更する値 | ① `STARTUP_DELAY_SECONDS=30` ② ①のまま startupProbe の `failureThreshold: 30 → 5` ③ readinessProbe の path を `/ready`（I05） |
| ③ 予想される結果 | ① 起動に 30 秒かかるが最終的に Ready ② 10 秒（2s×5）で startup 失敗 → 再起動ループ ③ Running だが 0/1 Ready |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get pods -w` | READY 列と RESTARTS 列の変化 |
| ターミナル | `kubectl -n mcp-dev describe pod <pod>` | Events: `Startup probe failed` / `Readiness probe failed` |
| ターミナル | `kubectl -n mcp-dev get endpointslices` | ③ Ready でない Pod は Endpoint に含まれない |

### ⑥ うまくいかない場合の調査

- readiness 失敗 = トラフィックが来ないだけ（再起動しない）、liveness/startup 失敗 = 再起動される

### ⑦ 復旧方法

- `./scripts/reset.sh dev`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

startupProbe が成功するまで liveness/readiness は実行されない（起動の遅いアプリを誤って殺さないため）。readiness は『トラフィックを受けてよいか』、liveness は『プロセスが壊れていないか（再起動すべきか）』。liveness に DB 接続確認など外部依存を入れると、DB 障害時に全 Pod が再起動ループになる、というのが実務の有名な落とし穴。

</details>

**🔁 発展（もう一周）**

- livenessProbe の `failureThreshold` と `periodSeconds` から『異常発生から再起動までの最大時間』を計算する

---

## T12: Graceful shutdown（terminationGracePeriodSeconds）

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

**What** — Pod 削除時に SIGTERM を送ってから強制終了（SIGKILL）するまでの猶予。

**Why（実務でなぜ触るか）** — デプロイのたびに処理中のリクエストが切れる、という地味だが重要な品質問題。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/base/deployment.yaml` の `terminationGracePeriodSeconds`（`★ LAB T12`） |
| ② 変更する値 | `30` → `1`。`LATENCY_MS=3000` にした状態でデプロイ中にリクエストを送る |
| ③ 予想される結果 | 1 秒では処理中のリクエストが途中で切れる（curl がエラー） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `LATENCY_MS=3000` で反映後、`while true; do curl -s -m 10 -o /dev/null -w '%{http_code}\n' http://hello-dev.localtest.me/; done` を流しつつ別の変更（T07）をデプロイ

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev logs <旧 pod> -f` | `shutdown signal received` → `bye` のログ |
| curl ループ | ステータス | grace=1 のとき 502 / 000（接続断）が混ざる |

### ⑥ うまくいかない場合の調査

- アプリが SIGTERM を処理しているか（main.go の signal.Notify）

### ⑦ 復旧方法

- `30` に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Pod 削除時、kubelet は SIGTERM を送ると同時に Endpoint から Pod を外す。アプリは readiness を落として新規受付を止め、処理中のリクエストを終えてから終了する。猶予が短いと処理中でも SIGKILL される。

</details>

**🔁 発展（もう一周）**

- preStop フック（`sleep 5`）を追加して、Endpoint 削除の伝搬遅延による 502 を減らす

---
