# 0004: /metrics を依存なしで手書き
- Status: Accepted
- Date: 2026-10-06

## Context
アプリは学習の主題ではないため依存を最小にしたい。また /metrics が単なるテキストであることを見せたい。

## Decision
Prometheus テキスト形式を標準ライブラリだけで出力する（metrics.go）。

## Alternatives
- prometheus/client_golang: 本番では推奨。Go ランタイムメトリクスも自動で出る

## Consequences
+ go.sum 不要・ビルドが速い・仕組みが読める
- 機能は最小。本番相当にするなら client_golang へ置き換える（Future Improvements）
