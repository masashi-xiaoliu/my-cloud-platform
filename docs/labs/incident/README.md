# Incident Response Lab

意図的に障害を起こし、**症状 → 確認コマンド → 見るべきログ → 仮説 → 原因 → 修正 → 再デプロイ → 復旧確認** の流れで復旧する訓練。

## 2 つのモード

| モード | やり方 | ねらい |
|---|---|---|
| **シナリオ指定** | 各ページの「0. 障害の起こし方」を実行 | 障害の種類ごとの調査パターンを覚える |
| **ブラインド訓練** | `make chaos`（= `python3 scripts/chaos.py inject`）→ **差分を見ずに** commit → PR → Merge → 調査 | 本番と同じく「何が起きたかわからない」状態から始める |

ブラインド訓練中の操作:

```bash
make chaos      # ランダムな障害を dev overlay に仕込む（中身は表示されない）
git add -A && git commit -m "chore: routine config update" && git push   # → PR → Merge
make status     # 状態を俯瞰
make hint       # 行き詰まったらヒントを 1 つずつ
make reveal     # 調査が終わったら答え合わせ
make reset      # 正常状態に戻す → commit → PR → Merge
```

## シナリオ一覧

| ID | 障害 | 症状 |
|---|---|---|
| [I01](I01-crashloopbackoff.md) | Pod CrashLoopBackOff（設定エラー） | デプロイ後、サイトにアクセスすると時々エラー、または新バージョンにならない。Argo CD が `Progressing` から進まない。 |
| [I02](I02-imagepullbackoff.md) | ImagePullBackOff（存在しないイメージ） | デプロイしたのにバージョンが変わらない。Argo CD が `Progressing` → しばらくして `Degraded`。 |
| [I03](I03-service-targetport.md) | Service 接続失敗（targetPort 不一致） | Pod はすべて `Running` / `1/1`。なのにブラウザでは 502 Bad Gateway / Bad Gateway。 |
| [I04](I04-service-selector.md) | Service 接続失敗（selector 不一致） | Pod は正常。外部からは 503 / `no available server`。 |
| [I05](I05-readiness-failure.md) | Ready にならない（readinessProbe） | 新しい Pod が `Running` なのに READY `0/1`。デプロイが終わらない。 |
| [I06](I06-secret-error.md) | Secret エラー（必須の API_KEY がない） | 新しい Pod が起動直後に落ちる。 |
| [I07](I07-application-error.md) | アプリケーションエラー（5xx 率の上昇） | 一部のユーザーからエラーの報告。Pod はすべて正常。Grafana の Error rate が上昇。アラート `HelloGoHighErrorRate` が発火（Phase 8〜）。 |
| [I08](I08-resource-shortage.md) | リソース不足（Pending） | デプロイが終わらない。新 Pod が `Pending` のまま。 |
| [I09](I09-oomkilled.md) | OOMKilled（メモリ上限超過） | Pod の RESTARTS が増え続ける。ログにはエラーが出ていない。 |
| [I10](I10-ingress-class.md) | Ingress 障害（404） | http://hello-dev.localtest.me が 404 page not found。Pod も Service も正常。 |
| [I11](I11-liveness-restart.md) | 再起動ループ（livenessProbe） | Pod が 30 秒ほど動いては再起動する。その間アクセスは成功する。 |
| [I12](I12-invalid-config-value.md) | 不正な設定値（LOG_LEVEL） | 『障害調査のためにログを詳しくしたい』という変更をデプロイしたら、Pod が起動しなくなった。 |
| [I13](I13-ci-failure.md) | CI 失敗 | PR に ❌ が付き、Merge ボタンが押せない（ブランチ保護を設定済みの場合）。 |
| [I14](I14-cd-failure.md) | CD 失敗（Argo CD OutOfSync / Sync Failed / Degraded） | Merge したのにクラスタに反映されない。Argo CD のアプリに黄色・赤のアイコン。 |
| [I15](I15-dns-external-api.md) | 外部 API / DNS 障害 | `/upstream` を使う機能だけがエラー（502）。応答も遅い。 |
| [I16](I16-node-failure.md) | ノード障害・Pod 削除への耐性 | （① ではほぼ何も起きないはず。② では一時的にエラーが出る可能性） |

## 共通の調査手順（迷ったらここに戻る）

```text
1. 影響範囲     … 全部ダメ? 一部? いつから?（Grafana / curl）
2. 直近の変更   … Argo CD > History、git log。障害の大半は「変更」が引き金
3. 外から内へ   … DNS → Ingress → Service → Endpoint → Pod → コンテナ → アプリ
4. 状態         … kubectl get pods / describe（Events）/ logs（--previous）
5. 仮説 → 検証  … 1 回に 1 つだけ変える
6. 復旧優先     … 原因究明より先に Rollback（R01）で止血してよい
7. 記録         … docs/experiments/ に残し、再発防止（CI チェック・アラート）を考える
```

詳細なコマンド集は [docs/troubleshooting.md](../../troubleshooting.md)。
