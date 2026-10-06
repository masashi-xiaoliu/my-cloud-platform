# I15: 外部 API / DNS 障害

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

`config.env` の `UPSTREAM_URL` を `http://api.example.invalid/` にする（他の値は秘密にしてペアに出題してもらう）

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

`/upstream` を使う機能だけがエラー（502）。応答も遅い。

## 2. 最初に打つコマンド

- `curl -i http://hello-dev.localtest.me/upstream`
- `kubectl -n mcp-dev logs deploy/hello-go | grep upstream`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

ログの `error` 文字列（`no such host` / `connection refused` / `timeout` / `status 5xx`）

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

エラーの種類で層が決まる: DNS / TCP / HTTP。

</details>

<details><summary>💡 Hint 2</summary>

Pod から直接試す: `kubectl -n mcp-dev run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup api.example.invalid`

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

名前解決できないホスト。MAX_RETRY 回リトライするため応答も遅い。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

正しい URL に戻す → Merge

</details>

## 8. 復旧確認

- [ ] `/upstream` が `upstream ok`

## 9. 学び

外部依存の障害は自分では直せない。だからタイムアウト・リトライ・サーキットブレーカー・フォールバックで『巻き込まれない』設計をする（T09）。
