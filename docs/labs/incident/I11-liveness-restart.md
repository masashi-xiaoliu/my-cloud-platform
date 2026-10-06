# I11: 再起動ループ（livenessProbe）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I11
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

Pod が 30 秒ほど動いては再起動する。その間アクセスは成功する。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods -w`
- `kubectl -n mcp-dev describe pod <pod>`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

Events の `Liveness probe failed: ... connection refused` / `Container hello-go failed liveness probe, will be restarted`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

`connection refused` はどのポートに対して?

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

livenessProbe の port が 9999。何も待ち受けていないので失敗 → kubelet が再起動。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`./scripts/reset.sh dev` → Merge

</details>

## 8. 復旧確認

- [ ] RESTARTS が増えない

## 9. 学び

liveness の設定ミスは『正常なアプリを殺し続ける』。liveness はシンプルに保ち、外部依存を入れない。
