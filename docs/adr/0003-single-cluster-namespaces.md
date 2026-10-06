# 0003: 学習用に 1 クラスタ・Namespace で環境分離
- Status: Accepted
- Date: 2026-10-06

## Context
ノート PC 1 台で dev / staging / prod の昇格フローを体験したい。

## Decision
1 つのクラスタに mcp-dev / mcp-staging / mcp-prod の Namespace を作り、Argo CD Application を環境ごとに分ける。

## Alternatives
- 環境ごとにクラスタ: 実務的だがローカルではリソース不足、GCP では費用 3 倍

## Consequences
+ 昇格フロー・手動 Sync の運用を安く体験できる
- 本番の分離（障害・権限・ノード）としては不十分。実務では prod は別クラスタ・別プロジェクト（terraform/environments/prod がその設計例）
