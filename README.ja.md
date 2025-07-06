# helm-ssh-workspace

Dropbear SSH サーバを利用したセキュアな ssh ワークスペースを提供する Helm チャート。

- Dropbear SSH
  - https://github.com/mkj/dropbear
  - https://matt.ucc.asn.au/dropbear/dropbear.html

## 背景

CLI 型の AI エージェントと共同するためにはシェルアクセスが必要である。
SSH サーバとしては OpenSSH が広く使われているが、次の理由から kubernetes 上での運用には不向きである。

- sshd 自体が特権プロセスとしての運用を前提として開発されており、ユーザランドでの運用が難しい。
- 特権システムコールを利用しての権限管理機能が実装されており、活用するためには特権が必要

よりシンプルな ssh サーバである Dropbear SSH を利用することで、Kubernetes 上での運用が容易になると期待される。

## 要求・要件

- 機能
  - シングルユーザ SSH シェルアクセス可能な開発ワークスペースを提供
  - 様々な開発ツールを提供
    - linuxbrew でインストール可能なものはユーザランドで linuxbrew を利用してインストール
  - ホームディレクトリを PersistentVolume で永続化
  - ホームディレクトリは helm release を削除後にも残り、再利用可能
  - ホームディレクトリはサブディレクトリのマウントも可能
  - ホームディレクトリは他の Pod からもマウント可能
  - SSH ポートフォワーディングが出来る事
    - ただしローカルホストのみ
- セキュリティ
  - "pod-security.kubernetes.io/enforce=restricted" ポリシーで運用できること
  - 認証は SSH 鍵認証のみ
  - ホストキーは helm release 作成時に生成
  - ホストキーは helm release 削除後も残り、再利用可能
- 運用
  - ダウンタイムを許容
  - 必要に応じて作成し、作業が終わったら削除する運用を想定
- k8s デプロイ構成
  - deployment, replicas 1
  - service を提供、デフォルトで ClusterIP アドレスを提供
  - ingress はなし
  - ネットワークポリシーはなし
- リリース形態
  - Helm チャートとして提供
  - デプロイ結果が要件を全て満たしているかを確認するためのテストを提供
