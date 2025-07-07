# 設計書

## 概要

[README.ja.md](../README.ja.md)の[要求・要件](../README.ja.md#要求要件)を満たすDropbear SSH ワークスペースHelmチャートおよびDockerイメージの実装設計。

ssh workspace のコンポーネントは以下から構成される。

- Dockerイメージ
- Helmチャート(kubernetes リソース、 main/test)
- github actions workflow マニフェスト

ssh workspace のライフサイクルは以下の通り。

- CI: Github Actions のフェーズ
  - ビルド関連の処理のほか、 helm の全てのライフサイクルのテストも行う。
- Install: helm install フェーズ
- Test: helm test フェーズ
- Upgrade: helm upgrade フェーズ
- Rollback: helm rollback フェーズ
- Uninstall: helm uninstall フェーズ
