# Rollback / Recovery Lab

壊れた状態から『以前の正常な状態』に戻す手順を、GitOps のやり方で体に覚えさせる。

> 原則: **止血（Rollback）→ 原因調査 → 恒久対策** の順。原因がわかるまで待たない。

## 目次

- [R01: Rollback workflow（直前のデプロイを revert）](#r01-rollback-workflow直前のデプロイを-revert)
- [R02: 既知の正常タグを指定して戻す](#r02-既知の正常タグを指定して戻す)
- [R03: kubectl rollout undo の罠](#r03-kubectl-rollout-undo-の罠)
- [R04: Argo CD UI からの Rollback](#r04-argo-cd-ui-からの-rollback)
- [R05: データの復旧（PVC / Cloud SQL バックアップ）](#r05-データの復旧pvc--cloud-sql-バックアップ)

---

## R01: Rollback workflow（直前のデプロイを revert）

> Phase 5 以降 ｜ 所要 20 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | Actions > Rollback |
| ② 変更する値 | environment `dev`、mode `revert-last-deploy` |
| ③ 予想される結果 | main に `Revert "deploy(dev): ..."` コミット → Argo CD が旧タグに戻す |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. まず T08 ② / I02 で壊れたバージョンを dev にデプロイしておく
2. 課題: **『本番環境で問題が発生したと仮定し、以前のバージョンへ復旧してください』**
3. Actions > **Rollback** > Run workflow > environment `dev` / mode `revert-last-deploy` > Run

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| GitHub > Commits | main の履歴 | `Revert "deploy(dev): ..."` がある |
| Argo CD UI > `hello-go-dev` | History | Revert コミットで Sync |
| ターミナル | `kubectl -n mcp-dev get pods` / `curl .../info` | 全 Pod が旧バージョンで Running |

### ⑥ うまくいかない場合の調査

- revert 対象が違う → `git log -- kubernetes/overlays/dev/kustomization.yaml` で直近コミットを確認

### ⑦ 復旧方法

- （これ自体が復旧手順）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

GitOps では『Git を戻す = 環境を戻す』。履歴が残るので、いつ・誰が・何を戻したかが監査できる。

</details>

---

## R02: 既知の正常タグを指定して戻す

> Phase 5 以降 ｜ 所要 10 分 ｜ 環境: dev / prod

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | Actions > Rollback |
| ② 変更する値 | mode `set-tag`、image_tag `v1.0.0` |
| ③ 予想される結果 | dev は即反映、prod は PR が作られる |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. Actions > Rollback > mode `set-tag` / image_tag `v1.0.0`

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| ターミナル | `curl .../info` | version が v1.0.0 |

### ⑥ うまくいかない場合の調査

- Guardrail で止まる → 指定したタグが存在しない

### ⑦ 復旧方法

- —

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

revert は『直前に戻す』、set-tag は『確実に動いていたものに戻す』。複数回デプロイした後は set-tag の方が確実。

</details>

---

## R03: kubectl rollout undo の罠

> Phase 5 以降 ｜ 所要 15 分 ｜ 環境: dev

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | クラスタ直接 |
| ② 変更する値 | `kubectl -n mcp-dev rollout undo deploy/hello-go` |
| ③ 予想される結果 | 一瞬旧バージョンに戻るが、Argo CD の selfHeal が Git の（壊れた）状態に戻す |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. 壊れたバージョンをデプロイした状態で上記を実行し、`kubectl -n mcp-dev get rs -w` で観察

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Argo CD UI > `hello-go-dev` | History / Events | auto-sync で再び壊れた状態に |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- R01 / R02 で Git を直す

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

GitOps 環境では『クラスタを直接戻す』手順は使えない（使うなら先に Argo CD の auto-sync を止める必要がある）。障害時に慌てて従来の手順を使うと復旧が遅れる、という実務上の教訓。

</details>

---

## R04: Argo CD UI からの Rollback

> Phase 5 以降 ｜ 所要 15 分 ｜ 環境: prod

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | Argo CD UI > hello-go-prod > History and Rollback |
| ② 変更する値 | 1 つ前の Revision の `⋮` > Rollback |
| ③ 予想される結果 | prod（auto-sync なし）は UI から旧リビジョンに戻せる。Git とはズレる（OutOfSync 表示） |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. prod に新バージョンを Sync した状態で、History and Rollback を開く
2. 旧 Revision の `⋮` > **Rollback** > OK

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| Argo CD UI | hello-go-prod | Healthy かつ OutOfSync |
| ターミナル | `curl http://hello.localtest.me/info` | 旧バージョン |

### ⑥ うまくいかない場合の調査

- auto-sync が有効な Application では Rollback ボタンが使えない

### ⑦ 復旧方法

- その後必ず Git も揃える（R02 を prod で実行し PR を Merge）

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

UI Rollback は『最速の止血』だが Git とクラスタがズレる。止血 → Git を正す、の 2 段階で後始末までが復旧。

</details>

---

## R05: データの復旧（PVC / Cloud SQL バックアップ）

> Phase 10 以降 ｜ 所要 40 分 ｜ 環境: dev（Case Study CR-2 後）

| ステップ | 内容 |
|---|---|
| ① 変更する場所 | `kubernetes/components/postgres` / `terraform/modules/database` の `backup_enabled` |
| ② 変更する値 | ① postgres Pod を削除 ② PVC を削除（!）③ Cloud SQL: バックアップから別インスタンスに復元 |
| ③ 予想される結果 | ① データは残る ② データは消える ③ バックアップ時点のデータが戻る |

> 📝 先に `docs/experiments/` にファイルを作り、**Prediction** 欄に自分の予想を書いてから実行すること。

### ④ 実行方法

1. `kubectl -n mcp-dev exec -it postgres-0 -- psql -U app -c 'create table t(x int); insert into t values (1);'`
2. ① `kubectl -n mcp-dev delete pod postgres-0` → 復活後に `select * from t;`
3. ② StatefulSet を 0 にして `kubectl -n mcp-dev delete pvc data-postgres-0` → 戻して確認
4. ③ GCP Console > SQL > インスタンス > Backups > 復元

### ⑤ 確認場所と成功条件

| どこを見るか | 何をする / コマンド | 成功条件 |
|---|---|---|
| psql | `select * from t;` | ① 1 行 ② エラー（テーブルなし） |

### ⑥ うまくいかない場合の調査

- —

### ⑦ 復旧方法

- バックアップなしでは ② は復旧不能 → それが学び

<details><summary>✅ Answer / なぜその挙動になるのか（調べ終わってから開く）</summary>

Pod は使い捨て、データは PVC（＝ディスク）に残る。ただしディスク自体を消せば終わり。『Kubernetes は自己修復する』はステートレスな部分の話で、データの保護はバックアップと復元訓練でしか担保できない。

</details>

---
