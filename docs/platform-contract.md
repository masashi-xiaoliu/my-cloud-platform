# Platform Contract — 80% 共通基盤 / 20% 案件固有

## 考え方

```text
┌──────────────────────────── 20% 案件固有 ────────────────────────────┐
│ apps/<app>/（コード・Dockerfile）  overlays/<env>/config.env・secret.env │
│ 案件固有 component（postgres 等）   terraform/environments/<env>/*.tfvars │
└───────────────────────────────▲──────────────────────────────────────┘
                                │ Platform Contract（下の約束）を守れば何でも載る
┌──────────────────────────── 80% 共通基盤 ────────────────────────────┐
│ Git フロー / PR / CI (ci.yml)  Build・Deploy・Rollback workflow          │
│ kubernetes/base の型・components（hpa / monitoring / pdb / netpol）       │
│ Argo CD（AppProject / App of Apps）  Terraform modules（network / gke /   │
│ registry / platform-addons）  監視（Prometheus / Grafana / アラート）      │
│ セキュリティ既定値（non-root / readOnlyRootFS / WIF / 最小権限 SA）       │
│ 運用手順（Labs / Runbook / Rollback / destroy）                          │
└──────────────────────────────────────────────────────────────────────┘
```

**20% 側を変更しても、80% 側はできるだけ変更しない。** 80% 側を変えるのは「他の案件でも役立つ改善」のときだけ（ADR に残す）。

## アプリが守る約束（Contract）

| # | 約束 | 理由（基盤側の何が依存しているか） | hello-go | fastapi |
|---|---|---|---|---|
| 1 | `PORT` 環境変数（既定 8080）で HTTP を待ち受ける | Service / Probe / NetworkPolicy が共通 | ✅ | ✅ |
| 2 | `GET /healthz` = 生存、`GET /readyz` = 受付可能 | Deployment の Probe が共通 | ✅ | ✅ |
| 3 | `GET /metrics` で Prometheus 形式、`http_requests_total{code,path}` と `http_request_duration_seconds` を出す | ServiceMonitor / ダッシュボード / アラートが共通 | ✅ | ✅ |
| 4 | 設定はすべて環境変数（ConfigMap / Secret から注入） | overlays の config.env / secret.env が共通 | ✅ | ✅ |
| 5 | 必須設定がなければ起動時に非 0 で終了（Fail fast） | CrashLoopBackOff で設定ミスを即検知 | ✅ | ✅ |
| 6 | ログは標準出力に 1 行 1 JSON | ログ基盤・jq 検索が共通 | ✅ | △（uvicorn 既定） |
| 7 | SIGTERM で graceful shutdown | Rolling Update で無停止 | ✅ | ✅（uvicorn） |
| 8 | 非 root で動き、ルートファイルシステムに書かない | securityContext が共通 | ✅ | ✅（/tmp 書込みに注意） |
| 9 | ステートレス（状態は DB / Object Storage へ） | replicas / HPA / Pod 使い捨てが前提 | ✅ | ✅ |
| 10 | イメージタグは `vX.Y.Z` / `sha-...`（latest 禁止） | Rollback / 追跡 / check-manifests | ✅ | ✅ |

## 新規アプリのオンボーディング手順（例: FastAPI）

| # | やること | 変更するファイル | 80/20 |
|---|---|---|---|
| 1 | Contract を満たすアプリと Dockerfile を用意 | `apps/fastapi/*` | 20 |
| 2 | ローカルで確認 `docker compose --profile fastapi up --build` → `curl localhost:8081/metrics` | — | — |
| 3 | build.yml を matrix 化（`app: [hello-go, fastapi]`）して `apps/<app>` ごとにビルド | `.github/workflows/build.yml` | **80 の改善**（以後どのアプリも追加 1 行） |
| 4 | `kubernetes/base` を `kubernetes/apps/<app>/base` に移し、共通部分を component 化する（発展リファクタリング） | `kubernetes/` | **80 の改善** |
| 5 | `overlays/<env>` に fastapi 用を追加（images / config.env） | `kubernetes/apps/fastapi/overlays/dev` | 20 |
| 6 | Argo CD Application を追加 | `argocd/applications/fastapi-dev.yaml` | 20（テンプレートどおり） |
| 7 | ダッシュボードの `job` 変数を追加 | `monitoring/grafana/dashboards` | 80（汎用化） |
| 8 | 監視・アラート・Rollback がそのまま動くことを確認 | — | — |

> ステップ 3・4・7 のように「2 つ目のアプリを載せたときに初めて汎用化が必要だとわかる」部分こそ、Platform 設計の学びどころ。最初から汎用化しすぎない（YAGNI）。

## 20% の典型パターンと、基盤側の受け皿

| 案件固有要件 | 受け皿（このリポジトリ） | 状態 |
|---|---|---|
| Database | `components/postgres` / `modules/database` | ✅ |
| File processing / Upload | `modules/storage` | ✅ |
| External API | `UPSTREAM_URL` / Secret / NetworkPolicy Egress | ✅（Egress は発展） |
| Authentication | Ingress の ForwardAuth（Traefik middleware）/ IAP | 📝 Future |
| Queue / Worker | 別 Deployment（同じ base を再利用）+ Pub/Sub | 📝 Future |
| Batch | `kubernetes/jobs`（Job / CronJob） | ✅ |
| High traffic | HPA + Cluster Autoscaler + CDN | 🔶 HPA まで |
| Special networking | Private nodes + NAT / Firewall | ✅ |
| GPU | GPU ノードプール（node_pool を追加） | 📝 Future |
