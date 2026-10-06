# I13: CI 失敗

> 調査フロー: **症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認**
> 記録: `docs/experiments/` にテンプレートをコピーし、調査しながら埋めていくこと。

## 0. 障害の起こし方

下の 4 パターンから 1 つ選んで PR を作る：① `main_test.go` の期待文字列を変える ② main.go のインデントを崩す ③ `deployment.yaml` のインデントを崩す ④ `terraform/` の `.tf` のインデントを崩す

→ commit → PR → Merge（ブラインド訓練なら `git diff` を見ずに進める）

## 1. 症状（ユーザー / アラートからの報告）

PR に ❌ が付き、Merge ボタンが押せない（ブランチ保護を設定済みの場合）。

## 2. 最初に打つコマンド

- PR の Checks 欄 > 失敗した Check の `Details`
- 迷ったら `./scripts/status.sh mcp-dev`（全体の俯瞰）

## 3. 見るべきところ

失敗した Job → 赤くなっている Step → ログの最後の 20 行

## 4. 仮説を書く

ここで手を止め、実験記録の **Troubleshooting** 欄に「原因はたぶん○○。なぜなら△△だから」と書く。
仮説を 1 つ検証するごとに、結果（当たり / 外れ）を書き足す。

## 5. ヒント（順番に 1 つずつ開く）

<details><summary>💡 Hint 1</summary>

どの Job が落ちたかで層がわかる: Test = アプリ / Kubernetes manifests = YAML / Terraform = IaC。

</details>

<details><summary>💡 Hint 2</summary>

ログ内の `FAIL` / `Error` / `::error::` を検索（ログ画面右上の検索窓）。

</details>

<details><summary>💡 Hint 3</summary>

手元で同じコマンドを実行して再現する（`make test` / `kustomize build` / `terraform fmt -check -recursive terraform`）。

</details>

## 6. 原因

<details><summary>✅ 原因（自分で特定してから開く）</summary>

① テスト失敗 ② gofmt 違反 ③ YAML 構文エラー（kustomize build 失敗）④ terraform fmt 違反

</details>

## 7. 修正と再デプロイ

<details><summary>🔧 修正方法</summary>

手元で修正 → 同じブランチに push → CI が自動で再実行

</details>

## 8. 復旧確認

- [ ] PR の Checks が全部 ✅

## 9. 学び

CI の役割は『壊れたものを main に入れない』こと。失敗ログを最後から読む・手元で再現する、が基本動作。詳細は [CI/CD Lab](../cicd/README.md) C02/C03。
