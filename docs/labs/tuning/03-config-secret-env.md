# Tuning Lab 03 — ConfigMap / Secret / 環境変数

イメージを作り直さずに挙動を変える『設定』の扱いを学ぶ。

## 目次

- [T07: ConfigMap（APP_MESSAGE）](#t07-configmapapp_message)
- [T09: 環境変数（LOG_LEVEL / REQUEST_TIMEOUT / MAX_RETRY）](#t09-環境変数log_level--request_timeout--max_retry)
- [T18: Secret（API_KEY）](#t18-secretapi_key)

---

## T07: ConfigMap（APP_MESSAGE）

> Phase 5 以降 ｜ 所要 15 分 ｜ 環境: dev

**What** — アプリの設定を、イメージを作り直さずに外から注入する仕組み。

**Why（実務でなぜ触るか）** — 環境ごとに異なる設定（接続先、機能フラグ、文言）をコードと分離する。12-Factor App の基本。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/config.env` の `APP_MESSAGE`（`★ LAB T07`） |
| ② 変更する値 | `Hello from My Cloud Platform (dev)` → `Hello Cloud Engineer` |
| ③ 予想される結果 | イメージは変わらないのに、curl の応答が変わる。Pod が新しいものに入れ替わる（名前が変わる）。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. Merge 前に `kubectl -n mcp-dev get cm` で ConfigMap の名前（末尾のハッシュ）をメモしておく

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Argo CD UI > `hello-go-dev` | アプリのツリー | 新しい ConfigMap（`hello-go-config-<新ハッシュ>`）と新しい ReplicaSet が現れる |
| ターミナル | `kubectl -n mcp-dev get cm,rs` | ConfigMap 名のハッシュが変わり、ReplicaSet が 1 つ増えている |
| ターミナル | `curl http://hello-dev.localtest.me/` | `Hello Cloud Engineer (version=..., pod=...)` |
| ターミナル | `curl http://hello-dev.localtest.me/info` | `message` が新しい値 |

### ⑥ うまくいかない場合の調査

- 応答が変わらない → Argo CD が Synced か / 古い Pod がまだ残っていないか（`kubectl get pods`）
- ConfigMap は変わったのに Pod が古いまま → 環境変数は Pod 起動時にしか読まれない（下の Answer 参照）

### ⑦ 復旧方法

- 元の文言に戻して Merge

<details><summary>💡 Hint 1</summary>

`kustomize build kubernetes/overlays/dev | grep hello-go-config` を変更前後で実行して比べてみよう。

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

環境変数として注入された ConfigMap の値は **コンテナ起動時に 1 回だけ** 読まれる。ConfigMap を書き換えただけでは動いている Pod は古い値のまま。このリポジトリでは kustomize の configMapGenerator が内容のハッシュを名前に付けるため、内容が変わる → 名前が変わる → Deployment の Pod テンプレートが変わる → Rolling Update が起きる、という連鎖で自動的に反映される。

</details>

**🔁 発展（もう一周）**

- `kubectl -n mcp-dev edit cm <name>` で直接書き換えるとどうなるか？（Pod は変わらない、Argo CD が元に戻す）

---

## T09: 環境変数（LOG_LEVEL / REQUEST_TIMEOUT / MAX_RETRY）

> Phase 5 以降 ｜ 所要 30 分 ｜ 環境: dev

**What** — アプリの挙動を変えるチューニング用パラメータ。

**Why（実務でなぜ触るか）** — タイムアウトとリトライは実務で最も事故の多い設定。ログレベルは障害調査時に上げ下げする。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/config.env` |
| ② 変更する値 | ① `LOG_LEVEL=debug` → `warn` ② `LATENCY_MS=0` → `3000` かつ `REQUEST_TIMEOUT=5s` → `1s` ③ `UPSTREAM_URL=http://does-not-exist.mcp-dev.svc.cluster.local` かつ `MAX_RETRY=3` → `0` |
| ③ 予想される結果 | ① 通常のアクセスログが出なくなる ② `/` が 503 `request timeout` を返す ③ `/upstream` が 502。MAX_RETRY=3 のときはログに 4 回の試行が出て応答が遅い、0 なら 1 回で即失敗。 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. 各変更ごとに `kubectl -n mcp-dev logs deploy/hello-go -f` を見ながら curl する

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev logs deploy/hello-go --tail=20` | ① warn 以上のログだけになる |
| ターミナル | `curl -i http://hello-dev.localtest.me/` | ② `HTTP/1.1 503`、本文 `request timeout` |
| ターミナル | `time curl -s http://hello-dev.localtest.me/upstream` | ③ `upstream failed`。MAX_RETRY による試行回数と所要時間の差 |
| ターミナル | `kubectl -n mcp-dev logs deploy/hello-go | grep upstream` | ③ `attempt` が 1..(MAX_RETRY+1) |

### ⑥ うまくいかない場合の調査

- 不正値（例: `REQUEST_TIMEOUT=abc`）を入れると Pod が起動しない → I12 と同じ。`logs --previous`

### ⑦ 復旧方法

- `./scripts/reset.sh dev` → commit → PR → Merge

<details><summary>💡 Hint 1</summary>

タイムアウトが『上流の処理時間』より短いと何が起きる?

</details>

<details><summary>💡 Hint 2</summary>

リトライを増やすと成功率は上がるが、何が悪化する?

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

タイムアウトは『待つ上限』、リトライは『諦めるまでの回数』。リトライを増やすと一時的な失敗には強くなるが、相手が本当に落ちているときは応答時間が `(試行回数) × (タイムアウト + 待機)` まで延び、さらに上流に負荷を倍増させる（リトライストーム）。実務では『呼び出し側のタイムアウト > 呼び出される側のタイムアウト × リトライ回数』にならないよう全体で設計する。

</details>

**🔁 発展（もう一周）**

- Ingress（Traefik）側のタイムアウトとアプリの REQUEST_TIMEOUT のどちらが先に効くか調べる

---

## T18: Secret（API_KEY）

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

**What** — パスワードや API キーなど秘匿情報を注入する仕組み。

**Why（実務でなぜ触るか）** — 秘密情報をイメージやコードに埋め込まない。ただし Kubernetes の Secret は base64 で **暗号化ではない** 点を理解する。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/secret.env` の `API_KEY` / `kubernetes/overlays/dev/config.env` の `REQUIRE_API_KEY` |
| ② 変更する値 | ① `API_KEY` の値を変更 ② `REQUIRE_API_KEY=true` にして `API_KEY=`（空） |
| ③ 予想される結果 | ① `/info` の `api_key_set: true` のまま（値は表示されない）、Pod は入れ替わる ② Pod が起動失敗 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `curl http://hello-dev.localtest.me/info` | `api_key_set` が true/false で変化。値そのものは出ない |
| ターミナル | `kubectl -n mcp-dev get secret -o yaml \| grep API_KEY` | base64 文字列が見える |
| ターミナル | `echo <その文字列> \| base64 -d` | 平文に戻る ＝ 暗号化ではない |

### ⑥ うまくいかない場合の調査

- ② → `kubectl -n mcp-dev logs <pod> --previous` に `API_KEY is required` → I06

### ⑦ 復旧方法

- `./scripts/reset.sh dev` → Merge

<details><summary>💡 Hint 1</summary>

Secret を Git に置くこのリポジトリの方式は『学習用』。本番ではどうする? → docs/adr/0006-secrets.md

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Secret は etcd 上で（設定次第で）暗号化されうるが、API 上は base64 エンコードされているだけで、`get secret` 権限があれば誰でも読める。そのため (1) RBAC で読める人を絞る (2) Git に平文を置かない（Sealed Secrets / External Secrets + Secret Manager）(3) ログや /info に値を出さない、の 3 点が実務の基本。

</details>

**🔁 発展（もう一周）**

- GCP Phase で Secret Manager + External Secrets Operator を導入し、Git から secret.env を消す（Future Improvements）

---
