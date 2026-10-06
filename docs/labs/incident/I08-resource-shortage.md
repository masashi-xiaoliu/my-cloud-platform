# I08: リソース不足（Pending）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I08
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

デプロイが終わらない。新 Pod が `Pending` のまま。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods -o wide`
- `kubectl -n mcp-dev describe pod <pending pod>`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

Events の `FailedScheduling`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

`0/2 nodes are available: 2 Insufficient cpu.` の意味は?

</details>

<details><summary>💡 Hint 2</summary>

`kubectl describe nodes | grep -A8 'Allocated resources'` と Pod の requests を比べる。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

CPU requests が `64`（64 コア）。どのノードの Allocatable にも収まらない。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`./scripts/reset.sh dev` → Merge

</details>

## 8. 復旧確認

- [ ] Pod が Running

## 9. 学び

Pending = スケジューラが置き場所を見つけられない。原因は requests 過大・ノード不足・nodeSelector/taint 不一致・PVC 未割当など。クラウドでは Cluster Autoscaler がノードを足すことで解決する場合もある（それが正しい対応かはコスト次第）。
