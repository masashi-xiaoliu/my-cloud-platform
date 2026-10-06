# Labs — 触って・変えて・壊して・直す

このディレクトリの課題をこなすこと自体が、クラウドエンジニアの訓練になるように設計している。

## Standard Change Loop

**すべての Lab の「④ 実行方法」は、特に断りがない限りこのループで行う。** 1 回の変更 = 1 PR。

### SCL-GitOps（Phase 5 以降の基本形）

| # | 操作場所 | やること | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 0 | `docs/experiments/` | `cp docs/experiments/TEMPLATE.md docs/experiments/NNN-<名前>.md` し、**Objective / Current / Change / Prediction** を書く | エディタ | 予想が文章で書けている |
| 1 | ターミナル | `git switch main && git pull && git switch -c lab/<ID>-<短い名前>` | `git branch` | 新ブランチにいる |
| 2 | エディタ | Lab の「① 変更する場所」の「② 値」を変更 | `git diff` | 意図した 1 箇所だけ変わっている |
| 3 | ターミナル | `kustomize build kubernetes/overlays/dev \| less`（任意：適用される最終形を見る） | 出力 | 変更が反映されている |
| 4 | ターミナル | `git commit -am "lab(<ID>): <内容>" && git push -u origin HEAD` | GitHub | ブランチが push された |
| 5 | GitHub | **Compare & pull request** → PR 作成 | PR 下部の **Checks** | CI が全部 ✅（❌ なら [CI/CD Lab](cicd/README.md) C02 の手順で調査） |
| 6 | GitHub | **Merge pull request**（→ Delete branch） | main のコミット履歴 | Merge コミットがある |
| 7 | Argo CD UI | `hello-go-dev` を開く（待てなければ **Refresh**） | Sync / Health | `Synced` + `Healthy`（prod は手動 **SYNC**） |
| 8 | ターミナル / Grafana | Lab の「⑤ 確認場所」を見る | 各 Lab の表 | 成功条件どおり |
| 9 | `docs/experiments/` | **Observation / Verification / Why / Lessons** を書いて commit | — | 予想と結果の差を説明できる |

### SCL-Local（Phase 3〜4、Argo CD 導入前）

`kubernetes/overlays/local/` を編集 → `kubectl apply -k kubernetes/overlays/local` → `kubectl -n mcp-local get pods -w` → `curl http://hello-local.localtest.me/`

### SCL-Terraform

`terraform plan` → **差分を読んで実験記録に貼る**（`+` / `~` / `-/+` / `-` と最終行）→ `terraform apply` → 実物を確認（kubectl / GCP Console）→ 必要なら `destroy`

## Lab 一覧

| カテゴリ | 内容 | ページ |
|---|---|---|
| **Tuning Lab** | replicas / requests / limits / HPA / ConfigMap / Secret / env / image / rollout / probe / service / ingress / DNS / NetworkPolicy / PDB / Job（T01–T19） | [tuning/](tuning/README.md) |
| **CI/CD Lab** | GitHub Actions の操作、CI を壊す、ビルド、GitOps 反映、selfHeal、昇格（C01–C08） | [cicd/](cicd/README.md) |
| **Incident Response Lab** | 障害注入とトラブルシューティング（I01–I16）、ブラインド訓練 | [incident/](incident/README.md) |
| **Rollback / Recovery Lab** | revert / タグ指定 / rollout undo の罠 / Argo CD Rollback / データ復旧（R01–R05） | [recovery/](recovery/README.md) |
| **Monitoring Lab** | Grafana / Prometheus / アラート / ログ（M01–M08） | [monitoring/](monitoring/README.md) |
| **Terraform Lab** | plan の読み方、変数、state、ドリフト、destroy と再構築（TF-01–TF-08） | [terraform/](terraform/README.md) |
| **GCP Lab** | 予算、ノード、マシンタイプ、CIDR、Firewall、NAT、Spot、Registry（G00–G10） | [gcp/](gcp/README.md) |

## 進め方のルール

1. **予想してから実行する。** 予想が外れたところが一番の学び。
2. **1 回に 1 つだけ変える。** 複数同時に変えると因果がわからない。
3. **答え（Answer）は最後に開く。** Hint → 調査 → 仮説 → 検証 → それでも分からなければ Answer。
4. **必ず元に戻す。** `./scripts/reset.sh dev` → PR → Merge までが 1 セット。
5. **記録する。** `docs/experiments/` が増えていくこと＝ポートフォリオが育つこと。
