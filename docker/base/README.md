# docker/base — 共通 Dockerfile 方針（80% 側）

全アプリの Dockerfile は以下を守る。新しい言語を載せるときもこの表を満たすこと。

| ルール | 理由 |
|---|---|
| マルチステージビルド | ビルドツールを本番イメージに入れない（サイズ・攻撃面） |
| 非 root ユーザーで実行 | コンテナ脱出時の被害縮小。Kubernetes の `runAsNonRoot` と対 |
| `PORT` 環境変数で待受 | Service / Probe を全アプリ共通にできる |
| `VERSION` build-arg | `/info` と `app_info` メトリクスでデプロイ中のバージョンを確認できる |
| タグは `vX.Y.Z` と `sha-xxxxxxx` | `latest` は使わない（何が動いているか追えなくなる） |
| `.dockerignore` | ビルドコンテキストを小さく、秘密情報を入れない |
