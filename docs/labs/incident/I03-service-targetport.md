# I03: Service 接続失敗（targetPort 不一致）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I03
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

Pod はすべて `Running` / `1/1`。なのにブラウザでは 502 Bad Gateway / Bad Gateway。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods,svc,endpointslices`
- `curl -i http://hello-dev.localtest.me/`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

EndpointSlice の PORTS 列、Service の PORT(S)

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

外側から切り分ける: Ingress → Service → Pod。まず Pod に直接繋がるか: `kubectl -n mcp-dev port-forward pod/<pod> 18080:8080` → `curl localhost:18080/`

</details>

<details><summary>💡 Hint 2</summary>

Pod に直接なら繋がる → 問題は Service 以降。`kubectl -n mcp-dev describe svc hello-go` の `TargetPort` と `Endpoints` を見る。

</details>

<details><summary>💡 Hint 3</summary>

Endpoints の『IP:ポート』のポートは、アプリが待ち受けているポートと一致している?

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

Service の `targetPort` が 9090。Pod は 8080 で待ち受けているため、Service 経由の通信は接続拒否される。Traefik は 502 を返す。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

patch-chaos.yaml を削除し kustomization.yaml から参照を消す（`./scripts/reset.sh dev`）→ Merge

</details>

## 8. 復旧確認

- [ ] `describe svc` の Endpoints が `<podIP>:8080`
- [ ] curl が 200

## 9. 学び

『Pod は正常、でも繋がらない』は Service / Ingress / NetworkPolicy の層。port-forward で Pod に直接繋ぐのは最強の切り分け手段。
