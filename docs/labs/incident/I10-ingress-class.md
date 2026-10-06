# I10: Ingress 障害（404）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I10
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

http://hello-dev.localtest.me が 404 page not found。Pod も Service も正常。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get ingress`
- `kubectl get ingressclass`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

Ingress の CLASS 列

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

Service まで正常か: `kubectl -n mcp-dev port-forward svc/hello-go 18080:80` → `curl localhost:18080`

</details>

<details><summary>💡 Hint 2</summary>

404 を返しているのは誰? アプリ? Traefik?（レスポンス本文の形式で見分けられる）

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

`ingressClassName: nginx`。存在しないクラスのため Traefik がこの Ingress を無視し、ルートが存在しない → Traefik の 404。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`./scripts/reset.sh dev` → Merge

</details>

## 8. 復旧確認

- [ ] `curl` が 200

## 9. 学び

404 は『どこが返しているか』で意味がまったく違う。アプリの 404 と Ingress Controller の 404 を区別する。
