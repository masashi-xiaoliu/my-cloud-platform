# Phase 6 — Terraform（ローカル基盤のコード化）

## ゴール
Phase 3〜5 で手作業でやったこと（kind 作成・Traefik・Argo CD・metrics-server）を Terraform で再現し、**plan で変更内容を事前に読める** ようになる。

## 触るファイル
`terraform/modules/kind-cluster/*`、`terraform/modules/platform-addons/*`、`terraform/environments/local/*`

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | ターミナル | `kind delete cluster --name my-cloud-platform`（手作業版を消す） | `kind get clusters` | 空 |
| 2 | ターミナル | `cd terraform/environments/local && cp terraform.tfvars.example terraform.tfvars && terraform init` | 出力 | `Terraform has been successfully initialized!` |
| 3 | ターミナル | `terraform plan` | 出力の最終行 | `Plan: 4 to add, 0 to change, 0 to destroy.`（kind_cluster + helm_release ×3） |
| 4 | ターミナル | `terraform apply` → 内容を確認して `yes` | 出力 | `Apply complete!` |
| 5 | ターミナル | `terraform output` | 出力 | `urls.argocd = http://argocd.localtest.me` など |
| 6 | ブラウザ | http://argocd.localtest.me（Ingress 経由、port-forward 不要） | 画面 | ログイン画面。パスワードは `terraform output -raw argocd_initial_password_command` のコマンドで |
| 7 | ターミナル | `kubectl apply -n argocd -f argocd/bootstrap/root.yaml` | Argo CD UI | Phase 5 と同じアプリが全部復活（GitOps の威力） |
| 8 | ターミナル | `terraform plan` | 出力 | `No changes.`（コードと実物が一致） |

## 手作業 vs Terraform（記録に残す比較）

| 観点 | Phase 3〜5（手作業） | Phase 6（Terraform） |
|---|---|---|
| 再現性 | 手順書を人が読んで実行 | `apply` 1 回 |
| 変更の事前確認 | なし | `plan` |
| 現状把握 | 頭の中 / kubectl | `state list` |
| 作り直し | 手順を全部やり直し | `destroy` → `apply`（TF-07 で時間を計測） |

## この Phase でやる Lab
[Terraform Lab](../labs/terraform/README.md) TF-01〜TF-08

## Checkpoint
- [ ] plan の `+` `~` `-/+` `-` を説明できる
- [ ] destroy → apply → root.yaml だけで全環境が戻ることを確認した
