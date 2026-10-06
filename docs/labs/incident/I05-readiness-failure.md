# I05: Ready にならない（readinessProbe）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I05
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

新しい Pod が `Running` なのに READY `0/1`。デプロイが終わらない。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods`
- `kubectl -n mcp-dev describe pod <pod>`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

Events の `Readiness probe failed: HTTP probe failed with statuscode: 404`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

404 は『アプリには届いたが、そのパスは存在しない』という意味。

</details>

<details><summary>💡 Hint 2</summary>

probe の path を main.go の `routes()` と比べる。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

readinessProbe の path が `/ready`（正しくは `/readyz`）。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`./scripts/reset.sh dev` → Merge

</details>

## 8. 復旧確認

- [ ] READY `1/1`
- [ ] Rolling Update が完了（`kubectl -n mcp-dev rollout status deploy/hello-go`）

## 9. 学び

readiness 失敗は再起動されない（liveness との違い）。新 Pod が Ready にならないので旧 Pod が残り、サービスは継続する。
