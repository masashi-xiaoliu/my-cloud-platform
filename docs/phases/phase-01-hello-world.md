# Phase 1 — Hello World（Go → localhost）

## ゴール
`apps/hello-go` を手元で動かし、**設定（環境変数）で挙動が変わる** ことを理解する。アプリ開発ではなくインフラ学習のための準備。

## 触るファイル
`apps/hello-go/main.go`（読むだけでよい）、`main_test.go`、`metrics.go`

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | ターミナル | `make test` | 出力 | `ok ... coverage: xx%` |
| 2 | ターミナル A | `make run` | 出力 | `{"level":"INFO","msg":"listening","port":"8080"...}` |
| 3 | ターミナル B | `curl localhost:8080/` | 出力 | `Hello from My Cloud Platform (version=dev, pod=<ホスト名>)` |
| 4 | ターミナル B | `curl localhost:8080/info \| jq` | 出力 | 現在の設定が JSON で見える |
| 5 | ターミナル B | `curl localhost:8080/metrics` | 出力 | `http_requests_total{...}` が増えている |
| 6 | ターミナル A | Ctrl+C → `APP_MESSAGE= go run ./apps/hello-go` | 出力 | `invalid configuration` で即終了（exit 1） |
| 7 | ターミナル A | `cd apps/hello-go && APP_MESSAGE=hi ERROR_RATE=50 LATENCY_MS=300 go run .` → B で `curl -w ' %{http_code} %{time_total}\n' localhost:8080/` を数回 | 出力 | 約半分が 500、0.3 秒かかる |

## エンドポイント一覧（以降の Lab で使う）

| パス | 用途 | 関連 Lab |
|---|---|---|
| `/` | メッセージ。`ERROR_RATE` / `LATENCY_MS` の影響を受ける | T07, M03, M04 |
| `/info` | 現在の設定・version・pod 名 | ほぼ全部 |
| `/healthz` `/readyz` | Probe 用 | T11 |
| `/metrics` | Prometheus 用 | Phase 8 |
| `/burn?ms=200` | CPU を消費 | T03, T06 |
| `/error` | 必ず 500 | M03 |
| `/upstream` | `UPSTREAM_URL` を `MAX_RETRY` 回まで呼ぶ | T09, T17 |

## Checkpoint
- [ ] 6 で「設定ミスで起動しない」挙動を見た（→ 後の CrashLoopBackOff の正体）
- [ ] `docs/experiments/001-*.md` に最初の記録を書いた
