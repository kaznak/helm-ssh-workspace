# SSH Workspace Helm Chart

SSH でアクセスできる作業用のシェル環境を構築する Helm Chart

## 1. 概要・基本機能

### コンセプト
- 1デプロイあたり1ユーザー専用のSSH作業環境
- 高セキュリティな設定でKubernetes上にSSHサーバーを提供
- ホームディレクトリの永続化オプション

### 基本構成
- **ベースイメージ**: Ubuntu（最低限のSSH環境パッケージ）
- **デフォルトシェル**: ディストリビューション（Ubuntu）デフォルト
- **リソース管理**: ConfigMap, Secret, PVC を積極活用
- **永続化**: PVC, ConfigMap, Secret は Helm Release 削除後も保持

## 2. SSH・ユーザ設定

### SSH設定
- **認証方式**: 公開鍵のみ
- **ログ出力**: 標準出力（sshd -D -e オプション）
- **設定管理**: ホストキーはSecretで管理、初回起動時に自動生成
- **セキュリティ設定**:
  - PasswordAuthentication no
  - PermitEmptyPasswords no
  - MaxAuthTries 3
  - LoginGraceTime 30
  - ClientAliveInterval 300
  - ClientAliveCountMax 2
  - AllowTcpForwarding yes
  - GatewayPorts no
  - PermitRootLogin no
  - Protocol 2

### ユーザ設定
- **ユーザ作成**: 指定されたUID/GIDで自動作成（存在しない場合）
- **SSH公開鍵**: ホームディレクトリ + ConfigMap/Secret提供
- **ホームディレクトリ**: 永続化オプション（デフォルト10GiB）
- **sudo権限**: オプション（デフォルト無効）
- **設定ファイル**: ディストリビューションデフォルトを使用

### X11転送
- ローカルホストからの接続のみ許可
- sshdの転送オプション使用を想定

## 3. セキュリティ設定

### セキュリティレベル選択（オプション）
- **Basic**: 開発・テスト用
  - readOnlyRootFilesystem: false
  - 最小限の制限
- **Standard**: 推奨設定（デフォルト）
  - readOnlyRootFilesystem: true
  - seccomp: runtime/default
- **High**: 本番環境用
  - Standard + AppArmor有効
  - 厳格なSSH設定（短いタイムアウト等）

### Pod Security Context
- **runAsNonRoot**: false（root実行が必要）
- **readOnlyRootFilesystem**: true（Basicレベル時はfalse）
- **allowPrivilegeEscalation**: false（sudo有効時は自動でtrue）

### Capabilities
- **drop**: ["ALL"]
- **add**: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE"]
- **sudo有効時**: 必要なcapabilitiesを自動追加

### ファイルシステム
- **読み取り専用ルート**: セキュリティ強化
- **emptyDir マウント**:
  - /var/run: PIDファイル（10Mi）
  - /tmp: 一時ファイル・X11ソケット（100Mi）
  - /var/empty: sshd特権分離プロセス用
- **追加セキュリティ**: seccomp, AppArmor対応

## 4. サービス・アクセス設定

### Service設定
- **Type**: ClusterIP（デフォルト）
- **Port**: 22（デフォルト）
- **外部アクセス**: NodePort/LoadBalancer/Ingress選択可能
- **制限**: 外部公開はSSHのみ、localhostアクセスは許可

### Ingress対応（オプション）
- **デフォルト**: 無効
- **設定**: annotations, ingressClassName, TLS終端対応
- **機能**: SSH over HTTP/HTTPSトンネリング対応

### ネットワークセキュリティ
- 不要なポートの無効化
- ネットワークレベル制限は外部NetworkPolicyで実施

## 5. 監視・運用

### ヘルスチェック
- **Liveness Probe**: SSHプロセス生存確認（/usr/sbin/sshd -t）
- **Readiness Probe**: SSHポート接続確認
- **gracefulShutdown**: terminationGracePeriod対応

### 監視・メトリクス（オプション）
- **ssh_exporter**: サイドカーコンテナとして使用
- **収集メトリクス**: SSH接続数、レスポンス時間、認証失敗数
- **Prometheus連携**: ServiceMonitor設定
- **標準メトリクス**: CPU・メモリ使用量、PVC使用量

### エラーハンドリング
- **初期化失敗**: Init Containerで適切なエラー出力
- **SSH公開鍵無効**: 起動停止
- **UID/GID競合**: エラーで起動停止
- **PVCマウント失敗**: Pod Pending状態

### アップグレード戦略
- **Deployment戦略**: Recreate（ダウンタイム許容）
- **データ保護**: PVC/ConfigMap/Secretに`helm.sh/resource-policy: keep`
- **自動復旧**: restartPolicy Always
- **下位互換性**: values.yaml新規オプション追加時の既存設定保護

## 6. Helm Chart仕様

### Chart.yaml
- **name**: ssh-workspace
- **type**: application
- **version**: セマンティックバージョニング
- **description**: SSH accessible workspace environment
- **keywords**: [ssh, workspace, development]
- **maintainers**: 適切な連絡先情報

### Values.yaml構造
- **image**: repository, tag, pullPolicy
- **user**: name, uid, gid, shell, additionalGroups, sudo
- **ssh**: publicKeys, port, config
- **persistence**: enabled, size, storageClass, accessModes
- **resources**: requests, limits
- **service**: type, port
- **security**: securityContext, podSecurityContext, level
- **timezone**: デフォルトUTC
- **monitoring**: ssh_exporter有効/無効
- **ingress**: 設定オプション
- **デプロイ時決定パラメータ以外は全てオプション**

### Values.schema.json
- 型検証による設定値の妥当性確認

### Helm Hooks
- **pre-install**: SSH公開鍵妥当性チェック（必須、不正時はデプロイ失敗）
- **post-install**: 初期化完了とSSH接続可能性確認
- **pre-upgrade**: 設定互換性確認
- **post-upgrade**: アップグレード後動作確認
- **pre-delete**: 永続化データ警告表示
- **test**: SSH接続テスト実行

### NOTES.txt
- **インストール後案内**: SSH接続コマンド、ポート転送方法
- **設定確認手順**: 永続化設定確認
- **警告**: エフェメラルストレージ使用時のデータ喪失警告
- **トラブルシューティング**: よくある問題と解決方法

### 運用・テスト
- **Helm test**: 動作確認
- **統合テスト**: SSH接続テスト自動化
- **ドキュメント**: values.yaml設定例、SSH接続ガイド

## 7. コンテナイメージ・技術詳細

### イメージ戦略
- **標準イメージ**: UbuntuベースSSHサーバー
- **カスタマイズ**: values.yamlでイメージ・タグ変更可能
- **ImagePullPolicy**: latestタグ=Always、固定タグ=IfNotPresent
- **Private Registry**: imagePullSecrets対応

### リソース命名・ラベル
- **標準ラベル**: app.kubernetes.io/name, app.kubernetes.io/instance等
- **命名規則**: Kubernetes・Helmベストプラクティス準拠
- **一意性確保**: リソース名の重複回避

### 設定詳細
- **タイムゾーン**: UTC（デフォルト）、tzdataパッケージ事前インストール
- **SSH公開鍵**: 配列形式で複数キー対応、authorized_keys自動統合
- **ホストキー**: インスタンス固有生成で一意性確保

## 8. 制限事項

- **単一ユーザー専用**: マルチユーザー非対応
- **root実行必須**: セキュリティコンテキストで制限
- **永続化範囲**: ホームディレクトリのみ
- **X11転送**: ローカルホスト経由のみ
- **外部公開ポート**: SSH以外は不可
- **追加パッケージ**: カスタムイメージでの対応が必要