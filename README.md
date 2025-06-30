# SSH Workspace Helm Chart

SSH でアクセスできる作業用のシェル環境を構築する Helm Chart

## 仕様

### リソースに関して

- 設定情報に関しては ConfigMap, Secret を積極的に活用する
- PVC, ConfigMap, Secret は Helm Release を削除しても残るようにする
- 高セキュリティな環境を提供する
- ネットワークポリシーは外付けするため不要
- ssh サーバのベースイメージはまず ubuntu で作成する
- 合わせて導入するパッケージに関しては、さし当たっては ssh 環境を実現するために最低限必要なものとする。
- デフォルトシェルはディストリビューション（Ubuntu）のデフォルトを使用
- PVC の StorageClass, AccessMode は values.yaml で設定可能にする
- リソース制限に関しては values.yaml で設定できるようにし、デフォルトでは制限なしとする。
- セキュリティ強化のため、ルートファイルシステムを読み取り専用にする
  - sshd が書き込みを必要とするディレクトリは emptyDir でマウント
    - /var/run: PIDファイル保存用
    - /tmp: 一時ファイル・X11ソケット用
    - /var/empty: sshd特権分離プロセス用
  - ログは標準出力に出力して Kubernetes のログ機能を活用
    - /var/log: 通常ログファイル保存用だが、標準出力使用のため emptyDir マウント不要

### sshd に関して

- 高セキュリティな設定を行う
- 設定情報やホストキーは secret に含めるようにする
- 認証方式は公開鍵のみ
- 暗号化方式は現在のデフォルトのものを使用し、 values.yaml で設定を変更できるようにする
- 設定ファイルはセキュリティを考慮したものをデフォルトとしてコンテナイメージに含める
- root 実行モードで、 k8s リソース側のセキュリティ設定を強化して高いセキュリティを実現する
- X11 転送はローカルホストからの接続のみ受け付けるよう制限する
  - ユーザは sshd の転送オプションを使用して利用する想定
- ログは標準出力に出力する（sshd -D -e オプションを使用）
- セキュリティ強化設定（推奨値）
  - PasswordAuthentication no
  - PermitEmptyPasswords no
  - MaxAuthTries 3
  - LoginGraceTime 30
  - ClientAliveInterval 300
  - ClientAliveCountMax 2
  - AllowTcpForwarding yes（ポート転送を許可）
  - GatewayPorts no
  - PermitRootLogin no
  - Protocol 2

### ログインユーザに関して

- 1 デプロイあたり 1 ユーザ専用
- デプロイ時に環境変数でログインを許可するユーザをuid/gidともに指定できる
- ユーザの設定に基づき sshd の AllowUsers の設定が反映される
- ユーザの設定に基づき、ユーザが存在しなければ作成される
- ユーザのシステム設定は values.yaml で詳細設定可能
  - ログインシェル（デフォルトは /bin/bash）
  - 追加グループ
- ユーザのホームディレクトリ設定ファイルはディストリビューションデフォルトを使用
- ユーザのホームディレクトリを永続化するオプションを提供する
  - 同ボリュームのパラメータに関しては values.yaml で設定できるようにする
  - サイズはデフォルトで 10GiB とする
- ユーザのSSH公開鍵はホームディレクトリに含めるほか、 configmap や secret でも提供できるようにする。
- sudo で root になれるかどうかはオプションで、デフォルトでは off

### サービス・アクセス設定

- Service Type は values.yaml で設定可能とし、デフォルトは ClusterIP
- SSH接続ポートは values.yaml で設定可能とし、デフォルトは 22
- 外部からのアクセス方法（NodePort, LoadBalancer, Ingress等）は環境に応じて選択
- 外部公開するポートは SSH のみに制限
- localhost からのアクセスは基本的に許可

### ヘルスチェック・監視

- Liveness Probe: SSH プロセスの生存確認（/usr/sbin/sshd -t でコンフィグ検証）
- Readiness Probe: SSH ポートへの接続確認
- ログレベルは values.yaml で設定可能とし、デフォルトは INFO

### 初期化・運用

- 初回起動時にユーザ作成、SSH公開鍵配置を自動実行
- ConfigMap/Secret 更新時の設定反映は Pod 再起動で対応
- ホストキーは Secret で管理し、初回起動時に存在しなければ自動生成
- エラーハンドリングは Kubernetes のベストプラクティスに従う
  - 初期化失敗時は Init Container で適切なエラーを出力
  - SSH公開鍵が無効な場合は起動を停止
  - PVCマウント失敗時は Pod を Pending 状態にする

### セキュリティ詳細設定

- Pod Security Context（推奨値）
  - runAsNonRoot: false（root実行が必要）
  - readOnlyRootFilesystem: true
  - allowPrivilegeEscalation: false
- Security Context（推奨値）
  - capabilities:
    - drop: ["ALL"]
    - add: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE"]

### 監視・メトリクス

- Prometheus メトリクス（オプション）
  - SSH接続数
  - プロセス数
  - メモリ・CPU使用量
  - ファイルシステム使用量