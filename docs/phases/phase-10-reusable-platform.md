# Phase 10 — Reusable Platform（80% 共通基盤 + 20% 案件固有）

## ゴール
架空の案件を受注し、**基盤（80%）を変えずに** 案件固有の要件（20%）を追加できる。新しいアプリ（FastAPI）を同じ基盤に載せられる。

## 進め方
1. [Case Study](../case-study/README.md)：要件確認 → 設計 → 実装 → 負荷試験 → 障害 → 復旧、そして変更要求 CR-1〜CR-4
2. [Platform Contract](../platform-contract.md) の「新規アプリのオンボーディング手順」で `apps/fastapi` を載せる
3. ADR（`docs/adr/`）に設計判断を記録

## 「80% を変えていない」ことの確認方法

```bash
# Case Study 開始時にタグを打つ
git tag case-study-start
# 終了時: 共通基盤側の差分が小さいことを確認
git diff --stat case-study-start -- kubernetes/base kubernetes/components/hpa kubernetes/components/monitoring \
  terraform/modules/platform-addons .github/workflows argocd/projects
# 案件固有側の差分
git diff --stat case-study-start -- apps kubernetes/overlays kubernetes/components/postgres terraform/environments
```

## Checkpoint
- [ ] FastAPI 版が hello-go と同じ CI / CD / 監視ダッシュボードで動いた
- [ ] 共通基盤側の変更が「汎用化のための改善」だけであることを説明できた
