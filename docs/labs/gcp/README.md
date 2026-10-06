# GCP Lab

ローカルで回したサイクルを GCP（GKE）で再現する。**コスト管理も訓練対象**。

## ⚠ 課金対象になりうるもの（作ったら必ず消す）

| リソース | 課金の目安となる要素 | このリポジトリの既定 | 削除方法 |
|---|---|---|---|
| GKE クラスタ管理料 | クラスタ 1 つごと・時間課金（※ 無料枠で 1 ゾーンクラスタ分が相殺される場合あり。最新の料金ページで確認） | ゾーンクラスタ 1 つ | `terraform destroy` |
| ノード（Compute Engine VM） | マシンタイプ × 台数 × 時間 | e2-medium × 1、Spot | 同上 |
| 永続ディスク | GB × 時間（ノードのブートディスク、PVC） | 30GB pd-standard | 同上 / PVC は先に削除 |
| ロードバランサ | 転送ルール × 時間 + 通信量 | Traefik の LoadBalancer 1 つ | **Namespace / Service を先に消す** |
| Cloud NAT | ゲートウェイ × 時間 + 通信量 | 無効（private_nodes=false） | 同上 |
| Cloud SQL | インスタンス × 時間（停止中もディスク課金） | 無効 | `enable_database=false` → apply |
| Artifact Registry / GCS | 保存量 | クリーンアップポリシーあり | 同上 |
| 外部 IP | 未使用の静的 IP | 作らない | — |

**実験の 1 サイクル = apply → 実験 → destroy を同じ日のうちに終える** を原則にする。

## 事前準備（1 回だけ）

```bash
gcloud auth login
gcloud auth application-default login
gcloud projects create <PROJECT_ID>            # 既存プロジェクトでも可
gcloud billing projects link <PROJECT_ID> --billing-account <BILLING_ACCOUNT_ID>
gcloud config set project <PROJECT_ID>
gcloud services enable storage.googleapis.com
gcloud storage buckets create gs://<PROJECT_ID>-tfstate --location=asia-northeast1 --uniform-bucket-level-access
gcloud storage buckets update gs://<PROJECT_ID>-tfstate --versioning   # state の世代管理
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars  # 編集
terraform -chdir=terraform/environments/dev init -backend-config="bucket=<PROJECT_ID>-tfstate"
```

## GCP Console で確認する場所

| 何を見るか | Console の場所 |
|---|---|
| VPC / Subnet | VPC ネットワーク > VPC ネットワーク > `mcp-dev` |
| Firewall | VPC ネットワーク > ファイアウォール |
| GKE クラスタ | Kubernetes Engine > クラスタ > `mcp-dev` |
| Pod | Kubernetes Engine > ワークロード（Namespace で絞り込み）> hello-go > マネージド Pod |
| Service / Ingress | Kubernetes Engine > Gateway、Service、Ingress |
| ノード VM | Compute Engine > VM インスタンス（`gke-mcp-dev-default-...`） |
| ロードバランサ | ネットワーク サービス > ロード バランシング |
| イメージ | Artifact Registry > リポジトリ > `mcp` |
| ログ | Logging > ログ エクスプローラ（`resource.type="k8s_container"`） |
| 料金 | お支払い > レポート（プロジェクトで絞り込み）/ 予算とアラート |

## GKE 上で動かす手順（初回）

1. `terraform -chdir=terraform/environments/dev plan` → 読む → `terraform -chdir=terraform/environments/dev apply`（10〜15 分）。※ helm provider がクラスタ未作成で失敗する場合は `-target=module.gke` で先にクラスタだけ作り、再度全体を apply（2 段階 apply）
2. `$(terraform -chdir=terraform/environments/dev output -raw get_credentials_command)` で kubectl を GKE に向ける（`kubectl config current-context` で必ず確認！）
3. `kubectl -n argocd port-forward svc/argocd-server 8443:443` → https://localhost:8443
4. `kubectl apply -n argocd -f argocd/bootstrap/root.yaml`
5. Ingress のホスト名: `kubectl -n traefik get svc traefik` の EXTERNAL-IP を使い、`overlays/dev/patch-ingress.yaml` を `hello-dev.<EXTERNAL-IP>.nip.io` にして PR（または curl に `-H 'Host: hello-dev.localtest.me'`）
6. 終了時: `./scripts/destroy.sh gcp <PROJECT_ID>`


## 目次

- [G00: 予算アラートを最初に作る](#g00-予算アラートを最初に作る)
- [G01: ノード数（GKE ノードプール）](#g01-ノード数gke-ノードプール)
- [G02: マシンタイプ](#g02-マシンタイプ)
- [G03: Subnet CIDR（作り直しの怖さ）](#g03-subnet-cidr作り直しの怖さ)
- [G04: Firewall](#g04-firewall)
- [G05: Private ノード + Cloud NAT](#g05-private-ノード--cloud-nat)
- [G06: ゾーン vs リージョン](#g06-ゾーン-vs-リージョン)
- [G07: Spot VM の停止に耐える](#g07-spot-vm-の停止に耐える)
- [G08: deletion_protection](#g08-deletion_protection)
- [G09: Artifact Registry へ移行](#g09-artifact-registry-へ移行)
- [G10: GCS バケットのライフサイクル](#g10-gcs-バケットのライフサイクル)

---

## G00: 予算アラートを最初に作る

> Phase 7 以降 ｜ 所要 10 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `billing_account_id` / `monthly_budget` |
| ② 変更する値 | 空 → 請求先アカウント ID、予算 3000 |
| ③ 予想される結果 | plan に `+ module.budget[0].google_billing_budget.this` |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan` → apply

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GCP Console | お支払い > 予算とアラート | my-cloud-platform-<project> が存在 |

### ⑥ うまくいかない場合の調査

- 権限エラー → 請求先アカウントの『請求先アカウント管理者』権限が必要
- currency は請求先アカウントの通貨と一致させる

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

予算アラートは課金を止めない（通知するだけ）。だから destroy の習慣とセット。

</details>

---

## G01: ノード数（GKE ノードプール）

> Phase 7 以降 ｜ 所要 20 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `node_count` |
| ② 変更する値 | `1` → `2` |
| ③ 予想される結果 | `~ update in-place`（kind の TF-01 と違い作り直さない） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan` → `apply`
2. `kubectl get nodes -w`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | node_pool | `~ node_count = 1 -> 2` |
| GCP Console | Compute Engine > VM インスタンス | gke-mcp-dev-default-* が 2 台 |
| ターミナル | `kubectl get nodes` | 2 台 Ready |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- `1` に戻す（コスト）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

TF-01 との比較がポイント。同じ『ノード数』でも provider と resource の性質で変更方法が違う。

</details>

**🔁 発展（もう一周）**

- node_count の代わりに autoscaling { min_node_count / max_node_count } を入れて、T06 の HPA と組み合わせる（Cluster Autoscaler）

---

## G02: マシンタイプ

> Phase 7 以降 ｜ 所要 20 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `machine_type` |
| ② 変更する値 | `e2-medium` → `e2-standard-2` |
| ③ 予想される結果 | ノードプールの作り直し（ノードが順に入れ替わり、Pod が退避される） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan` → `# forces replacement` を確認 → apply
2. `kubectl -n mcp-dev get pods -o wide -w` で Pod の移動を観察

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl get nodes -L node.kubernetes.io/instance-type` | 新しいタイプ |

### ⑥ うまくいかない場合の調査

- Pod が長く Pending → 新ノードの起動待ち

### ⑦ 復旧方法

- 戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

ノードの作り直しは Pod の再スケジュールを伴う。replicas=1 だとここでダウンタイムが出る（T15 PDB / replicas の重要性）。

</details>

---

## G03: Subnet CIDR（作り直しの怖さ）

> Phase 7 以降 ｜ 所要 10 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `subnet_cidr` |
| ② 変更する値 | `10.10.0.0/20` → `10.10.0.0/21` |
| ③ 予想される結果 | subnet が `-/+`、それに依存する GKE も影響を受ける |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan` **のみ**（apply しない）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | 最終行 | destroy の数が大きい |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- 戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

ネットワーク設計は後から変えにくい。IP 帯は最初に余裕を持って設計し、ADR に残す。

</details>

---

## G04: Firewall

> Phase 7 以降 ｜ 所要 20 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform/modules/network/main.tf` の `allow_iap_ssh` / ルールの追加 |
| ② 変更する値 | ① `allow_iap_ssh = false` ② わざと `0.0.0.0/0` で 22 番を開けるルールを追加して plan |
| ③ 予想される結果 | ① IAP 経由の SSH ができなくなる ②（apply しない）セキュリティ上のレビュー指摘対象 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `gcloud compute ssh <node> --tunnel-through-iap --zone asia-northeast1-a`（① の前後）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GCP Console | VPC ネットワーク > ファイアウォール | ルールの有無 |
| ターミナル | gcloud compute ssh | ① 前は成功、後はタイムアウト |

### ⑥ うまくいかない場合の調査

- Firewall の『ログ』を有効化すると拒否された通信を Logging で確認できる

### ⑦ 復旧方法

- `true` に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Firewall は送信元を最小に絞る。IAP の送信元レンジだけ許可すれば、ノードに外部 SSH ポートを開けずに済む。

</details>

---

## G05: Private ノード + Cloud NAT

> Phase 7 以降 ｜ 所要 30 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` の `private_nodes` |
| ② 変更する値 | `false` → `true` |
| ③ 予想される結果 | ノードから外部 IP が消え、NAT が追加される。NAT がないと GHCR から pull できない |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan`（NAT と cluster の差分を読む）→ apply

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GCP Console | Compute Engine > VM インスタンス | 外部 IP 列が空 |
| GCP Console | ネットワーク サービス > Cloud NAT | mcp-dev-nat |

### ⑥ うまくいかない場合の調査

- Pod が ImagePullBackOff → NAT がない / ルーターの設定

### ⑦ 復旧方法

- `false`（NAT のコスト）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

外部 IP を持たないノードは攻撃面が小さいが、外向き通信に NAT（有料）が必要になる。セキュリティとコストのトレードオフ。

</details>

---

## G06: ゾーン vs リージョン

> Phase 7 以降 ｜ 所要 10 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform.tfvars` に `zone = "asia-northeast1"`（リージョン） |
| ② 変更する値 | ゾーン → リージョン |
| ③ 予想される結果 | クラスタが作り直し、ノード数が 3 倍（各ゾーンに node_count ずつ） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan` のみ

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| plan | cluster / node_pool | replacement |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- 戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

リージョンクラスタはコントロールプレーンとノードが複数ゾーンに分散し可用性が高いが、費用も増える。案件の SLA で選ぶ。

</details>

---

## G07: Spot VM の停止に耐える

> Phase 7 以降 ｜ 所要 20 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `spot = true` |
| ② 変更する値 | ノードを手動で削除してプリエンプションを模擬 |
| ③ 予想される結果 | 新ノードが自動で作られ、Pod が再スケジュールされる |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. GCP Console > Compute Engine > ノード VM > 削除（または `gcloud compute instances delete`）
2. `kubectl get nodes,pods -A -w`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | kubectl get nodes | 数分で新ノードが Ready |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Spot は安いが予告なく停止される。ステートレス・複数 replicas・PDB なら耐えられる。

</details>

---

## G08: deletion_protection

> Phase 7 以降 ｜ 所要 10 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform/environments/dev/main.tf` の `deletion_protection` |
| ② 変更する値 | `false` → `true` で apply → destroy を試す |
| ③ 予想される結果 | destroy がエラーで止まる |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev destroy`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | エラー | `Cannot destroy cluster because deletion_protection is set to true` |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- `false` に戻して apply → destroy

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

本番の誤削除防止。prod/main.tf では true にしている。

</details>

---

## G09: Artifact Registry へ移行

> Phase 7 以降 ｜ 所要 40 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `.github/workflows/build.yml` |
| ② 変更する値 | GHCR → `asia-northeast1-docker.pkg.dev/<PROJECT>/mcp/hello-go`（WIF で認証） |
| ③ 予想される結果 | ノード SA に artifactregistry.reader があるので imagePullSecrets なしで pull できる |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. terraform.tfvars に `github_repository` を設定して apply → `output github_actions_variables` を GitHub Variables に登録
2. build.yml に `google-github-actions/auth` と `gcloud auth configure-docker` を追加（発展課題）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GCP Console | Artifact Registry > mcp | hello-go のタグ |

### ⑥ うまくいかない場合の調査

- `denied` → WIF の attribute_condition のリポジトリ名

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

クラウドの Registry はノードと同じ IAM で認証でき、鍵の管理が不要になる。WIF で GitHub からも鍵なしで push できる。

</details>

---

## G10: GCS バケットのライフサイクル

> Phase 10 以降 ｜ 所要 15 分 ｜ 環境: GCP dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `enable_storage = true`、`modules/storage` の `delete_after_days` |
| ② 変更する値 | `30` → `1` |
| ③ 予想される結果 | plan に lifecycle_rule の変更（in-place） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `terraform -chdir=terraform/environments/dev plan` → apply

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GCP Console | Cloud Storage > バケット > ライフサイクル | 1 日 |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

ストレージは放置するとコストが積み上がる。保存期間をコードで管理する。

</details>

---
