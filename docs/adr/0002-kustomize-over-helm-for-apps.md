# 0002: アプリは Kustomize、アドオンは Helm
- Status: Accepted
- Date: 2026-10-06

## Context
自作アプリの環境差分管理と、OSS アドオン（Argo CD / Prometheus 等）の導入方法を決める必要がある。

## Decision
自作アプリは Kustomize（base + components + overlays）。OSS は公式 Helm チャートを Terraform の helm provider で入れる。

## Alternatives
- アプリも Helm チャート化: テンプレート構文の学習コストが高く、最終 YAML が見えにくい
- アドオンも Argo CD で管理: Argo CD 自身のブートストラップ問題が残る

## Consequences
+ `kustomize build` で適用される YAML がそのまま読める（学習向き）
+ components で機能を ON/OFF できる
- overlay の patch が component より後に適用される順序の罠がある（T06）→ CI でガード
