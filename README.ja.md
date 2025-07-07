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

- <span id="f01">[F01]</span> 機能
  - <span id="f01a">[F01a]</span> シングルユーザ SSH シェルアクセス可能な開発ワークスペースを提供
  - <span id="f01b">[F01b]</span> 様々な開発ツールを提供
    - <span id="f01b1">[F01b1]</span> linuxbrew でインストール可能なものはユーザランドで linuxbrew を利用してインストール（非特権環境での利用）
  - <span id="f01c">[F01c]</span> SSH ポートフォワーディングが可能であること
    - <span id="f01c1">[F01c1]</span> ただしローカルホストのみ
  - <span id="f01d">[F01d]</span> ホームディレクトリは emptyDir と PersistentVolume が values.yaml で選択可能
    - <span id="f01d1">[F01d1]</span> デフォルトでは emptyDir
    - <span id="f01d2">[F01d2]</span> PersistentVolume の場合、 StorageClass は values.yaml で設定可能
    - <span id="f01d3">[F01d3]</span> PersistentVolume の場合、ホームディレクトリは Helm release 削除後も残り、再利用可能
    - <span id="f01d4">[F01d4]</span> PersistentVolume の場合、サブディレクトリのマウントも可能
- <span id="r01">[R01]</span> リソース管理
  - <span id="r01a">[R01a]</span> values.yaml で CPU、メモリ、ストレージのリソース制限を設定可能
- <span id="n01">[N01]</span> ネットワーク・外部アクセス
  - <span id="n01a">[N01a]</span> SSH接続用のポートを values.yaml で設定可能。デフォルト2222（ユーザランド運用のため）。
  - <span id="n01b">[N01b]</span> Service リソースから利用される想定。
    - <span id="n01b1">[N01b1]</span> アドレス種別は values.yaml で設定可能。デフォルトでは ClusterIP 。
  - <span id="n01c">[N01c]</span> 以下は外付けで運用する想定であり、Helm チャートでは提供しない。
    - <span id="n01c1">[N01c1]</span> Ingress
    - <span id="n01c2">[N01c2]</span> NetworkPolicy
- <span id="l01">[L01]</span> ログ・監視
  - <span id="l01a">[L01a]</span> 構造化されたログ出力
  - <span id="l01b">[L01b]</span> 基本的な監視メトリクス提供（接続数、リソース使用量）
  - <span id="l01c">[L01c]</span> ヘルスチェック機能（liveness/readiness probe）
- <span id="s01">[S01]</span> セキュリティ
  - <span id="s01a">[S01a]</span> "pod-security.kubernetes.io/enforce=restricted" ポリシーで運用できること
  - <span id="s01b">[S01b]</span> 認証は SSH 鍵認証のみ
  - <span id="s01c">[S01c]</span> ホストキーは helm release 作成時に生成
  - <span id="s01d">[S01d]</span> ホストキーは helm release 削除後も残り、再利用可能
- <span id="o01">[O01]</span> 運用
  - <span id="o01a">[O01a]</span> ダウンタイムを許容
  - <span id="o01b">[O01b]</span> 必要に応じて作成し、作業が終わったら削除する運用を想定
  - <span id="o01c">[O01c]</span> 自動スケーリングは無効（replicas固定）
- <span id="b01">[B01]</span> バックアップ・復旧
  - <span id="b01a">[B01a]</span> 本プロジェクトではPVレイヤの機能として提供しない
- <span id="k01">[K01]</span> k8s デプロイ構成
  - <span id="k01a">[K01a]</span> deployment, replicas 1
  - <span id="k01b">[K01b]</span> service を提供、デフォルトで ClusterIP アドレスを提供
  - <span id="k01c">[K01c]</span> ingress はなし
  - <span id="k01d">[K01d]</span> ネットワークポリシーはなし
- <span id="rl01">[RL01]</span> リリース形態
  - <span id="rl01a">[RL01a]</span> Helm チャートとして提供
  - <span id="rl01b">[RL01b]</span> デプロイ結果が要件を全て満たしているかを確認するためのテストを提供
