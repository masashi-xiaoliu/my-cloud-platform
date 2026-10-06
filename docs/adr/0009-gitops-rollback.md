# 0009: Rollback は Git revert
- Status: Accepted
- Date: 2026-10-06

## Context
Argo CD の selfHeal を有効にしているため、クラスタを直接戻しても Git の状態に戻される。

## Decision
Rollback は rollback.yml で Git を戻す（revert / 既知タグの指定）。prod の緊急時のみ Argo CD UI の Rollback を許可し、直後に Git を揃える。

## Alternatives
- kubectl rollout undo: selfHeal と衝突（R03）

## Consequences
+ 誰が・いつ・何に戻したかが Git に残る
- Argo CD の検知待ち分だけ復旧が遅れる（Webhook で短縮可能）
