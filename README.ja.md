# helm-ssh-workspace

Dropbear SSH サーバを利用したセキュアな ssh ワークスペースを提供する Helm チャート。

- Dropbear SSH
  - https://github.com/mkj/dropbear
  - https://matt.ucc.asn.au/dropbear/dropbear.html

## 背景

CLI 型の AI エージェントと共同開発を行うためには、シェルアクセスが必要である。
SSH サーバとして OpenSSH が広く使われているが、Kubernetes 上での運用には以下の課題がある。

- sshd は特権プロセスとしての運用を前提として開発されており、ユーザランドでの運用が困難
- 特権システムコールを利用した権限管理機能が実装されており、これを活用するには特権が必要

よりシンプルな SSH サーバである Dropbear SSH を利用することで、Kubernetes 上での運用が容易になると期待される。 Dropbear SSH はユーザランドでの運用が可能であり、特権システムコールを利用しないため、Kubernetes 上での運用に適していると思われる。

## 要求・要件

[背景](#背景)を踏まえ、以下の要求・要件を満たすことを目指す。

- 機能
  - シングルユーザ SSH シェルアクセス可能な開発ワークスペースを提供
  - 様々な開発ツールを提供
    - linuxbrew でインストール可能なものはユーザランドで linuxbrew を利用してインストール（非特権環境での利用）
  - ホームディレクトリを PersistentVolume で永続化
  - ホームディレクトリは helm release を削除後にも残り、再利用可能
  - ホームディレクトリはサブディレクトリのマウントも可能
  - ホームディレクトリは他の Pod からもマウント可能
  - SSH ポートフォワーディングが可能であること
    - ただしローカルホストのみ
- リソース管理
  - values.yaml で CPU、メモリ、ストレージのリソース制限を設定可能
- ネットワーク・外部アクセス
  - SSH接続用のポートを values.yaml 設定可能。デフォルト2222（ユーザランド運用のため）。
  - Service リソースから利用される想定。
    - アドレス種別は values.yaml で設定可能。デフォルトでは ClusterIP 。
  - 以下は外付けで運用する想定であり、Helm チャートでは提供しない。
    - Ingress
    - NetworkPolicy
- ログ・監視
  - 構造化されたログ出力
  - 基本的な監視メトリクス提供（接続数、リソース使用量）
  - ヘルスチェック機能（liveness/readiness probe）
- セキュリティ
  - "pod-security.kubernetes.io/enforce=restricted" ポリシーで運用できること
  - 認証は SSH 鍵認証のみ
  - ホストキーは helm release 作成時に生成
  - ホストキーは helm release 削除後も残り、再利用可能
- 運用
  - ダウンタイムを許容
  - 必要に応じて作成し、作業が終わったら削除する運用を想定
  - 自動スケーリングは無効（replicas固定）
- バックアップ・復旧
  - 本プロジェクトではPV のレイヤでの機能であるとして提供しない
- k8s デプロイ構成
  - deployment, replicas 1
  - service を提供、デフォルトで ClusterIP アドレスを提供
  - ingress はなし
  - ネットワークポリシーはなし
- リリース形態
  - Helm チャートとして提供
  - デプロイ結果が要件を全て満たしているかを確認するためのテストを提供
