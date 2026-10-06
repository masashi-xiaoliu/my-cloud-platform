# Phase 2 — Docker（Go → Docker → localhost）

## ゴール
アプリをコンテナイメージにし、「どこでも同じように動く」状態にする。Dockerfile の各行の意味を説明できる。

## 触るファイル
`apps/hello-go/Dockerfile`、`docker-compose.yml`、`docker/base/README.md`（共通ルール）

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | ターミナル | `docker build --build-arg VERSION=v0.0.1 -t hello-go:v0.0.1 apps/hello-go` | 出力 | `naming to docker.io/library/hello-go:v0.0.1` |
| 2 | ターミナル | `docker images hello-go` | SIZE 列 | 十数 MB 程度（マルチステージ + distroless の効果） |
| 3 | ターミナル | `docker run --rm -p 8080:8080 -e APP_MESSAGE="from docker" hello-go:v0.0.1` → 別ターミナルで `curl localhost:8080/` | 出力 | `from docker (version=v0.0.1, ...)` |
| 4 | ターミナル | `docker run --rm hello-go:v0.0.1` | 出力 | `APP_MESSAGE is required`（環境変数なし） |
| 5 | ターミナル | `docker run --rm -it hello-go:v0.0.1 sh` | 出力 | 失敗する（シェルがない = distroless） |
| 6 | ターミナル | `make docker-run`（= `docker compose up --build`） | `curl localhost:8080/info` | compose の environment が反映 |
| 7 | エディタ | `docker-compose.yml` の `APP_MESSAGE` を変更 → `docker compose up -d` | curl | メッセージが変わる（イメージは再ビルドされない） |

## 実験アイデア
- `FROM gcr.io/distroless/...` を `FROM alpine:3.20` に変えてサイズを比較 → 記録
- `.dockerignore` を消して `docker build` のコンテキスト転送量の変化を見る
- `docker run --memory=20m ...  -e MEMORY_BALLAST_MB=50` → OOM（Kubernetes の T05 の予習）

## Checkpoint
- [ ] build-arg `VERSION` が `/info` に出ることを確認
- [ ] 「イメージ = 不変、設定 = 外から注入」を説明できる
