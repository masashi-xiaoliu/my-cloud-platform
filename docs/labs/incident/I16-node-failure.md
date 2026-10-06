# I16: ノード障害・Pod 削除への耐性

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

① `kubectl -n mcp-dev delete pod <pod>` ② `docker stop my-cloud-platform-worker`（kind の worker ノードを止める）

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

（① ではほぼ何も起きないはず。② では一時的にエラーが出る可能性）

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods -o wide -w`
- `kubectl get nodes -w`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

Pod が別ノードで作り直されるまでの時間、ノードの `NotReady`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

Pod を消したのに数が減らないのはなぜ?（ReplicaSet）

</details>

<details><summary>💡 Hint 2</summary>

ノードが NotReady になってから Pod が退避されるまで、どのくらい時間がかかった?

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

① ReplicaSet が即座に Pod を補充 ② ノード停止を検知 → 一定時間（既定 5 分程度の toleration）後に Pod が他ノードへ再作成

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`docker start my-cloud-platform-worker`

</details>

## 8. 復旧確認

- [ ] 全ノード Ready、Pod が Running

## 9. 学び

Pod は使い捨て（Cattle, not pets）。replicas=1 ではノード障害時にダウンタイムが出る。replicas≥2 + Pod を別ノードに分散（topologySpreadConstraints）で可用性を上げる。
