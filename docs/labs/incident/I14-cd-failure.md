# I14: CD 失敗（Argo CD OutOfSync / Sync Failed / Degraded）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

① `components/monitoring` を Phase 8 より前に有効化する ② Argo CD Application の `targetRevision` を存在しないブランチにする（argocd/applications/hello-go-dev.yaml）③ I02 を実施

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

Merge したのにクラスタに反映されない。Argo CD のアプリに黄色・赤のアイコン。

## 2. 最初に打つコマンド

- Argo CD UI > hello-go-dev > 上部のステータス（Sync / Health）
- `kubectl -n argocd get applications`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

App Details の `CONDITIONS` / `LAST SYNC` のメッセージ、ツリー上で赤いリソース

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

Sync status（Git とクラスタが一致しているか）と Health status（動いているか）は別物。どちらが悪い?

</details>

<details><summary>💡 Hint 2</summary>

`SyncFailed` の場合は Sync 結果のメッセージにそのまま原因が書いてある（例: `no matches for kind "ServiceMonitor"`）。

</details>

<details><summary>💡 Hint 3</summary>

`ComparisonError` は Argo CD が Git からマニフェストを作れていない（ブランチ・パス・kustomize エラー）。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

① ServiceMonitor の CRD がまだクラスタにない ② Git にブランチが存在しない ③ Sync は成功しているが Pod が起動できず Health が Degraded

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

① components から外す（または Phase 8 で kube-prometheus-stack を入れる）② targetRevision を main に戻す ③ R01 で Rollback

</details>

## 8. 復旧確認

- [ ] Argo CD が `Synced` かつ `Healthy`

## 9. 学び

『Synced だが Degraded』『OutOfSync だが Healthy』の組み合わせを読めることが GitOps 運用の基本。CI（構文）が通っても CD（クラスタ適用）で落ちる種類のエラーがある。
