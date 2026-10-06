# Phase 0 — Setup（初回のみ・約 60 分）

## ゴール
必要なツールが入り、自分の GitHub にこのリポジトリがあり、`./scripts/setup.sh` が ✅ だけを表示する。

## 必要なもの

| ツール | 用途 | インストール例（macOS / Homebrew） | 確認コマンド |
|---|---|---|---|
| Git | バージョン管理 | `brew install git` | `git --version` |
| Docker Desktop（または OrbStack / Colima） | コンテナ実行、kind の土台 | 公式サイトから | `docker info` |
| Go 1.23+ | アプリのビルド・テスト | `brew install go` | `go version` |
| kubectl | Kubernetes 操作 | `brew install kubectl` | `kubectl version --client` |
| kind | ローカル Kubernetes | `brew install kind` | `kind version` |
| Helm | チャートのインストール | `brew install helm` | `helm version` |
| kustomize | マニフェスト生成 | `brew install kustomize` | `kustomize version` |
| Terraform 1.6+ | IaC | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` | `terraform version` |
| jq | JSON ログの絞り込み | `brew install jq` | `jq --version` |
| gh（任意） | GitHub CLI | `brew install gh` | `gh auth status` |
| gcloud（Phase 7） | GCP 操作 | `brew install --cask google-cloud-sdk` | `gcloud version` |

> Docker Desktop のメモリは **6GB 以上** を推奨（Phase 8 の Prometheus/Grafana まで動かすため）。Settings > Resources で設定。

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | GitHub | 右上 **+** > **New repository** > 名前 `my-cloud-platform` / **Public** / README なしで作成 | ブラウザ | 空のリポジトリができる |
| 2 | ターミナル | このファイル一式を置いたディレクトリで `git init -b main && git remote add origin https://github.com/<you>/my-cloud-platform.git` | `git remote -v` | origin が表示 |
| 3 | ターミナル | `./scripts/setup.sh <you>` | 出力 | すべて ✅、`masashi-xiaoliu` が置換された |
| 4 | ターミナル | `git add -A && git commit -m "chore: initial import" && git push -u origin main` | GitHub > Code | ファイルが表示される |
| 5 | GitHub | Settings > Actions > General > Workflow permissions > **Read and write** + **Allow GitHub Actions to create and approve pull requests** > Save | 同画面 | 設定が保存された |
| 6 | ターミナル | `git tag lab-baseline && git push origin lab-baseline` | GitHub > Tags | `lab-baseline` がある（`reset.sh` の戻り先） |
| 7 | GitHub | Actions タブ | 一覧 | push によって **CI** が走り ✅（失敗したら [I13](../labs/incident/I13-ci-failure.md)） |

## Checkpoint
- [ ] `./scripts/setup.sh` がエラーなし
- [ ] GitHub Actions の CI が ✅
- [ ] `lab-baseline` タグがある
