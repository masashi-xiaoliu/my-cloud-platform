# Phase 9 — Failure / Recovery（障害注入・トラブルシューティング・復旧）

## ゴール
何が壊れたかわからない状態から、**症状 → 確認コマンド → ログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認** を自力で回せる。

## 進め方
1. [Incident Response Lab](../labs/incident/README.md) を I01 から順に「シナリオ指定」モードで 1 周
2. [Rollback / Recovery Lab](../labs/recovery/README.md) R01〜R04
3. `make chaos` のブラインド訓練を最低 10 回（毎回 `docs/experiments/` に記録）
4. 「平均復旧時間（障害注入から復旧確認まで）」を記録して短縮を目指す

## ブラインド訓練の記録表（learning-log.md に転記）

| # | 日付 | 症状 | 最初に打ったコマンド | 原因 | 復旧までの時間 | 次回の改善 |
|---|---|---|---|---|---|---|
| 1 | | | | | | |

## Checkpoint
- [ ] 16 シナリオすべてを Answer を見ずに特定できた
- [ ] 再発防止として CI チェック or アラートを 1 つ以上追加した（例: config.env の値検証、requests ≤ limits）
