# CI/CD Lab — GitHub Actions と Argo CD

GitHub Actions（CI）と Argo CD（CD）を、**ボタンの位置レベル** で操作できるようになるための実習。

## GitHub Actions 画面の歩き方

```text
GitHub リポジトリ
 └─ 上部タブ「Actions」
     ├─ 左サイドバー: ワークフロー一覧（CI / Build / Deploy / Rollback / Terraform Plan）
     │    └─ ワークフローを選ぶと右上に「Run workflow ▼」ボタン（workflow_dispatch があるものだけ）
     └─ 中央: 実行（Run）の一覧 … ✅ 成功 / ❌ 失敗 / 🟡 実行中
          └─ Run をクリック
              ├─ Summary: Job のグラフ（test → docker など依存関係）と Job Summary（$GITHUB_STEP_SUMMARY の出力）
              └─ 左の Job 名をクリック
                  └─ Step の一覧（▶ を開くとログ）。失敗した Step は赤で自動的に開く
                       右上 ⚙ > 「View raw logs」で全文、検索窓でログ内検索
```

## ワークフロー一覧と各 Step の意味

| ワークフロー | いつ動く | Step の流れ | 成功したらどこに何が出るか |
|---|---|---|---|
| **CI** (`ci.yml`) | すべての push / PR / 手動 | Checkout → Setup Go → Format check → Vet → **Run tests** → Docker build (no push) → kustomize build + kubeconform + check-manifests → terraform fmt / validate | PR の Checks 欄に ✅ が 4 つ |
| **Build** (`build.yml`) | main の `apps/hello-go/**` 変更 / `v*` タグ / 手動 | Checkout → タグ決定 → Buildx → GHCR ログイン → **Docker build & push** → (Deploy to dev を呼ぶ) | リポジトリ右側「Packages」> hello-go に新しいタグ |
| **Deploy** (`deploy.yml`) | Build から自動 / 手動 | Checkout main → **Guardrail（イメージ存在確認）** → kustomize edit set image → dev: main に commit / staging・prod: PR 作成 | dev: main に `deploy(dev): ...` コミット、staging/prod: 新しい PR |
| **Rollback** (`rollback.yml`) | 手動のみ | 直近の deploy コミットを `git revert` / 指定タグに書き戻し | main に revert コミット or Rollback PR |
| **Terraform Plan** (`terraform-plan.yml`) | `terraform/**` を変える PR（GCP 設定後） | WIF 認証 → init → **plan** → Job Summary に差分 | Run の Summary に `Plan: N to add...` |

## 初回だけ必要な GitHub 設定

| 設定 | 場所 | 値 | 理由 |
|---|---|---|---|
| Actions の書き込み権限 | Settings > Actions > General > Workflow permissions | **Read and write permissions** と **Allow GitHub Actions to create and approve pull requests** に ✅ | deploy.yml が main へ push / PR 作成するため |
| ブランチ保護（推奨） | Settings > Rules > Rulesets > New branch ruleset（対象: main） | Require a pull request / Require status checks: `Test (hello-go)`, `Kubernetes manifests`, `Terraform fmt / validate`。**Bypass list に GitHub Actions を追加** | 人は PR 必須、dev への自動デプロイ（bot）は直接 push を許可 |
| パッケージの公開 | 初回 Build 後: Packages > hello-go > Package settings > Change visibility | **Public** | kind が認証なしで pull できるように（Private のままなら imagePullSecrets が必要 = I02 の発展） |

> ⚠ `GITHUB_TOKEN` で行った push は、他のワークフローを起動しない（無限ループ防止の GitHub の仕様）。deploy コミットで CI が走らないのはそのため。


## 目次

- [C01: CI を手動で実行してログを読む](#c01-ci-を手動で実行してログを読む)
- [C02: CI を意図的に失敗させる（テスト）](#c02-ci-を意図的に失敗させるテスト)
- [C03: マニフェストのガードレールに引っかかる](#c03-マニフェストのガードレールに引っかかる)
- [C04: イメージをビルドして Registry に push する](#c04-イメージをビルドして-registry-に-push-する)
- [C05: GitOps の反映を観察する（Argo CD）](#c05-gitops-の反映を観察するargo-cd)
- [C06: selfHeal と prune を体験する](#c06-selfheal-と-prune-を体験する)
- [C07: staging → prod への昇格（Promotion）](#c07-staging--prod-への昇格promotion)
- [C08: Argo CD のポーリング間隔](#c08-argo-cd-のポーリング間隔)

---

## C01: CI を手動で実行してログを読む

> Phase 4 以降 ｜ 所要 15 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | GitHub > Actions > CI |
| ② 変更する値 | （変更なし）手動実行 |
| ③ 予想される結果 | 4 つの Job が並列〜順に実行され、すべて ✅ |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. GitHub でリポジトリを開く
2. 上部タブ **Actions** をクリック
3. 左サイドバーで **CI** をクリック
4. 右上の **Run workflow ▼** をクリック
5. **Use workflow from** で `Branch: main` を選択
6. 緑の **Run workflow** ボタンをクリック
7. 数秒後、一覧の一番上に 🟡 の Run が現れる → クリック
8. Summary の Job グラフで `Test (hello-go)` → `Docker build (no push)` の依存関係を確認
9. 左の **Test (hello-go)** をクリック → Step 一覧の **Run tests** を ▶ で開きログを読む

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Actions > CI > 該当 Run | Summary | すべての Job に ✅、所要時間が表示される |
| Job > Run tests の Step | ログ | `ok  github.com/.../hello-go  coverage: xx% of statements` |
| Job > Kubernetes manifests | Build & validate overlays の Step | `Summary: N resources ... Invalid: 0` が 4 環境分 |

### ⑥ うまくいかない場合の調査

- Run workflow ボタンがない → ci.yml に `workflow_dispatch:` があるか / デフォルトブランチに push 済みか

### ⑦ 復旧方法

- （なし）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

CI は『マージしてよいか』の自動判定。各 Step はただのシェルコマンドなので、ログに出ているコマンドを手元で実行すれば必ず再現できる。

</details>

---

## C02: CI を意図的に失敗させる（テスト）

> Phase 4 以降 ｜ 所要 20 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `apps/hello-go/main_test.go` の `TestRootReturnsMessage`（`★ LAB (CI-01)`） |
| ② 変更する値 | `"Hello from My Cloud Platform"` → `"Hello from Your Cloud Platform"` |
| ③ 予想される結果 | `Test (hello-go)` Job が ❌、後続の `Docker build` は実行されない（needs: test のため） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `git switch -c lab/c02-break-test`
2. 上記の値を変更
3. `git commit -am 'test: break on purpose' && git push -u origin HEAD`
4. GitHub に表示される **Compare & pull request** から PR を作成
5. PR 下部の Checks 欄を見る

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| PR > Checks | ❌ の行の **Details** | `Test (hello-go)` が失敗 |
| Job > Run tests | ログ末尾 | `--- FAIL: TestRootReturnsMessage` と `body = "...", want it to contain ...` |
| Run の Summary | Job グラフ | `Docker build (no push)` が Skipped（灰色） |

### ⑥ うまくいかない場合の調査

- ログの最後から読む。`FAIL` の直前の行が原因
- 手元で `make test` を実行して同じエラーが出るか確認

### ⑦ 復旧方法

- 値を元に戻して同じブランチに push → CI が自動で再実行 → ✅ になったら PR を Close（または Merge）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

needs で依存関係を張ると、前段が失敗した時点で後続が止まり、無駄な実行と『テストが落ちているのにイメージができる』事故を防げる。

</details>

**🔁 発展（もう一周）**

- gofmt 違反（インデント崩し）/ YAML 構文エラー / terraform fmt 違反でも同じことを行い、どの Job が落ちるか比較（Incident Lab I13）

---

## C03: マニフェストのガードレールに引っかかる

> Phase 4 以降 ｜ 所要 15 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/kustomization.yaml` の components |
| ② 変更する値 | `../../components/hpa` を有効化し、patch-deployment.yaml の replicas は **消さない** |
| ③ 予想される結果 | CI の `Kubernetes manifests` が ❌（check-manifests.py が検出） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. ブランチを切って変更 → push → PR

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| PR > Checks > Kubernetes manifests | ログ / Annotations | `::error::Deployment/hello-go: HPA があるのに spec.replicas が設定されています` |

### ⑥ うまくいかない場合の調査

- `kustomize build kubernetes/overlays/dev | python3 scripts/check-manifests.py` で手元再現

### ⑦ 復旧方法

- replicas 行を削除して push（T06 の正しい手順）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

『このチームでよく起きる事故』をスクリプト化して CI に入れるのが Platform Engineering の本質。scripts/check-manifests.py にルールを足していくことが、そのまま 80% 側の資産になる。

</details>

**🔁 発展（もう一周）**

- T04 の『requests > limits』を検出するルールを追加する

---

## C04: イメージをビルドして Registry に push する

> Phase 4 以降 ｜ 所要 20 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | GitHub > Actions > Build |
| ② 変更する値 | version: `v1.1.0` |
| ③ 予想される結果 | GHCR に `hello-go:v1.1.0` が作られる（Phase 5 以降は dev に自動デプロイ） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. Actions > **Build** > **Run workflow ▼**
2. Branch: `main`、version: `v1.1.0`、deploy_to_dev: ✅（Phase 4 時点では Argo CD がないので ☐ でもよい）
3. **Run workflow**
4. Run を開き `Build & Push image` Job の **Docker build & push** Step を読む

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Run の Summary | Job Summary | `### Image: ghcr.io/<user>/hello-go:v1.1.0` |
| リポジトリトップ右側 > Packages > hello-go | タグ一覧 | `v1.1.0` と `sha-<40桁>` がある |
| ターミナル | `docker pull ghcr.io/<user>/hello-go:v1.1.0 && docker run --rm -e APP_MESSAGE=hi -p 8080:8080 ghcr.io/<user>/hello-go:v1.1.0` | `curl localhost:8080/` で `version=v1.1.0` |

### ⑥ うまくいかない場合の調査

- `denied: permission_denied` → Workflow permissions（上表）を確認
- push できたが pull できない → パッケージが Private

### ⑦ 復旧方法

- （なし）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

イメージのタグは『何がどこで動いているか』を追跡するための ID。`latest` を使わず、セマンティックバージョンとコミット SHA の両方を付けることで、Pod → イメージ → コミット → PR まで辿れる。

</details>

---

## C05: GitOps の反映を観察する（Argo CD）

> Phase 5 以降 ｜ 所要 20 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/overlays/dev/config.env`（任意の値） |
| ② 変更する値 | APP_MESSAGE を変更（T07 と同じ） |
| ③ 予想される結果 | Merge 後、最大 3 分（既定のポーリング間隔）以内に Argo CD が OutOfSync を検知 → 自動 Sync → Synced / Healthy |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. [SCL-GitOps](../README.md#standard-change-loop) の手順で dev に反映
2. Merge 直後に Argo CD UI を開いたまま待つ。待てなければ **Refresh** ボタン

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Argo CD UI > Applications | hello-go-dev のカード | `OutOfSync` → `Syncing` → `Synced`、Health `Progressing` → `Healthy` |
| Argo CD UI > hello-go-dev > 上部 **History and Rollback** | Revision 一覧 | Merge コミットの SHA が最上段 |
| Argo CD UI > hello-go-dev > ツリー | Deployment をクリック > **Diff**（Sync 前） | 変更した値の差分が見える |

### ⑥ うまくいかない場合の調査

- いつまでも反映されない → Application の `targetRevision` / `path` / repoURL
- Refresh で `ComparisonError` → kustomize build がエラー（I14）

### ⑦ 復旧方法

- （なし）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Argo CD は (1) Git から desired state をレンダリング (2) クラスタの live state と比較 (3) 差分があれば OutOfSync (4) automated なら Sync、を周期的に行う。CI/CD パイプラインからクラスタへの認証情報が不要（Pull 型）なのが GitOps のセキュリティ上の利点。

</details>

---

## C06: selfHeal と prune を体験する

> Phase 5 以降 ｜ 所要 20 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | クラスタを直接操作 / `argocd/applications/hello-go-dev.yaml` の `syncPolicy.automated` |
| ② 変更する値 | ① `kubectl -n mcp-dev scale deploy hello-go --replicas=4` ② `kubectl -n mcp-dev delete svc hello-go` ③ selfHeal: `false` にして①を再実行 |
| ③ 予想される結果 | ①② 数十秒以内に Argo CD が Git の状態に戻す ③ 戻らず OutOfSync のまま |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. ①② を実行し `kubectl -n mcp-dev get deploy,svc -w` で観察
2. ③ は Application YAML を変更して PR（root app が Application 自体を Sync する）

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `kubectl -n mcp-dev get deploy hello-go` | ① replicas が 1 に戻る |
| Argo CD UI > `hello-go-dev` | Events / History | `self-healed` に相当する Sync が記録 |

### ⑥ うまくいかない場合の調査

- ③ のあと UI で OutOfSync の差分（Diff）を確認

### ⑦ 復旧方法

- selfHeal: true に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

selfHeal は『手作業の変更（drift）を許さない』設定。本番で誰かが kubectl で直したつもりでも Git に戻される。だから GitOps では **修正も必ず Git 経由**。prune は Git から消したリソースをクラスタからも消す設定。

</details>

**🔁 発展（もう一周）**

- prune: false にして overlay から Ingress を消すと何が残るか

---

## C07: staging → prod への昇格（Promotion）

> Phase 5 以降 ｜ 所要 30 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | Actions > Deploy |
| ② 変更する値 | environment: `staging`、image_tag: dev で確認済みのタグ → 次に `prod` |
| ③ 予想される結果 | staging は PR が作られ、Merge で自動反映。prod は Merge しても **反映されず**、Argo CD で手動 Sync して初めて反映 |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. Actions > **Deploy** > Run workflow > environment `staging` / image_tag `v1.1.0`
2. 作成された PR（`deploy(staging): ...`）をレビューして Merge
3. 同様に environment `prod` で実行 → PR を Merge
4. Argo CD UI > hello-go-prod > `OutOfSync` を確認 > **SYNC** > **SYNCHRONIZE**

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GitHub > Pull requests | Deploy が作った PR | 本文に確認手順が書かれている |
| Argo CD UI > hello-go-prod | Merge 直後 | `OutOfSync`（automated がないため） |
| ターミナル | `curl http://hello.localtest.me/info` | SYNC 後に version が変わる |

### ⑥ うまくいかない場合の調査

- PR が作られない → Workflow permissions の『create and approve pull requests』

### ⑦ 復旧方法

- Rollback workflow（R01）を environment `prod` で実行

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

同じイメージ（同じタグ）を dev → staging → prod と昇格させるのが原則。環境ごとにビルドし直すと『staging で試したものと本番が違う』ことになる。prod だけ手動 Sync にすることで、Merge（変更の承認）とリリース（反映のタイミング）を分離できる。

</details>

---

## C08: Argo CD のポーリング間隔

> Phase 6 以降 ｜ 所要 15 分

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `terraform/modules/platform-addons/main.tf` の `timeout.reconciliation`（`★ LAB C07`）または local の変数 |
| ② 変更する値 | `60s` → `10s` |
| ③ 予想される結果 | Merge から反映までの時間が短くなる |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. terraform plan → apply（Phase 6 以降）
2. T07 を行い、Merge から Synced までの時間を計測

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Argo CD UI | LAST SYNC の時刻 | Merge 時刻との差 |

### ⑥ うまくいかない場合の調査

- 反映されない → `kubectl -n argocd rollout restart deploy argocd-repo-server`（設定の再読込）

### ⑦ 復旧方法

- `60s` に戻す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

ポーリングを短くすると GitHub API へのリクエストが増える（レート制限）。実務では GitHub の Webhook を Argo CD に向けて即時反映するのが一般的。

</details>

**🔁 発展（もう一周）**

- Argo CD に Webhook を設定するには何が必要か調べる（外部から到達可能な URL）

---
