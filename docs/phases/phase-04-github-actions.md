# Phase 4 — GitHub Actions（Push → Test → Build → Registry）

## ゴール
push / PR で CI が自動実行され、Build でイメージが GHCR に push される。**Actions の画面のどこを見れば成否と原因がわかるか** を説明できる。

## 触るファイル
`.github/workflows/ci.yml`、`build.yml`、`scripts/check-manifests.py`

## フロー

```text
git push / PR ─▶ CI: Checkout → Setup Go → Format → Vet → Test → Docker build(no push)
                     → kustomize build → kubeconform → check-manifests → terraform fmt/validate
main merge (apps/hello-go/**) ─▶ Build: Docker build → push ghcr.io/<you>/hello-go:<tag> ─▶ (Phase 5〜) Deploy
```

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | GitHub > Actions > CI | [C01](../labs/cicd/README.md) の手順で **Run workflow** | Run の Summary | 4 Job すべて ✅ |
| 2 | GitHub > Actions > Build | **Run workflow** > version `v1.0.0` / deploy_to_dev ☐ | Run の Job Summary | `Image: ghcr.io/<you>/hello-go:v1.0.0` |
| 3 | GitHub > リポジトリ右側 Packages | hello-go > **Package settings** > Change visibility > **Public** | パッケージページ | Public 表示 |
| 4 | ターミナル | `docker pull ghcr.io/<you>/hello-go:v1.0.0` | 出力 | pull 成功 |
| 5 | GitHub | Settings > Rules > Rulesets で main に「PR 必須 + Status checks 必須」（Bypass: GitHub Actions） | — | 直接 push が拒否される |
| 6 | ターミナル + GitHub | [C02](../labs/cicd/README.md) で CI を壊す → 直す | PR の Checks | ❌ → ✅ |

## Checkpoint
- [ ] PR の ❌ から「失敗した Step のログの該当行」まで 3 クリックで辿れる
- [ ] GHCR に v1.0.0 がある（Phase 5 の dev / staging / prod の初期タグ）
