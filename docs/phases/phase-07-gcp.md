# Phase 7 — GCP（Local → Cloud）

## ゴール
ローカルと **同じモジュール・同じマニフェスト** で GKE 上に環境を作り、コストを管理しながら実験し、確実に削除できる。

## 触るファイル
`terraform/modules/{network,gke,artifact-registry,budget,database,storage}`、`terraform/environments/dev/*`（`github-oidc.tf` 含む）、`.github/workflows/terraform-plan.yml`

## 構成

```text
Terraform ─▶ Budget alert
          ─▶ VPC mcp-dev ─ Subnet (nodes 10.10.0.0/20 / pods 10.20.0.0/16 / services 10.30.0.0/20)
          │               ─ Firewall (internal, IAP SSH)  ─ [Cloud NAT: private_nodes 時のみ]
          ─▶ GKE mcp-dev (zonal, Dataplane V2, Workload Identity) ─ NodePool (e2-medium × 1, Spot)
          ─▶ Artifact Registry mcp
          ─▶ Workload Identity Federation (GitHub Actions → GCP、鍵なし)
          ─▶ platform-addons（local と同じモジュール。Traefik は LoadBalancer、管理画面は非公開）
Argo CD ─▶ kubernetes/overlays/dev（local と同じ）
```

## 手順
詳細なコマンドと課金対象の一覧は [GCP Lab](../labs/gcp/README.md) の冒頭。

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | ターミナル | GCP Lab「事前準備」のコマンド | `gcloud config list` | project が設定済み |
| 2 | ターミナル | `terraform plan`（dev） | 最終行 | 作成予定のリソース数を記録 |
| 3 | ターミナル | `terraform apply` | GCP Console > Kubernetes Engine > クラスタ | `mcp-dev` が緑 |
| 4 | ターミナル | `$(terraform output -raw get_credentials_command)` → `kubectl config current-context` | 出力 | `gke_<project>_asia-northeast1-a_mcp-dev` |
| 5 | ターミナル | Argo CD に port-forward → root.yaml を apply | Argo CD UI | hello-go-dev が Synced/Healthy |
| 6 | GCP Console | Kubernetes Engine > ワークロード > hello-go | Pod 一覧 | Running |
| 7 | ターミナル | `kubectl -n traefik get svc traefik` → `curl -H 'Host: hello-dev.localtest.me' http://<EXTERNAL-IP>/` | 出力 | メッセージ |
| 8 | GitHub | terraform.tfvars に `github_repository` → apply → `terraform output github_actions_variables` を Settings > Secrets and variables > Actions > **Variables** に登録 | PR で terraform を変更 | Terraform Plan ワークフローが Summary に plan を出す |
| 9 | ターミナル | `./scripts/destroy.sh gcp <PROJECT_ID>` | GCP Console > お支払い > レポート（翌日） | 課金が止まっている |

> ⚠ kubectl のコンテキストを kind と GKE で切り替えるとき、`kubectl config current-context` を必ず確認する習慣をつける（「ローカルのつもりで本番を消した」は実務の定番事故）。

## Checkpoint
- [ ] local と dev で **同じ** `platform-addons` モジュール・**同じ** overlays を使っていることを説明できる（80% の再利用）
- [ ] 課金対象の一覧と削除手順を自分の言葉で書いた
