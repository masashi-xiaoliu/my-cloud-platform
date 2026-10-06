# I09: OOMKilled（メモリ上限超過）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I09
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

Pod の RESTARTS が増え続ける。ログにはエラーが出ていない。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods`
- `kubectl -n mcp-dev describe pod <pod>`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

`Last State: Terminated / Reason: OOMKilled / Exit Code: 137`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

ログにエラーがないのに死ぬ → 外部から殺されている可能性。

</details>

<details><summary>💡 Hint 2</summary>

Exit Code 137 = 128 + 9。9 は何のシグナル?

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

起動時に 100MB 確保（MEMORY_BALLAST_MB=100）するのに memory limit が 48Mi。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

ballast を 0 にするか limit を上げる → Merge

</details>

## 8. 復旧確認

- [ ] RESTARTS が増えない
- [ ] Grafana Memory working set が limit 未満

## 9. 学び

Tuning Lab T05 参照。本番では『limit を上げて即復旧 → リークの原因調査』の 2 段階。
