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

### アップグレード戦略

- データ永続化の保護
  - PVC, ConfigMap, Secret に `helm.sh/resource-policy: keep` アノテーションを設定
  - アップグレード時にもユーザデータとSSHホストキーを保持
- Rolling Update 戦略
  - Deployment の `strategy.type: RollingUpdate` を使用
  - `maxUnavailable: 0` でダウンタイムを最小化
  - readinessProbe によるトラフィック制御
- 設定の下位互換性
  - values.yaml の新規オプション追加時も既存設定を保護
  - デフォルト値の適切な設定による後方互換性確保
- Init Container での前処理
  - アップグレード時の設定ファイル形式変更対応
  - ホームディレクトリの権限・所有者修正
  - 既存SSH接続への影響最小化
- ロールバック対応
  - 問題発生時の迅速なロールバック機能
  - アップグレード前の状態確認とバックアップ

### コンテナイメージ戦略

- 標準イメージの提供
  - Ubuntu ベースの SSH サーバイメージを作成
  - values.yaml でイメージ・タグを変更可能
- ImagePullPolicy は Kubernetes ベストプラクティスに従う
  - latest タグの場合は Always
  - 固定タグの場合は IfNotPresent
- Private Registry 対応
  - imagePullSecrets の設定可能
  - values.yaml での認証情報指定

### リソース命名・ラベル戦略

- Kubernetes・Helm ベストプラクティスに従った命名
  - app.kubernetes.io/name, app.kubernetes.io/instance 等の標準ラベル
  - リソース名の一意性確保
  - セレクタの適切な設定

### 設定詳細

- タイムゾーン設定
  - デフォルトは UTC
  - values.yaml で変更可能
  - tzdata パッケージを事前インストール
- SSH公開鍵の複数対応
  - values.yaml の配列形式で複数キー設定可能
  - authorized_keys ファイルに自動統合

### 運用・テスト・検証

- Kubernetes・Helm ベストプラクティスに従った実装
  - gracefulShutdown 対応（terminationGracePeriod）
  - 適切なヘルスチェック設定
  - Helm test による動作確認

### セキュリティ強化

- seccomp プロファイル設定
  - runtime/default プロファイルを使用
- AppArmor 対応（利用可能な場合）
- 監査ログ設定
  - SSH 接続の詳細ログ記録
- ネットワークセキュリティ
  - 不要なポートの無効化
  - localhost 以外への接続制限

### ドキュメント・使用例

- values.yaml の典型的な設定例
- SSH 接続方法の詳細ガイド
- トラブルシューティングガイド
- 制限事項・注意点の明記
- セキュリティ設定の説明

### Chart.yaml 要件

- Chart メタデータ（Helm ベストプラクティス準拠）
  - name: ssh-workspace
  - version: セマンティックバージョニング
  - description: SSH accessible workspace environment
  - type: application
  - maintainers: 適切な連絡先情報
  - keywords: [ssh, workspace, development]
  - sources: Git リポジトリ URL

### Values.yaml 構造定義

- 階層構造による設定の整理（Helm ベストプラクティス準拠）
  - image: repository, tag, pullPolicy
  - user: name, uid, gid, shell, additionalGroups
  - ssh: publicKeys, port, config
  - persistence: enabled, size, storageClass, accessModes
  - resources: requests, limits
  - service: type, port
  - security: securityContext, podSecurityContext
  - timezone: デフォルト UTC
- values.schema.json による型検証

### Helm Hooks 設定

- pre-install: SSH公開鍵の妥当性チェック
- post-install: 初期化完了とSSH接続可能性の確認
- pre-upgrade: 設定の互換性確認
- post-upgrade: アップグレード後の動作確認
- pre-delete: 永続化データの警告表示
- test: SSH接続テストの実行

### NOTES.txt 要件

- インストール後の案内（Helm ベストプラクティス準拠）
  - SSH接続コマンドの表示
  - ポート転送方法の説明
  - 永続化設定の確認方法
  - エフェメラルストレージ使用時の警告
- 設定確認手順とトラブルシューティング情報

### 追加機能

- 追加パッケージインストール機能
  - values.yaml で追加パッケージリストを指定可能
  - apt install での自動インストール
- Ingress 対応（オプション、デフォルト無効）
  - values.yaml での Ingress 設定可能
  - TLS 終端対応

### 制限事項

- 単一ユーザー専用（マルチユーザー非対応）
- root 実行が必要（セキュリティコンテキストで制限）
- 永続化はホームディレクトリのみ
- X11転送はローカルホスト経由のみ
- SSH以外のポートは外部公開不可