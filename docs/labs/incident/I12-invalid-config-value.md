# I12: 不正な設定値（LOG_LEVEL）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I12
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

『障害調査のためにログを詳しくしたい』という変更をデプロイしたら、Pod が起動しなくなった。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods`
- `kubectl -n mcp-dev logs <pod> --previous`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

`LOG_LEVEL must be one of debug|info|warn|error`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

変更差分を見る: Argo CD > History and Rollback、または `git log -p -1 kubernetes/overlays/dev/config.env`

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

`LOG_LEVEL=verbose` は許可されていない値。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`LOG_LEVEL=debug` にする → Merge

</details>

## 8. 復旧確認

- [ ] Pod が Running、debug ログが出る

## 9. 学び

障害対応中の変更が二次障害を起こすのは実務でよくある。『変更したら必ず結果を確認する』『1 度に 1 つだけ変える』。CI で config.env の値を検証すれば防げる（発展課題）。
