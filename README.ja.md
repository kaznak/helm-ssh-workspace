# helm-ssh-workspace

Dropbear SSH サーバを利用したセキュアな ssh ワークスペースを提供する Helm チャートおよび Docker イメージ。

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
  - <span id="P3R8-SHELL">[P3R8-SHELL]</span> シングルユーザ SSH シェルアクセス可能な開発ワークスペースを提供
  - <span id="Q2N5-TOOLS">[Q2N5-TOOLS]</span> 開発ワークスペースでは様々な開発ツールを提供
    - <span id="M4J7-BREW">[M4J7-BREW]</span> 開発ワークスペースでは linuxbrew などユーザランドで動作するパッケージマネージャでインストール可能なツールはユーザランドでインストール（非特権環境での利用）
  - <span id="P7M2-FORWARD">[P7M2-FORWARD]</span> SSH 標準のポートフォワーディング機能を提供
    - <span id="N4C7-NETPOL">[N4C7-NETPOL]</span> ポートフォワーディングのアクセス制御は運用者がネットワークポリシーで設定
  - <span id="V5Q3-HOME">[V5Q3-HOME]</span> ホームディレクトリは emptyDir と PersistentVolume のいずれかを values.yaml の設定値で指定してマウント
    - <span id="T1H8-EMPTY">[T1H8-EMPTY]</span> ホームディレクトリはデフォルトで emptyDir をマウント
    - <span id="R7P4-STORAGE">[R7P4-STORAGE]</span> ホームディレクトリに PersistentVolume をマウントする場合、 StorageClass は values.yaml の設定値で指定可能
    - <span id="N3M9-PERSIST">[N3M9-PERSIST]</span> ホームディレクトリに PersistentVolume をマウントする場合、 Helm release 削除後も残り、再利用可能
    - <span id="C6B2-SUBDIR">[C6B2-SUBDIR]</span> ホームディレクトリに PersistentVolume をマウントする場合、サブディレクトリのマウントも可能
  - <span id="Y4F1-USER">[Y4F1-USER]</span> ユーザ設定を values.yaml の設定値で指定可能
    - <span id="G8W5-USERNAME">[G8W5-USERNAME]</span> ユーザ設定でユーザ名を values.yaml の設定値で指定可能、デフォルトは developer
    - <span id="Z2S7-UID">[Z2S7-UID]</span> ユーザ設定で UID を values.yaml の設定値で指定可能、デフォルトは 1000
    - <span id="A9T3-GID">[A9T3-GID]</span> ユーザ設定で GID を values.yaml の設定値で指定可能、デフォルトは 1000
- リソース管理
  - <span id="J1X6-LIMIT">[J1X6-LIMIT]</span> values.yaml の設定値で CPU、メモリ、ストレージの resource request/limit を指定可能
- ネットワーク・外部アクセス
  - <span id="B3Q8-PORT">[B3Q8-PORT]</span> SSH接続用のポートを values.yaml の設定値で指定可能。デフォルト2222（ユーザランド運用のため）。
  - <span id="W9F5-SERVICE">[W9F5-SERVICE]</span> Service リソースから利用される想定。
    - <span id="E4L7-CLUSTER">[E4L7-CLUSTER]</span> Service のアドレス種別は values.yaml の設定値で指定可能。デフォルトでは ClusterIP 。
  - <span id="S6R1-EXTERNAL">[S6R1-EXTERNAL]</span> 外部アクセス機能は外付けで運用する想定であり、Helm チャートでは提供しない。
    - <span id="U8N4-INGRESS">[U8N4-INGRESS]</span> 外部アクセス機能として Ingress リソースは外付けで運用
    - <span id="I2M6-NETPOL">[I2M6-NETPOL]</span> 外部アクセス機能として NetworkPolicy リソースは外付けで運用
- ログ・監視
  - <span id="K5G2-STRUCT">[K5G2-STRUCT]</span> 構造化されたログを出力
  - <span id="F7C8-METRICS">[F7C8-METRICS]</span> 基本的な監視メトリクスを提供（接続数、リソース使用量）
  - <span id="Q1P4-HEALTH">[Q1P4-HEALTH]</span> 基本的なヘルスチェック機能（liveness/readiness probe）を提供
- セキュリティ
  - <span id="X2K7-RESTRICT">[X2K7-RESTRICT]</span> "pod-security.kubernetes.io/enforce=restricted" ポリシーで運用できること
  - <span id="L6H3-KEYAUTH">[L6H3-KEYAUTH]</span> 認証は SSH 公開鍵認証のみ
  - <span id="V4J1-HOSTKEY">[V4J1-HOSTKEY]</span> SSH ホストキーは values.yaml の設定値でユーザが指定しない場合 helm release 作成時に生成
  - <span id="R8N9-REUSE">[R8N9-REUSE]</span> SSH サーバホストキーは helm release 削除後も残り、再利用可能
- 運用
  - <span id="Y3S2-DOWN">[Y3S2-DOWN]</span> アップデートやメンテナンス時のダウンタイムを許容し、高可用性は要求しない
  - <span id="C5Q4-TEMP">[C5Q4-TEMP]</span> 必要に応じて作成し、作業が終わったら削除する運用を想定
- バックアップ・復旧
  - <span id="Z4T5-NOPROV">[Z4T5-NOPROV]</span> バックアップ・復旧機能は本プロジェクトではPVレイヤの機能として提供しない
- k8s デプロイ構成
  - <span id="J8R2-DEPLOY">[J8R2-DEPLOY]</span> Deployment リソースで replicas 1 固定で運用（自動スケーリング無効）
  - <span id="N4V9-SVC">[N4V9-SVC]</span> Service を提供、デフォルトで ClusterIP アドレスを提供
  - <span id="H1C6-NOING">[H1C6-NOING]</span> Ingress リソースは提供しない
  - <span id="B7X5-NONP">[B7X5-NONP]</span> NetworkPolicy リソースは提供しない
- リリース形態
  - <span id="W5I2-HELM">[W5I2-HELM]</span> 本製品は Docker イメージと Helm チャートを提供
  - <span id="U9A4-TEST">[U9A4-TEST]</span> デプロイ結果が要件を全て満たしているかを確認するためのテストを提供
