# I02: ImagePullBackOff（存在しないイメージ）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I02
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

デプロイしたのにバージョンが変わらない。Argo CD が `Progressing` → しばらくして `Degraded`。

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

新しい Pod の STATUS が `ErrImagePull` / `ImagePullBackOff`

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

`kubectl -n mcp-dev describe pod <pod>` の一番下の **Events** を読む。

</details>

<details><summary>💡 Hint 2</summary>

Events に出ているイメージ名とタグを、GitHub > Packages > hello-go のタグ一覧と比べる。

</details>

<details><summary>💡 Hint 3</summary>

そのタグはどのコミットで入った? `git log -p kubernetes/overlays/dev/kustomization.yaml`

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

`newTag: v999.0.0` は Registry に存在しない。ノードの containerd が pull に失敗し、BackOff しながら再試行している。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

[Recovery Lab R01](../recovery/README.md)：Actions > Rollback（revert-last-deploy）で直前の deploy コミットを打ち消す。または R02 で既知の正常タグを指定。

</details>

## 8. 復旧確認

- [ ] 新 Pod が消え、全 Pod が正常タグで `Running`
- [ ] `curl .../info` の version が正常タグ

## 9. 学び

旧 Pod が生き残っていたのでサービスは止まらなかった（maxUnavailable: 0 の効果）。deploy.yml の Guardrail はこの事故を CD の手前で防ぐ。人が手で書き換えた PR はガードレールを通らない → CI にもイメージ存在チェックを入れるべき（発展課題）。プライベートレジストリでは同じ症状が『認証エラー（imagePullSecrets 未設定）』で起きる点も覚えておく。
