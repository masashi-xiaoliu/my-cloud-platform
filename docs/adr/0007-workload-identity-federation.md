# 0007: GitHub → GCP は Workload Identity Federation
- Status: Accepted
- Date: 2026-10-06

## Context
CI から GCP に認証する必要がある。サービスアカウントキー（JSON）は漏えい時の影響が大きく、ローテーションも面倒。

## Decision
GitHub の OIDC トークンを GCP の WIF で受け、特定リポジトリからのトークンだけを SA に紐付ける（attribute_condition）。

## Alternatives
- SA キーを GitHub Secrets に保存: 簡単だが長期有効な鍵が残る

## Consequences
+ 長期有効な鍵が存在しない
- 初期設定がやや複雑（terraform/environments/dev/github-oidc.tf にコード化）
