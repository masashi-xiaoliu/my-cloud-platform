# I06: Secret エラー（必須の API_KEY がない）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I06
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

新しい Pod が起動直後に落ちる。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods`
- `kubectl -n mcp-dev logs <pod> --previous`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

ログの `error` フィールド

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

エラーメッセージにあるキーは ConfigMap と Secret のどちらにある?

</details>

<details><summary>💡 Hint 2</summary>

`kubectl -n mcp-dev get secret <name> -o jsonpath='{.data.API_KEY}' | base64 -d` で中身を確認（空文字?）

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

`REQUIRE_API_KEY=true` なのに Secret の `API_KEY` が空。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`secret.env` に値を設定、または `REQUIRE_API_KEY=false` → Merge

</details>

## 8. 復旧確認

- [ ] Pod が Running
- [ ] `/info` の `api_key_set: true`

## 9. 学び

外部 API キーの失効・ローテーション漏れは実務で頻発する。起動時に検証して即失敗させれば、本番トラフィックが来る前に気付ける。
