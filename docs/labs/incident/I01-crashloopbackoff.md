# I01: Pod CrashLoopBackOff（設定エラー）

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

```bash
python3 scripts/chaos.py inject I01
```

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

デプロイ後、サイトにアクセスすると時々エラー、または新バージョンにならない。Argo CD が `Progressing` から進まない。

**アラート**: `HelloGoPodRestarting`（Phase 8 以降）

## 2. 最初に打つコマンド

- `kubectl -n mcp-dev get pods`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

STATUS 列と RESTARTS 列

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

STATUS が `CrashLoopBackOff` / `Error` なら、コンテナは起動して **自分で終了している**。次に見るのは『なぜ終了したか』＝ログ。

</details>

<details><summary>💡 Hint 2</summary>

`kubectl -n mcp-dev logs <pod>` で何も出ない場合は `--previous` を付ける（今のコンテナではなく、直前に死んだコンテナのログ）。

</details>

<details><summary>💡 Hint 3</summary>

ログの `error` フィールドに書かれた設定名を、`kubernetes/overlays/dev/config.env` で探す。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

`APP_MESSAGE` が空。アプリは起動時に必須設定を検証し、不正なら `exit 1` する（main.go の `loadConfig`）。kubelet は再起動を繰り返し、間隔が 10s → 20s → 40s… と伸びる（BackOff）。

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

`config.env` の `APP_MESSAGE` に値を入れる（または `./scripts/reset.sh dev`）→ commit → PR → Merge

</details>

## 8. 復旧確認

- [ ] `kubectl -n mcp-dev get pods` で `1/1 Running`、RESTARTS が増えない
- [ ] Argo CD が `Synced / Healthy`
- [ ] `curl http://hello-dev.localtest.me/` が 200

## 9. 学び

CrashLoopBackOff は『状態』であって『原因』ではない。原因は必ずコンテナのログか `describe` の `Last State` にある。設定エラーで即死するアプリは、設定ミスを早く・はっきり教えてくれる良い設計（Fail fast）。
