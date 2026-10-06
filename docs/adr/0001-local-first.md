# 0001: Local first（kind → GKE）
- Status: Accepted
- Date: 2026-10-06

## Context
クラウドは試行錯誤のたびに課金される。学習初期は壊す・作り直す回数を最大化したい。

## Decision
kind で Phase 1〜6 と Phase 8〜9 を完結させ、GCP は Phase 7 で同じモジュール・同じマニフェストを再利用して検証する。

## Alternatives
- 最初から GKE: 費用と待ち時間で試行回数が減る
- minikube / k3d: kind は Kubernetes 本体の CI でも使われ、マルチノード構成と Terraform provider がある

## Consequences
+ 無料で何度でも壊せる
- LoadBalancer / IAM / NetworkPolicy などクラウド固有の挙動は Phase 7 まで確認できない
