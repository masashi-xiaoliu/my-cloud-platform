# Tuning Lab 05 — Network（Service / Ingress / DNS / NetworkPolicy）

『繋がらない』を外側から一段ずつ切り分けられるようになる。Firewall / HTTPS は [GCP Lab](../gcp/README.md)。

## 目次

- [T13: Service port / targetPort](#t13-service-port--targetport)
- [T14: Ingress（host / ingressClassName）](#t14-ingresshost--ingressclassname)
- [T16: NetworkPolicy（通信の許可制）](#t16-networkpolicy通信の許可制)
- [T17: DNS と外部 API（UPSTREAM_URL）](#t17-dns-と外部-apiupstream_url)

---

## T13: Service port / targetPort

> Phase 3 以降 ｜ 所要 25 分 ｜ 環境: dev

**What** — Service が受けるポート（port）と、転送先の Pod のポート（targetPort）。

**Why（実務でなぜ触るか）** — 『Pod は動いているのに繋がらない』の原因の大半はポートかラベルの不一致。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/base/service.yaml` の `port` / `targetPort`（`★ LAB T13`）。dev だけで試すなら `python3 scripts/chaos.py inject I03` |
| ② 変更する値 | ① `port: 80 → 8080` ② `targetPort: http → 9090` |
| ③ 予想される結果 | ① クラスタ内から `hello-go:80` では繋がらず `hello-go:8080` で繋がる。Ingress は port 名で参照しているので外部からは繋がる ② すべての経路で繋がらない |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）
2. クラスタ内からの確認用: `kubectl -n mcp-dev run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| tmp Pod 内 | `wget -qO- http://hello-go:80/` と `:8080/` | ① どちらが成功するか |
| ターミナル | `kubectl -n mcp-dev describe svc hello-go` | `Port` / `TargetPort` / `Endpoints` の値 |
| ブラウザ | http://hello-dev.localtest.me | ② 502 Bad Gateway / 接続エラー |

### ⑥ うまくいかない場合の調査

- `kubectl -n mcp-dev get endpointslices -o wide` で Endpoint の IP:Port を確認
- `kubectl -n mcp-dev port-forward pod/<pod> 8080:8080` で Pod に直接繋がるか → 繋がれば Service 側の問題

### ⑦ 復旧方法

- 元に戻す / `./scripts/reset.sh dev`

<details><summary>💡 Hint 1</summary>

切り分けは『外から順に』: Ingress → Service → Endpoint → Pod。どこまで届いているか一段ずつ確かめる。

</details>

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Service は (1) selector で Pod を選び (2) Endpoint（Pod IP:targetPort）の一覧を作り (3) `ClusterIP:port` への通信をそこへ転送する。targetPort が Pod の実際の待受ポートと違えば Endpoint はあっても接続は拒否される。Ingress が `port.name: http` で参照しているため ① では外部経路は壊れない（名前参照の利点）。

</details>

**🔁 発展（もう一周）**

- Ingress の backend を `port.number: 80` に書き換えて ① をやり直すと？

---

## T14: Ingress（host / ingressClassName）

> Phase 3 以降 ｜ 所要 20 分 ｜ 環境: dev

**What** — HTTP のホスト名・パスでクラスタ外からのリクエストを Service に振り分けるルール。

**Why（実務でなぜ触るか）** — 複数アプリ・複数ドメインを 1 つの入口で捌く、Web 案件で必ず触る部分。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/patch-ingress.yaml` の `value`（host）、`kubernetes/base/ingress.yaml` の `ingressClassName` |
| ② 変更する値 | ① host を `hello-dev.localtest.me` → `api-dev.localtest.me` ② ingressClassName を `traefik` → `nginx`（I10） |
| ③ 予想される結果 | ① 旧ホスト名は 404、新ホスト名で応答 ② どのホスト名でも 404 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get ingress` | HOSTS / CLASS 列 |
| ターミナル | `curl -i http://api-dev.localtest.me/` | ① 200 |
| ターミナル | `curl -i -H 'Host: hello-dev.localtest.me' http://127.0.0.1/` | Host ヘッダで振り分けていることの確認 |

### ⑥ うまくいかない場合の調査

- `kubectl get ingressclass` に存在するクラスか
- `kubectl -n traefik logs deploy/traefik` にエラーがないか

### ⑦ 復旧方法

- `./scripts/reset.sh dev`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Ingress リソースは『ルール』でしかなく、実際に通信を捌くのは Ingress Controller（ここでは Traefik）。Controller は自分の IngressClass が指定された Ingress だけを読むため、存在しないクラスを書くと誰にも処理されず 404 になる。*.localtest.me は常に 127.0.0.1 を返す公開 DNS 名で、kind の 80 番 → Traefik に届く。

</details>

**🔁 発展（もう一周）**

- GCP では Cloud DNS に A レコードを作り、本物のドメインで同じことをする（G 発展）

---

## T16: NetworkPolicy（通信の許可制）

> Phase 7 以降 ｜ 所要 30 分 ｜ 環境: GKE（または Calico 入り kind）

**What** — Pod 間通信をラベルで許可・拒否するファイアウォール。

**Why（実務でなぜ触るか）** — 『同じクラスタ内なら何でも通る』状態は侵害時の横展開を許す。ゼロトラストの第一歩。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/kustomization.yaml` の components に `../../components/network-policy` を追加 |
| ② 変更する値 | 有効化 → `mcp-dev` 内の tmp Pod から hello-go へアクセス |
| ③ 予想される結果 | Traefik 経由（外部）は通るが、同じ Namespace の tmp Pod からは繋がらない |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| tmp Pod 内 | `wget -qO- -T 3 http://hello-go/` | タイムアウト |
| ブラウザ | Ingress のホスト名 | 200 |

### ⑥ うまくいかない場合の調査

- kind 標準 CNI では効かない（全部通る）→ これ自体が学び。GKE Dataplane V2 で確認

### ⑦ 復旧方法

- components から外す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

NetworkPolicy は CNI プラグインが実装する。ポリシーを書いても CNI が対応していなければ何も起きない（エラーにもならない）。『設定したのに効いていない』を検証で見つけることが重要。

</details>

**🔁 発展（もう一周）**

- 監視（Prometheus）からのスクレイプが止まっていないか Grafana で確認する（monitoring Namespace を許可している理由）

---

## T17: DNS と外部 API（UPSTREAM_URL）

> Phase 5 以降 ｜ 所要 25 分 ｜ 環境: dev

**What** — クラスタ内 DNS（`<svc>.<ns>.svc.cluster.local`）と外部 API 呼び出し。

**Why（実務でなぜ触るか）** — Case Study CR-4（外部 API 連携）の土台。名前解決・タイムアウト・認証の失敗を切り分けられるようにする。

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/config.env` の `UPSTREAM_URL` |
| ② 変更する値 | ① `http://hello-go.mcp-staging.svc.cluster.local/healthz`（別 Namespace の Service）② `http://hello-go.mcp-stg.svc.cluster.local/healthz`（typo）③ `https://httpbin.org/status/503` |
| ③ 予想される結果 | ① `/upstream` が `upstream ok` ② `no such host` で 502 ③ 503 を MAX_RETRY 回リトライして 502 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順 1〜7 で変更を dev に反映する（ブランチ作成 → 変更 → PR → CI 緑 → Merge → Argo CD Sync）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `curl http://hello-dev.localtest.me/upstream` | 各ケースの応答 |
| ターミナル | `kubectl -n mcp-dev logs deploy/hello-go \| grep upstream` | エラーの種類（DNS / 接続 / HTTP ステータス） |
| tmp Pod 内 | `nslookup hello-go.mcp-staging.svc.cluster.local` | IP が返る / NXDOMAIN |

### ⑥ うまくいかない場合の調査

- DNS か通信かを分ける: `nslookup` が成功して `wget` が失敗 → 通信（NetworkPolicy / Firewall / ポート）
- `kubectl -n kube-system get pods -l k8s-app=kube-dns` で CoreDNS が動いているか

### ⑦ 復旧方法

- `UPSTREAM_URL=` に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Pod の /etc/resolv.conf には `search <ns>.svc.cluster.local svc.cluster.local ...` が設定されているため、同じ Namespace なら `hello-go` だけで、別 Namespace なら `hello-go.mcp-staging` で解決できる。エラーメッセージの `no such host`（DNS）/ `connection refused`（ポート）/ `timeout`（経路・FW）/ HTTP 5xx（相手のアプリ）を見分けることがネットワーク調査の基本。

</details>

**🔁 発展（もう一周）**

- 外向き通信を NetworkPolicy の Egress で制限し、③ が失敗するようにする

---
