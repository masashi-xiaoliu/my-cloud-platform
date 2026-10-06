# I04: Service 接続失敗（selector 不一致）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I04
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

Pod は正常。外部からは 503 / `no available server`。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get endpointslices`
- `kubectl -n mcp-dev describe svc hello-go`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

`Endpoints: <none>`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

Endpoint が空 ＝ Service が Pod を 1 つも見つけられていない。

</details>

<details><summary>💡 Hint 2</summary>

`kubectl -n mcp-dev get pods --show-labels` と Service の `Selector` を 1 文字ずつ比べる。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

Service の selector が `app.kubernetes.io/name=hello-goo`。どの Pod のラベルにも一致しない。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`./scripts/reset.sh dev` → Merge

</details>

## 8. 復旧確認

- [ ] `get endpointslices` に Pod IP が並ぶ
- [ ] curl が 200

## 9. 学び

Kubernetes の部品は名前ではなく **ラベル** で緩く結びついている。ラベル不一致はエラーにならず『静かに何も起きない』ので、Endpoint を見る習慣が重要。
