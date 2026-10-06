# 0008: Ingress Controller に Traefik
- Status: Accepted
- Date: 2026-10-06

## Context
Ingress API を学ぶため Controller が必要。長く使われてきた ingress-nginx は Kubernetes プロジェクトによって引退（retirement）が告知されている（2026 年 3 月でメンテナンス終了の予定と案内されていた。最新状況は公式ブログで確認すること）。

## Decision
Ingress API をサポートし、Helm で kind / GKE 共通に入れられる Traefik を使う。

## Alternatives
- ingress-nginx: 情報は多いが引退済み/予定
- GKE Ingress: GKE 専用で local と共通化できない
- Gateway API（Envoy Gateway 等）: 今後の標準。Future Improvements で移行

## Consequences
+ local と GKE で同じ Ingress マニフェスト
- 将来 Gateway API へ移行する前提（そのときも overlays の差分は小さいはず）
