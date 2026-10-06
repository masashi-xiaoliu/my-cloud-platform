# Phase 3 — Kubernetes（Docker Image → kind）

## ゴール
ローカルの kind クラスタに手作業でデプロイし、Namespace / Deployment / ReplicaSet / Pod / Service / Ingress / ConfigMap / Secret の関係を `kubectl` で追える。

## 触るファイル
`scripts/kind-config.yaml`、`scripts/cluster-up.sh`、`kubernetes/base/*`、`kubernetes/overlays/local/*`

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | ターミナル | `make kind-up` | `kubectl get nodes` | control-plane と worker が `Ready` |
| 2 | ターミナル | `kubectl -n traefik get pods,svc` | 出力 | traefik Pod が Running、Service が NodePort 30080 |
| 3 | ターミナル | `kustomize build kubernetes/overlays/local` | 出力 | Namespace / ConfigMap / Secret / Service / Deployment / Ingress の YAML |
| 4 | ターミナル | `make local-deploy`（build → `kind load` → `kubectl apply -k`） | 出力 | 最後に `Hello from My Cloud Platform (local)` |
| 5 | ターミナル | `kubectl -n mcp-local get deploy,rs,pods,svc,ingress,cm,secret` | 出力 | 各リソースが 1 つずつ。Pod は `1/1 Running` |
| 6 | ブラウザ | http://hello-local.localtest.me | 画面 | メッセージが表示 |
| 7 | ターミナル | `kubectl -n mcp-local describe pod <pod>` | Events | `Scheduled → Pulled → Created → Started` |
| 8 | ターミナル | `kubectl -n mcp-local logs deploy/hello-go -f` → ブラウザをリロード | 出力 | アクセスログが流れる |

## 関係図（kubectl で辿る）

```text
Ingress (host: hello-local.localtest.me)
   └─▶ Service hello-go (port 80 → targetPort http)
          └─▶ EndpointSlice（Ready な Pod の IP:8080 一覧）  ← kubectl get endpointslices
                 └─▶ Pod hello-go-xxxxx-yyyyy                 ← kubectl get pods --show-labels
                        ▲ 作る・維持する
                    ReplicaSet hello-go-xxxxx                 ← kubectl get rs
                        ▲ テンプレート変更ごとに新しく作る
                    Deployment hello-go                       ← kubectl get deploy
                        ├── envFrom ConfigMap hello-go-config-<hash>
                        └── envFrom Secret    hello-go-secret-<hash>
```

## この Phase でやる Lab（SCL-Local で実行）
`kubernetes/overlays/local/` を編集して `kubectl apply -k` で反映：
T01（replicas）、T07（ConfigMap）、T13（Service port）、T14（Ingress host）、T11（Probe）、T05（OOMKilled）、I16 ①（Pod 削除）

## Checkpoint
- [ ] Pod を消しても復活する理由を ReplicaSet で説明できる
- [ ] ConfigMap を変えると Pod が入れ替わる理由（名前のハッシュ）を説明できる
