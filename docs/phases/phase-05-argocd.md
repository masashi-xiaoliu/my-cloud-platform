# Phase 5 — Argo CD（GitOps）

## ゴール
**Git を書き換えるとクラスタが変わる** 状態を作る。以後、クラスタへの変更はすべて PR 経由。

## 触るファイル
`argocd/bootstrap/root.yaml`、`argocd/projects/*`、`argocd/applications/*`、`kubernetes/overlays/{dev,staging,prod}`、`.github/workflows/deploy.yml` `rollback.yml`

## フロー

```text
Developer ─PR─▶ GitHub ─merge─▶ Actions(Build) ─push─▶ GHCR
                                     └─ Deploy: overlays/dev の newTag を書き換えて main にコミット
Argo CD ─(poll 3 分 / Refresh)─▶ GitHub の kubernetes/overlays/dev を読む ─diff─▶ kind に apply
```

## 手順

| # | 操作場所 | 実行 | 確認場所 | 成功条件 |
|---|---|---|---|---|
| 1 | ターミナル | `./scripts/bootstrap-argocd.sh` | 出力 | admin パスワードが表示 |
| 2 | ターミナル | `kubectl -n argocd port-forward svc/argocd-server 8443:443` | ブラウザ https://localhost:8443 | ログイン画面（証明書警告は進む） |
| 3 | Argo CD UI | `admin` / 表示されたパスワードでログイン | Applications | `root`, `hello-go-dev`, `hello-go-staging`, `hello-go-prod` |
| 4 | Argo CD UI | `hello-go-dev` をクリック | 上部 | **Sync Status: Synced**、**App Health: Healthy** |
| 5 | Argo CD UI | ツリーの Pod をクリック > **LOGS** タブ | ログ | アクセスログ |
| 6 | ターミナル | `kubectl -n mcp-dev get pods` / `curl http://hello-dev.localtest.me/info` | 出力 | `version: v1.0.0` |
| 7 | Argo CD UI | `hello-go-prod` | 上部 | **OutOfSync**（automated なし）→ **SYNC** > **SYNCHRONIZE** → Synced |
| 8 | GitHub > Actions > Build | version `v1.1.0` / deploy_to_dev ✅ | main の履歴 → Argo CD | `deploy(dev): hello-go v1.0.0 -> v1.1.0` → dev が v1.1.0 |

## Argo CD 画面の見方

| 表示 | 意味 | 次の行動 |
|---|---|---|
| Synced / Healthy | Git どおりで正常 | — |
| OutOfSync / Healthy | Git が変わったが未反映（prod の正常な状態） | 差分（APP DIFF）を確認して SYNC |
| Synced / Progressing | 適用済み、Pod 入れ替え中 | 待つ / Pod を確認 |
| Synced / Degraded | 適用したが動いていない（ImagePullBackOff 等） | [I02](../labs/incident/I02-imagepullbackoff.md) / [I14](../labs/incident/I14-cd-failure.md) |
| Unknown / ComparisonError | Git からマニフェストを作れない | App Details > CONDITIONS |

## この Phase でやる Lab
Tuning Lab の大半（T01–T19）を **SCL-GitOps** で。C05–C07、R01–R04。

## Checkpoint
- [ ] kubectl を使わずに（PR だけで）replicas を変更できた
- [ ] prod は Merge だけでは反映されず、手動 Sync が必要なことを体験した
