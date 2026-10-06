# Terraform Lab

Terraform の基本サイクル **plan → 確認 → apply → 実際のインフラ変化 → destroy → 再構築** を、ローカル（kind）で何度も回す。GCP に出る前にここで手を慣らす。

## 学習項目とこのリポジトリでの場所

| 概念 | どこにあるか |
|---|---|
| provider | `terraform/environments/local/main.tf` の `required_providers`（kind / helm） |
| resource | `terraform/modules/kind-cluster/main.tf` の `kind_cluster`、`platform-addons` の `helm_release` |
| variable | `terraform/environments/local/variables.tf` / `terraform.tfvars` |
| output | `terraform/environments/local/outputs.tf`（`terraform output` で表示） |
| locals | `terraform/modules/platform-addons/main.tf` の `admin_hosts` |
| state | `terraform/environments/local/terraform.tfstate`（GCP は GCS） |
| module | `terraform/modules/*` を environments から呼び出す |
| plan / apply / destroy | 下の Lab |

## plan の読み方

```text
  + create            新しく作る
  ~ update in-place   その場で変更（ダウンタイムなしのことが多い）
-/+ destroy and then create replacement   作り直し（⚠ データ・IP・ダウンタイムに注意）
  - destroy           削除
Plan: 1 to add, 2 to change, 0 to destroy.   ← 最後の 1 行を必ず読む
```

> **ルール: plan を読まずに apply しない。** `# forces replacement` と書かれた属性が作り直しの原因。


## 目次

- [TF-01: ノード数（worker_count）](#tf-01-ノード数worker_count)
- [TF-02: Kubernetes バージョン](#tf-02-kubernetes-バージョン)
- [TF-03: 機能フラグ（enable_monitoring）](#tf-03-機能フラグenable_monitoring)
- [TF-04: state を覗く](#tf-04-state-を覗く)
- [TF-05: チャートのバージョン固定（pin）](#tf-05-チャートのバージョン固定pin)
- [TF-06: ドリフト（手作業の変更）を検出する](#tf-06-ドリフト手作業の変更を検出する)
- [TF-07: destroy と再構築（作り直せることの証明）](#tf-07-destroy-と再構築作り直せることの証明)
- [TF-08: validation とモジュールの境界](#tf-08-validation-とモジュールの境界)

---

## TF-01: ノード数（worker_count）

> Phase 6 以降 ｜ 所要 20 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform/environments/local/terraform.tfvars` の `worker_count` |
| ② 変更する値 | `1` → `2` |
| ③ 予想される結果 | plan: kind_cluster が `-/+`（kind はノード追加をその場でできないため作り直し）。apply 後 `kubectl get nodes` が 3 行 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/local plan` を実行し、出力を実験記録にコピー
2. `# forces replacement` の行を探す
3. `terraform -chdir=terraform/environments/local apply` → `yes`
4. apply 後、Argo CD の root app を再登録（`kubectl apply -n argocd -f argocd/bootstrap/root.yaml`）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | plan の最終行 | `Plan: N to add, 0 to change, N to destroy` |
| ターミナル | `kubectl get nodes` | worker が 2 台 |

### ⑥ うまくいかない場合の調査

- apply が途中で失敗 → もう一度 plan して残差分を確認（Terraform は冪等）

### ⑦ 復旧方法

- `1` に戻して plan → apply

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

同じ『ノードを増やす』でも、kind は作り直し、GKE のノードプール（G01）はその場で変更。provider によって変更の影響が違うので、plan を読む習慣が必要。作り直しでクラスタ内の状態（Argo CD の登録など）が消えることも体験できる → だから GitOps で『Git から全部復元できる』ようにしておく。

</details>

---

## TF-02: Kubernetes バージョン

> Phase 6 以降 ｜ 所要 20 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` に `kubernetes_version = "v1.30.6"` |
| ② 変更する値 | `v1.31.2` → `v1.30.6` |
| ③ 予想される結果 | `-/+`（node_image の変更は作り直し） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/local plan` のみ（apply は任意）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | `node_image` の行 | `# forces replacement` |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

本番 GKE ではマイナーバージョンアップは in-place（ノードが順に入れ替わる）。PDB（T15）がここで効く。

</details>

---

## TF-03: 機能フラグ（enable_monitoring）

> Phase 6 以降 ｜ 所要 30 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `enable_monitoring` |
| ② 変更する値 | `false` → `true` |
| ③ 予想される結果 | `+ helm_release.kube_prometheus_stack[0]` が 1 つ追加。他は変わらない |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/local plan`
2. `terraform -chdir=terraform/environments/local apply`（数分かかる）
3. `terraform -chdir=terraform/environments/local output urls`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | 最終行 | `Plan: 1 to add, 0 to change, 0 to destroy` |
| ブラウザ | http://grafana.localtest.me | ログイン画面 |

### ⑥ うまくいかない場合の調査

- timeout → `kubectl -n monitoring get pods` で起動待ちの Pod を確認（メモリ不足が多い）

### ⑦ 復旧方法

- `false` で plan → `1 to destroy` を確認 → apply

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

`count = var.enable_monitoring ? 1 : 0` は Terraform の典型的な機能フラグ。アドレスが `[0]` 付きになる点に注意。

</details>

---

## TF-04: state を覗く

> Phase 6 以降 ｜ 所要 15 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | state |
| ② 変更する値 | （変更なし） |
| ③ 予想される結果 | Terraform が管理しているリソースの一覧と属性が見える |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/local state list`
2. `terraform -chdir=terraform/environments/local state show module.cluster.kind_cluster.this`
3. `terraform -chdir=terraform/environments/local output -json`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | state list | module.addons.helm_release.* などが並ぶ |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

state は『Terraform が作ったもの』と『実物』の対応表。消すと Terraform は何も知らない状態になり、次の apply で二重作成を試みる。GCP では GCS に置き、ロックで同時実行を防ぐ。state には秘密情報も平文で入るので Git に入れない（.gitignore 済み）。

</details>

---

## TF-05: チャートのバージョン固定（pin）

> Phase 6 以降 ｜ 所要 15 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `chart_versions` |
| ② 変更する値 | `argocd = "<helm search repo argo/argo-cd で確認した 1 つ前の版>"` |
| ③ 予想される結果 | `~ helm_release.argocd` の version が変わる（in-place） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `helm repo add argo https://argoproj.github.io/argo-helm && helm search repo argo/argo-cd --versions | head`
2. `terraform -chdir=terraform/environments/local plan`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | version 属性 | `"" -> "x.y.z"` または `"a" -> "b"` |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

バージョンを固定しないと、同じコードでも実行日によって違うものが入る（再現性がない）。固定 → 計画的に上げる、が運用の基本。

</details>

---

## TF-06: ドリフト（手作業の変更）を検出する

> Phase 6 以降 ｜ 所要 15 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | クラスタ直接 |
| ② 変更する値 | `helm -n kube-system uninstall metrics-server` |
| ③ 予想される結果 | plan に `+ helm_release.metrics_server[0]`（再作成）が出る |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. 上記コマンドを実行
2. `terraform -chdir=terraform/environments/local plan`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | 出力 | metrics_server が create |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- `terraform -chdir=terraform/environments/local apply`

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

plan は『コード』と『実物（refresh 結果）』の差を出す。手作業の変更はドリフトとして検出され、apply でコードの状態に戻される。Argo CD の selfHeal（C06）と同じ思想。

</details>

---

## TF-07: destroy と再構築（作り直せることの証明）

> Phase 6 以降 ｜ 所要 30 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | — |
| ② 変更する値 | destroy → apply → root app 登録 |
| ③ 予想される結果 | 15 分程度で元どおり（Git から全アプリが復元される） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `time terraform -chdir=terraform/environments/local destroy`
2. `time terraform -chdir=terraform/environments/local apply`
3. `kubectl apply -n argocd -f argocd/bootstrap/root.yaml`
4. Argo CD で全アプリが Synced / Healthy になるまでの時間を計測

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `./scripts/status.sh mcp-dev` | すべて正常、curl 200 |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

『壊しても作り直せる』ことが IaC + GitOps の最大の価値。再構築時間を実験記録に残すと、そのまま DR（災害復旧）の RTO の根拠になる。

</details>

---

## TF-08: validation とモジュールの境界

> Phase 6 以降 ｜ 所要 15 分 ｜ 環境: local

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `worker_count` |
| ② 変更する値 | `10` |
| ③ 予想される結果 | plan の前に validation エラー（`worker_count は 0〜4 にしてください`） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/local plan`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | エラー | variable validation のメッセージ |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- 戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

モジュールは『入力（variables）で安全に使い回せる部品』。validation でガードレールを入れておくと、使う人が事故を起こしにくい（80% 側の品質）。

</details>

**🔁 発展（もう一周）**

- prod 環境の main.tf と dev の main.tf を並べて、同じモジュールに何を変えて渡しているか表にする

---
