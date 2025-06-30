# SSH Workspace

SSH でアクセスできる作業用のシェル環境を構築するプロジェクト。
DockerイメージとKubernetes用Helm Chartを提供します。

## 📁 プロジェクト構造

```
ssh-workspace/
├── README.md              # このファイル（仕様書）
├── USAGE.md              # 使用方法ガイド
├── LICENSE               # MITライセンス
├── .github/              # GitHub設定
│   ├── workflows/        # CI/CDワークフロー
│   ├── ISSUE_TEMPLATE/   # Issueテンプレート
│   └── CODEOWNERS        # コード所有者
├── docker/               # Dockerイメージ
│   ├── Dockerfile        # イメージ定義
│   ├── config/           # SSH設定
│   ├── scripts/          # 初期化スクリプト
│   └── README.md         # Docker用ドキュメント
├── helm/                 # Helm Chart
│   ├── ssh-workspace/    # Chartパッケージ
│   ├── example-values.yaml # 設定例
│   └── README.md         # Helm用ドキュメント
└── docs/                 # 追加ドキュメント
    └── helm-oci-format.md # OCI形式ガイド
```

## 🚀 クイックスタート

### Dockerで実行

```bash
cd docker
docker build -t ssh-workspace .

echo "ssh-ed25519 AAAAC3... user@example.com" > authorized_keys
docker run -d -p 2222:22 \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace

ssh developer@localhost -p 2222
```

### Kubernetesで実行

```bash
cd helm
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"

kubectl port-forward svc/workspace-ssh-workspace 2222:22
ssh developer@localhost -p 2222
```

## 🔄 CI/CD & コンテナレジストリ

### GitHub Container Registry (GHCR)

ビルド済みイメージがGitHub Container Registryで利用可能です：

```bash
# 最新イメージをプル
docker pull ghcr.io/YOUR_USERNAME/ssh-workspace:latest

# Helm Chartで使用
helm install workspace ./helm/ssh-workspace \
  --set image.repository=ghcr.io/YOUR_USERNAME/ssh-workspace \
  --set image.tag=latest \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

### 利用可能なタグ

- `latest` - mainブランチからの最新安定版リリース
- `develop` - 最新開発版
- `v1.0.0` - 特定バージョンタグ
- `main` - mainブランチビルド

### CI/CDワークフロー

| ワークフロー | トリガー | 目的 |
|-------------|----------|------|
| **CI/CDパイプライン** | Push/PR | リント、テスト、ビルド、プッシュ |
| **Dockerビルド&プッシュ** | Docker変更 | マルチアーキテクチャイメージのビルド |
| **セキュリティスキャン** | 日次/Push | Trivyによる脆弱性スキャン |
| **Helmリリース** | Chart変更 | Chartのパッケージと公開 |
| **Pages Helmリポジトリ** | Chart変更 | GitHub Pages Helmリポジトリ |

### Helm Chartインストール

#### 方法1: OCIレジストリ（推奨）

```bash
# GHCRから直接インストール
helm install workspace \
  oci://ghcr.io/YOUR_USERNAME/charts/ssh-workspace \
  --version 1.0.0 \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

#### 方法2: 従来のHelmリポジトリ

```bash
# リポジトリを追加
helm repo add ssh-workspace https://YOUR_USERNAME.github.io/REPOSITORY_NAME/
helm repo update

# Chartをインストール
helm install workspace ssh-workspace/ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

#### 方法3: ローカルインストール

```bash
# リポジトリをクローンしてローカルでインストール
git clone https://github.com/YOUR_USERNAME/REPOSITORY_NAME.git
cd REPOSITORY_NAME
helm install workspace ./helm/ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

## 1. 概要・基本機能

### コンセプト
- 1デプロイあたり1ユーザー専用のSSH作業環境
- 高セキュリティなKubernetes上のSSHサーバー
- ホームディレクトリの永続化オプション

### 基本構成
- **ベースイメージ**: Ubuntu（最低限のSSH環境パッケージ）
- **リソース管理**: ConfigMap, Secret, PVC を積極活用
- **永続化**: PVC, ConfigMap, Secret は Helm Release 削除後も保持

## 2. SSH・ユーザ設定

### SSH機能
| 項目 | 設定値 | 備考 |
|------|--------|------|
| 認証方式 | 公開鍵のみ | PasswordAuthentication no |
| ログ出力 | 標準出力 | sshd -D -e オプション |
| ホストキー管理 | Secret | 初回起動時自動生成 |
| 接続試行 | 3回まで | MaxAuthTries 3 |
| 接続タイムアウト | 30秒 | LoginGraceTime 30 |
| Keep-Alive | 300秒間隔 | ClientAliveInterval 300 |
| ポート転送 | 許可 | AllowTcpForwarding yes |
| Gateway | 無効 | GatewayPorts no |
| Root Login | 無効 | PermitRootLogin no |

### ユーザ設定
- **作成**: 指定UID/GIDで自動作成（存在しない場合）
- **SSH公開鍵**: **必須** - ConfigMap経由で提供
- **ユーザ名**: **必須** - ユーザ作成に使用
- **UID/GID**: オプション（未指定時は自動割り当て）
- **ホームディレクトリ**: 永続化オプション（10GiB）、無効時はemptyDir使用
- **sudo権限**: オプション（無効）
- **設定ファイル**: ディストリビューションデフォルト使用

### X11転送
- ローカルホストからの接続のみ許可
- sshdの転送オプション使用

## 3. セキュリティ設定

### セキュリティレベル
| レベル | 用途 | readOnlyRootFilesystem | 追加機能 |
|--------|------|------------------------|----------|
| Basic | 開発・テスト | false | 最小限制限 |
| Standard | 推奨 | true | seccomp有効 |
| High | 本番環境 | true | seccomp RuntimeDefault |

### Pod Security Context
- **runAsNonRoot**: false（root実行必須）
- **readOnlyRootFilesystem**: true（Basicレベル時はfalse）
- **allowPrivilegeEscalation**: false（sudo有効時は自動でtrue）

### Capabilities
- **drop**: ["ALL"]
- **add**: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE"]
- **sudo有効時**: ["SETPCAP", "SYS_ADMIN"]を追加

### ファイルシステム
- **読み取り専用ルート**: セキュリティ強化
- **emptyDir マウント**:
  - /var/run: PIDファイル（10Mi）
  - /tmp: 一時ファイル・X11ソケット（100Mi）
  - /var/empty: sshd特権分離プロセス用

## 4. サービス・アクセス設定

### Service・Network
| 項目 | デフォルト | 選択肢 |
|------|------------|--------|
| Service Type | ClusterIP | NodePort/LoadBalancer |
| SSH Port | 22 | カスタマイズ可能 |
| 外部公開 | SSH のみ | localhost アクセス許可 |
| Ingress | 無効 | TLS終端・トンネリング対応 |

### ネットワークセキュリティ
- 不要なポートの無効化
- ネットワークレベル制限は外部NetworkPolicyで実施

## 5. 監視・運用

### ヘルスチェック
- **Liveness**: SSHプロセス生存確認（/usr/sbin/sshd -t）
- **Readiness**: SSHポート接続確認
- **Shutdown**: terminationGracePeriod対応

### 監視・メトリクス（オプション）
- **ssh_exporter**: サイドカーコンテナ
- **収集データ**: SSH接続数、レスポンス時間、認証失敗数
- **Prometheus**: ServiceMonitor設定
- **標準メトリクス**: CPU・メモリ・PVC使用量

### エラーハンドリング・運用
| 状況 | 対応 |
|------|------|
| 初期化失敗 | pre-install hookでエラー出力 |
| SSH公開鍵無効 | 起動停止 |
| UID/GID競合 | エラーで起動停止 |
| PVCマウント失敗 | Pod Pending状態 |
| アップグレード | Recreate戦略（ダウンタイム許容） |
| データ保護 | `helm.sh/resource-policy: keep` |
| 自動復旧 | restartPolicy Always |

## 6. Helm Chart・技術仕様

### Chart.yaml
```yaml
apiVersion: v2
name: ssh-workspace
type: application
version: 1.0.0
appVersion: "1.0.0"
description: SSH accessible workspace environment
keywords: [ssh, workspace, development, terminal]
maintainers:
  - name: SSH Workspace Team
    email: maintainer@example.com
```

### Values.yaml構造
```yaml
image:
  repository: # UbuntuベースSSHサーバー
  tag: # セマンティックバージョン
  pullPolicy: # latest=Always, 固定=IfNotPresent
  pullSecrets: [] # Private Registry対応

user:
  name: "" # ユーザ名（必須）
  uid: null # ユーザID（オプション、未指定時は自動割り当て）
  gid: null # グループID（オプション、未指定時は自動割り当て）
  shell: /bin/bash # ログインシェル
  additionalGroups: [] # 追加グループ
  sudo: false # sudo権限

ssh:
  publicKeys: [] # SSH公開鍵（必須、配列形式）
  port: 22 # SSHポート
  config: {} # カスタム設定

persistence:
  enabled: false # 永続化有効/無効
  size: 10Gi # ストレージサイズ
  storageClass: "" # ストレージクラス
  accessModes: [ReadWriteOnce] # アクセスモード

security:
  level: standard # basic/standard/high
  securityContext: {} # Pod Security Context
  podSecurityContext: {} # Container Security Context

service:
  type: ClusterIP # Service Type
  port: 22 # Service Port

resources: {} # CPU・メモリ制限
timezone: UTC # タイムゾーン（tzdataパッケージ）
monitoring:
  enabled: false # ssh_exporter有効/無効
ingress:
  enabled: false # Ingress有効/無効
  # annotations, className, TLS設定等

# デプロイ時決定パラメータ以外は全てデフォルト値設定済み
```

### Helm機能
- **Schema**: values.schema.jsonによる型検証
- **Hooks**: 
  - pre-install: SSH公開鍵検証（必須）
  - post-install: 初期化完了確認
  - pre-upgrade: 互換性確認
  - test: SSH接続テスト
- **NOTES.txt**: SSH接続手順、永続化警告、トラブルシューティング
- **Labels**: app.kubernetes.io/* 標準ラベル
- **必須パラメータ**: SSH公開鍵、ユーザ名
- **Values設計**: デプロイ時決定事項以外は全てオプション（デフォルト値提供）

## 7. 制限事項

- **単一ユーザー専用**: マルチユーザー非対応
- **root実行必須**: セキュリティコンテキストで制限
- **永続化範囲**: ホームディレクトリのみ
- **X11転送**: ローカルホスト経由のみ
- **外部公開ポート**: SSH以外は不可
- **追加パッケージ**: カスタムイメージで対応