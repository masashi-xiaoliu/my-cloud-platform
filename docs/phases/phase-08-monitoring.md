# Phase 8 — Monitoring（Prometheus / Grafana）

## ゴール
**設定変更 → システム変化 → メトリクス変化** を Grafana で確認できる。アラートが鳴る条件を自分で設計できる。

## 触るファイル
`monitoring/prometheus/values.yaml`、`monitoring/grafana/*`、`kubernetes/components/monitoring/*`、`argocd/applications/monitoring-dashboards.yaml`

## 手順
[Monitoring Lab の「有効化チェックリスト」](../labs/monitoring/README.md) の 1〜5。ローカルで行うのを推奨（GKE ではノード増が必要になりコスト増）。

## HPA もここで
metrics-server と Grafana が揃ったので、T06（HPA）と T03（CPU throttling）をこの Phase で行うと因果がグラフで見える。

## この Phase でやる Lab
M01〜M08、T03、T06、I07

## Checkpoint
- [ ] Grafana の各パネルの PromQL を 1 つ読み解いて実験記録に書いた
- [ ] ERROR_RATE を上げてアラートが Firing → 戻して Resolved を確認した
