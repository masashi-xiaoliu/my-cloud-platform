# I07: アプリケーションエラー（5xx 率の上昇）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I07
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

一部のユーザーからエラーの報告。Pod はすべて正常。Grafana の Error rate が上昇。アラート `HelloGoHighErrorRate` が発火（Phase 8〜）。

**アラート**: `HelloGoHighErrorRate`

## 2. 最初に打つコマンド

- Grafana > My Cloud Platform / hello-go > Error rate / Requests by status code
- `for i in $(seq 20); do curl -s -o /dev/null -w '%{http_code} ' http://hello-dev.localtest.me/; done`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

status code の分布、エラーが始まった時刻

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

エラーが始まった時刻と、直近のデプロイ（Argo CD の History / `git log`）の時刻を比べる。

</details>

<details><summary>💡 Hint 2</summary>

`kubectl -n mcp-dev logs deploy/hello-go | grep '"level":"ERROR"\|WARN'` でエラーログを探す。

</details>

<details><summary>💡 Hint 3</summary>

`curl .../info` で現在の設定値を見る。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

`ERROR_RATE=40`（アプリの設定で 40% のリクエストが 500 を返す）。インフラは正常で、アプリ層の問題。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`ERROR_RATE=0` に戻す → Merge。本番なら『まず直前のデプロイを Rollback（R01）→ 落ち着いてから原因調査』が定石。

</details>

## 8. 復旧確認

- [ ] Grafana の Error rate が 0 に戻る
- [ ] アラートが resolved になる

## 9. 学び

インフラの指標（Pod 数・CPU）が正常でもユーザーは困っている、というケース。だからアプリのメトリクス（RED: Rate / Errors / Duration）を監視する。『変更と障害の時刻の相関』を見るのが最初の一手。
