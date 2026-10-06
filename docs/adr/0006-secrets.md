# 0006: Secret の扱い
- Status: Accepted
- Date: 2026-10-06

## Context
Argo CD は Git にあるものしか適用できない。一方、秘密情報を Git に平文で置いてはいけない。

## Decision
学習用には明示的なダミー値だけを secret.env に置く（実在の値は禁止）。本番相当では Secret Manager + External Secrets Operator に移行する。

## Alternatives
- Sealed Secrets: 暗号化して Git に置ける。鍵管理が必要
- SOPS + age: 同上
- External Secrets + Secret Manager: クラウドの IAM と統合でき、ローテーションしやすい

## Consequences
+ 学習の初期段階をシンプルに保てる
- 本番には使えない構成であることを README とファイル先頭で明示する
