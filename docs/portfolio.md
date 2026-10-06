# ポートフォリオとして何をアピールできるか

## 一言で

> 「Kubernetes のチュートリアルをやった人」ではなく、
> **小規模ながら再利用可能なクラウドプラットフォームを自分で設計・構築し、その上で CI/CD・GitOps・IaC・監視・障害対応・Rollback を、記録付きで何十回も回した人。**

## 見る人別のアピールポイント

| 見る人 | 見てほしい場所 | 伝わること |
|---|---|---|
| 経営陣・非インフラの方 | README「3. Relationship to Web / WordPress Business」 | 会社の Web 制作・運用の品質と効率を上げるための技術キャッチアップである。全案件に Kubernetes を入れるという話ではない |
| エンジニアリングマネージャー | `docs/experiments/`、`docs/learning-log.md`、`docs/case-study/` | 予想 → 実行 → 観察 → 考察を継続できる。障害報告書が書ける |
| インフラ / SRE エンジニア | `kubernetes/`（base / components / overlays）、`.github/workflows/`、`terraform/modules/`、`scripts/check-manifests.py`、`scripts/chaos.py` | 環境差分の設計、GitOps の運用（prod 手動 Sync・Git revert Rollback）、ガードレールの考え方、WIF・最小権限 SA |
| 採用担当（技術職） | README「21. Architecture Decisions」と `docs/adr/` | 技術選定の理由と代替案を説明できる |

## 定量的に示せるもの（learning-log.md から転記して README に載せる）

- 実験記録 N 本 / PR N 本 / ブラインド障害訓練 N 回（平均復旧時間 N 分 → N 分に短縮）
- `terraform destroy` → `apply` → 全アプリ復旧まで N 分（DR の再現性）
- GCP 実験の月額コスト N 円（予算アラートと destroy の運用で管理）

## 面接で話せるストーリーの例

1. **「CI は通るのに CD で落ちた」**（T04 / I14）→ kubeconform はスキーマしか見ないことに気付き、check-manifests.py にルールを追加した
2. **「HPA を入れたら Pod 数がバタついた」**（T06）→ Kustomize の適用順で replicas が復活していた。CI でガードを入れた
3. **「rollout undo したのに戻らない」**（R03）→ GitOps の selfHeal。Rollback を Git revert に統一し ADR に残した
4. **「Spot ノードが消えてもサービスは落ちなかった」**（G07）→ replicas・PDB・Probe の組み合わせで説明できる
5. **「2 つ目のアプリ（FastAPI）を載せたとき、何を共通化すべきかがわかった」**（Phase 10）→ 80/20 の境界を実体験から説明できる

## README に載せると良いもの

- Argo CD のツリー画面、Grafana ダッシュボード（負荷試験中）、PR の CI ❌ → ✅ のスクリーンショット（`docs/images/` に置く）
- Experiments 一覧表（予想が外れたものほど価値がある）
