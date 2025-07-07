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

### 注意事項

#### Install フェーズでのユーザ設定

ssh workspace は、デプロイ時にユーザ情報を受け付けてそれに合わせた設定を行う - [[Y4F1-USER]](../README.ja.md#Y4F1-USER), [[G8W5-USERNAME]](../README.ja.md#G8W5-USERNAME), [[Z2S7-UID]](../README.ja.md#Z2S7-UID), [[A9T3-GID]](../README.ja.md#A9T3-GID)。
そのため CI フェーズではユーザの設定を行うことは出来ない。
Install フェーズでユーザの追加、ホームディレクトリのセットアップなどを行う必要がある - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME)。

この時ホームディレクトリを再利用するケースがあり、ホームディレクトリの内容を確認した上でユーザ設定を行う必要がある - [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST)。
また、要件から SSH サーバはユーザランドで動作するため、そのホストキーはユーザのホームディレクトリに保存することが第一の選択肢となる - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT), [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)。

## コンポーネントの詳細

## ライフサイクルの詳細
