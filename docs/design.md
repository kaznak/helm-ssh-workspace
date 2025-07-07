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

#### ユーザ設定と関連する処理

ssh workspace は、デプロイ時にユーザ情報を受け付けてそれに合わせた設定を行う - [[Y4F1-USER]](../README.ja.md#Y4F1-USER), [[G8W5-USERNAME]](../README.ja.md#G8W5-USERNAME), [[Z2S7-UID]](../README.ja.md#Z2S7-UID), [[A9T3-GID]](../README.ja.md#A9T3-GID)。
そのため CI フェーズではユーザの設定を行うことは出来ない。

したがって Install フェーズで以下の処理を行う必要がある：

- ユーザの追加とホームディレクトリのセットアップ - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME)
- linuxbrew の非特権環境での導入とパッケージ管理 - [[M4J7-BREW]](../README.ja.md#M4J7-BREW)

また Install フェーズでの関連する処理として以下がある：

- ホームディレクトリ再利用時の既存設定確認 - [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST)
  - ホームディレクトリのデータが既に存在する場合、ユーザ設定を上書きしないようにする。
- SSH ホストキーのユーザホームディレクトリへの配置 - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT), [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)
  - 要件から SSH サーバはユーザランドで動作するため([[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT))、そのホストキーはユーザのホームディレクトリに保存することが第一の選択肢となる。

#### 各種スクリプトについて

ssh workspace はライフサイクルの各段階でのテストを充実させ、後段でのトラブルの発生を極力抑える - [[U9A4-TEST]](../README.ja.md#U9A4-TEST)。
また、節、[Install フェーズでのユーザ設定](#install-フェーズでのユーザ設定)、で述べた理由のため、複雑な処理を実行する必要がある - [[Y4F1-USER]](../README.ja.md#Y4F1-USER), [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME), [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST)。

確実にこれらの処理を実行できるようにするため、成果物の Docker イメージにこれらの処理のためのスクリプトを含めて、 Docker により全ての処理を行えるようにする。

## コンポーネントの詳細

## ライフサイクルの詳細
