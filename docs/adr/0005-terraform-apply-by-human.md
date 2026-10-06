# 0005: terraform apply は人が実行、plan は CI
- Status: Accepted
- Date: 2026-10-06

## Context
インフラ変更は影響が大きく、学習段階では plan を自分で読む訓練が目的の一つ。

## Decision
CI は fmt / validate、GCP 設定後は PR で plan を Job Summary に出す。apply は人がローカルで実行する。

## Alternatives
- Atlantis / CI からの apply: 自動化は進むが、CI に強い権限が必要になる

## Consequences
+ CI の GCP 権限は roles/viewer で済む
- apply 漏れ（Git と実物のズレ）が起きうる → 定期的に plan して No changes を確認
