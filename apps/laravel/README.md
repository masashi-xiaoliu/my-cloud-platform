# apps/laravel（Phase 10 の発展課題・未実装）

Laravel を My Cloud Platform に載せるときの「20% 側」の検討メモ。

| 項目 | hello-go | Laravel で追加で考えること |
|---|---|---|
| プロセス | 単一バイナリ | php-fpm + nginx（2 コンテナ or 1 Pod 2 コンテナ） |
| 設定 | env | `.env` を使わず env / ConfigMap / Secret から注入 |
| DB | なし | MySQL/PostgreSQL（Cloud SQL or StatefulSet）、`php artisan migrate` は **Job** で実行 |
| ストレージ | なし | `storage/` を Pod に持たない → Object Storage（GCS） |
| キュー | なし | `queue:work` を別 Deployment（worker） |
| スケジューラ | なし | `schedule:run` を **CronJob** |
| /healthz | あり | ルートを追加（Platform Contract を満たす） |
| /metrics | あり | exporter or nginx/php-fpm exporter を sidecar |

**80% 側（kubernetes/components, CI, Argo CD, Terraform, Monitoring）は変更しない**ことがゴール。
docs/platform-contract.md の「新規アプリのオンボーディング手順」に沿って追加する。
