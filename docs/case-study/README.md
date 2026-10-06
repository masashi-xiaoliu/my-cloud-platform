# Case Study — 架空の案件を受注する（Phase 10）

> この章は「顧客とのやり取り」を模している。各ステップで **成果物（ファイル）** を作り、`docs/case-study/deliverables/` に置くこと。

## 受注内容

> **顧客（架空）: 株式会社サンプル物流**
> 「配送状況を返す Go 製の Web API を作った。クラウドにデプロイして、運用までお願いしたい。」

### 初期要件

| # | 要件 | 種別 |
|---|---|---|
| R1 | Web API（Go、既存コード = `apps/hello-go` を流用） | 20%（アプリ） |
| R2 | 3 replicas で常時稼働 | 80% の設定値 |
| R3 | CPU request 100m / Memory request 128Mi | 80% の設定値 |
| R4 | CI 必須（テストが通らないものはデプロイしない） | 80%（ci.yml） |
| R5 | main にマージされたら自動デプロイ | 80%（build.yml / Argo CD） |
| R6 | 監視必須（エラー率・応答時間・Pod 数） | 80%（monitoring） |
| R7 | 問題が起きたら 5 分以内に前のバージョンに戻せること | 80%（rollback.yml） |

## 進め方

| Step | やること | 成果物 | 参照 |
|---|---|---|---|
| 1. 要件確認 | 上の表を読み、曖昧な点を「顧客への質問リスト」にする（例: 想定アクセス数は? 停止許容時間は? 予算は? データの保存期間は?） | `deliverables/01-questions.md` | — |
| 2. Architecture | 構成図と、80% / 20% の切り分け表を書く | `deliverables/02-architecture.md` | [architecture.md](../architecture.md) |
| 3. Docker | Dockerfile が Platform Contract を満たすか確認 | — | [platform-contract.md](../platform-contract.md) |
| 4. Kubernetes | `overlays/prod` を要件どおりに（replicas 3 / requests 100m・128Mi） | PR | T01, T02, T04 |
| 5. CI | ブランチ保護で CI 必須に | スクリーンショット | Phase 4 |
| 6. CD | Build → dev 自動 → staging/prod は PR 昇格 | PR | C07 |
| 7. Monitoring | ダッシュボード + アラート 2 種 | Grafana のスクリーンショット | M01–M06 |
| 8. Deploy | v1.0.0 を prod へ | Argo CD のスクリーンショット | — |
| 9. Load Test | `./scripts/load.sh mcp-prod 4` で 10 分。p95・エラー率・CPU を記録 | `deliverables/09-load-test.md` | M02 |
| 10. Failure | 新バージョン v1.2.0 に `ERROR_RATE=30` 相当の不具合が入っていたと仮定してデプロイ | — | I07 |
| 11. Troubleshooting | アラート → ダッシュボード → ログ → 原因特定 | 障害報告書 `deliverables/11-incident-report.md` | Incident Lab |
| 12. Rollback | R7 の 5 分以内を計測しながら復旧 | 復旧時間 | R01 / R04 |
| 13. Recovery | 恒久対策（CI に何を追加するか等）を提案 | 報告書に追記 | — |

### 障害報告書テンプレート（11）

```markdown
# 障害報告書: <タイトル>
- 発生日時 / 検知日時 / 復旧日時 / 影響時間:
- 影響範囲（何%のリクエストが失敗したか。Grafana の値）:
- 検知方法（アラート名）:
- 原因:
- 対応経緯（時系列）:
- 恒久対策:
- 学び:
```

## 変更要求（Change Request）— 20% 側を増やしていく

各 CR で **「80% 側（共通基盤）を変更したか？」** を必ず自問し、変更した場合はそれが他案件でも再利用できる改善かを ADR に書く。

### CR-1「アクセスが増えたので最大 10 Pod までスケールさせたい」
- 対応: `overlays/prod` で `components/hpa` を有効化、`maxReplicas: 10`（prod 用の patch で上書き）、patch-deployment の replicas を削除
- 検証: 負荷試験で 10 まで増えること・ノードが足りるか（足りなければ G01 発展: Cluster Autoscaler）
- 80% 側の変更: なし（hpa component はそのまま再利用）
- 関連: T06, G01

### CR-2「DB が必要になった（PostgreSQL）」
- 対応（dev）: `components/postgres`（StatefulSet + PVC + headless Service）を有効化。アプリに `DATABASE_URL` を ConfigMap/Secret で渡す
- 対応（prod 想定）: `terraform/modules/database`（Cloud SQL）を `enable_database = true`。接続は Cloud SQL Auth Proxy（sidecar）+ Workload Identity
- マイグレーション: Deployment の前に **Job** で実行（Argo CD の `PreSync` hook を調べる）
- バックアップ: R05
- 判断を ADR に: 「StatefulSet で自前運用 vs マネージド（Cloud SQL）」のコスト・運用負荷比較
- 80% 側の変更: なし（component と module を追加しただけ）

### CR-3「ファイルアップロードが必要になった」
- 対応: Pod のディスクに保存しない（Pod は使い捨て・複数 replicas で共有できない）→ `terraform/modules/storage`（GCS）。アクセスは Workload Identity で（鍵ファイルなし）
- ライフサイクル: G10
- 80% 側の変更: platform-addons に何か必要か? → 不要

### CR-4「外部の配送業者 API を利用する」
- 対応: `UPSTREAM_URL` / `API_KEY`（Secret）/ `REQUEST_TIMEOUT` / `MAX_RETRY` の設計（T09, T17, T18）
- Egress 制御: NetworkPolicy の Egress で外部宛てを許可リスト化（GKE、T16 発展）
- 障害時の振る舞い: 外部 API 停止を I15 で再現し、タイムアウト・リトライ値を決める
- 80% 側の変更: Secret 管理を External Secrets + Secret Manager に移行するなら、それは **全案件で再利用できる 80% 側の改善**（ADR 0006 を更新）

## 振り返り（最後に書く）

| 観点 | 共通基盤（80%）で吸収できたこと | 案件固有（20%）として追加したこと |
|---|---|---|
| CI/CD | | |
| Kubernetes | | |
| Terraform | | |
| 監視 | | |
| セキュリティ | | |
