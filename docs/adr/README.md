# Architecture Decision Records

「なぜこの技術・構成を選んだか」を残す。後から読んだ人（未来の自分を含む）が判断の前提を理解できるようにする。

| # | タイトル | 状態 |
|---|---|---|
| [0001](0001-local-first.md) | Local first（kind → GKE） | Accepted |
| [0002](0002-kustomize-over-helm-for-apps.md) | アプリのマニフェストは Kustomize、アドオンは Helm | Accepted |
| [0003](0003-single-cluster-namespaces.md) | 学習用に 1 クラスタ・Namespace で環境分離 | Accepted |
| [0004](0004-hand-rolled-metrics.md) | /metrics を依存なしで手書き | Accepted |
| [0005](0005-terraform-apply-by-human.md) | terraform apply は人が実行、plan は CI | Accepted |
| [0006](0006-secrets.md) | Secret の扱い（学習用 dummy → External Secrets） | Accepted（暫定） |
| [0007](0007-workload-identity-federation.md) | GitHub → GCP は WIF（鍵なし） | Accepted |
| [0008](0008-traefik-ingress.md) | Ingress Controller に Traefik | Accepted |
| [0009](0009-gitops-rollback.md) | Rollback は Git revert | Accepted |

テンプレート:

```markdown
# NNNN: タイトル
- Status: Proposed / Accepted / Superseded by NNNN
- Date:
## Context（背景・制約）
## Decision（決めたこと）
## Alternatives（検討した他の案と却下理由）
## Consequences（良い影響・悪い影響・今後の課題）
```
