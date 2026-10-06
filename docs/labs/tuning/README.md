# Tuning Lab — 設定値を変えて結果を見る

各課題は **① 変更する場所 → ② 変更する値 → ③ 予想 → ④ 実行方法 → ⑤ 確認場所と成功条件 → ⑥ 失敗時の調査 → ⑦ 復旧** の 7 ステップで書かれている。
実行は [Standard Change Loop](../README.md#standard-change-loop)。リポジトリ内では `★ LAB Txx` コメントで該当箇所を探せる：

```bash
grep -rn "★ LAB T01" kubernetes/
```

| ID | テーマ | 変更する場所 | 変更する値 | 予想される結果 | 主な確認場所 | ページ |
|---|---|---|---|---|---|---|
| T01 | Replica 数 | `overlays/dev/patch-deployment.yaml` | `replicas: 1→3→10` | Pod が 3 個。10 では一部 Pending | `kubectl get pods` / Argo CD / Grafana Ready Pods | [01](01-replicas-and-resources.md) |
| T02 | CPU requests | 同上 `requests.cpu` | `50m→500m` | Pod 数を増やすと Pending（Insufficient cpu） | `kubectl describe nodes` / `describe pod` | [01](01-replicas-and-resources.md) |
| T03 | CPU limits | 同上 `limits.cpu` | `200m→50m→1000m` | throttling で応答が遅くなる（殺されない） | Grafana CPU throttling / curl 時間 | [01](01-replicas-and-resources.md) |
| T04 | Memory requests | 同上 `requests.memory` | `32Mi→128Mi→512Mi` | requests > limits は Sync で拒否 | Argo CD Sync エラー | [01](01-replicas-and-resources.md) |
| T05 | Memory limits | `config.env` `MEMORY_BALLAST_MB` + limits | `0→40→100` | 100 で OOMKilled（Exit 137） | `describe pod` Last State | [01](01-replicas-and-resources.md) |
| T06 | HPA | `components/hpa/hpa.yaml` | min/max/target/stabilization | 負荷で増え、遅れて減る | `kubectl get hpa -w` / Grafana | [02](02-hpa.md) |
| T07 | ConfigMap | `overlays/dev/config.env` `APP_MESSAGE` | 文言変更 | ハッシュ付き ConfigMap → Rolling Update | curl / Argo CD ツリー | [03](03-config-secret-env.md) |
| T09 | Env（timeout / retry / log） | `config.env` | `LOG_LEVEL` `REQUEST_TIMEOUT` `MAX_RETRY` `LATENCY_MS` | 503 timeout / リトライ回数の違い | logs / curl | [03](03-config-secret-env.md) |
| T18 | Secret | `overlays/dev/secret.env` | `API_KEY` / `REQUIRE_API_KEY` | 値は見えない・空なら起動失敗 | `/info` / logs | [03](03-config-secret-env.md) |
| T08 | Image tag | `overlays/dev/kustomization.yaml` `newTag` | `v1.0.0→v1.1.0→v999.0.0` | v999 で ImagePullBackOff、旧 Pod は残る | `get pods` / `describe pod` / Packages | [04](04-image-and-rollout.md) |
| T10 | Rolling Update | `base/deployment.yaml` `strategy` | maxSurge/maxUnavailable/Recreate | 入れ替わり方・ダウンタイムの差 | `get pods -w` / curl ループ | [04](04-image-and-rollout.md) |
| T11 | Probe | `base/deployment.yaml` probes + `STARTUP_DELAY_SECONDS` | 遅延 30s / threshold / path | startup 失敗で再起動、readiness 失敗で 0/1 | `describe pod` Events | [04](04-image-and-rollout.md) |
| T12 | Graceful shutdown | `terminationGracePeriodSeconds` | `30→1` | デプロイ中にリクエスト断 | curl ループ / logs | [04](04-image-and-rollout.md) |
| T13 | Service port | `base/service.yaml` | `port 80→8080` / `targetPort→9090` | 経路ごとに繋がる / 繋がらない | `describe svc` / port-forward | [05](05-network.md) |
| T14 | Ingress | `overlays/dev/patch-ingress.yaml` / `ingressClassName` | host / class | 404 | `get ingress` / curl -H Host | [05](05-network.md) |
| T16 | NetworkPolicy | components `network-policy` | 有効化 | 同 NS からの通信が遮断（GKE） | tmp Pod から wget | [05](05-network.md) |
| T17 | DNS / 外部 API | `config.env` `UPSTREAM_URL` | 別 NS / typo / 503 | no such host / リトライ | `/upstream` / logs / nslookup | [05](05-network.md) |
| T15 | PDB | components `pdb` | `minAvailable` × replicas | drain が止まる / 通る | `kubectl drain` / `get pdb` | [06](06-pdb-and-jobs.md) |
| T19 | Job / CronJob | `kubernetes/jobs/*.yaml` | schedule / parallelism | 定期実行・失敗検知 | `get cronjob,jobs` | [06](06-pdb-and-jobs.md) |

Terraform / GCP の設定値変更は [Terraform Lab](../terraform/README.md) と [GCP Lab](../gcp/README.md)、監視系の値は [Monitoring Lab](../monitoring/README.md)。
