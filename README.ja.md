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

# SSH公開鍵は環境変数で提供
docker run -d -p 2222:22 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  ssh-workspace

ssh developer@localhost -p 2222
```

### Kubernetesで実行

```bash
cd helm
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"

kubectl port-forward svc/workspace-ssh-workspace 2222:2222
ssh developer@localhost -p 2222
```

**注意**: テスト目的では、自動SSH接続テスト用に`ssh.testKeys`を有効にできます。テストSSHキーはテスト完了後に自動的にクリーンアップされ、安全に使用できます。追加機能の詳細については[高度な設定](#6-高度な設定)を参照してください。

```bash
# 自動テスト用のテストキーを有効化
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com" \
  --set ssh.testKeys.enabled=true
```

## 🔄 CI/CD & コンテナレジストリ

### GitHub Container Registry (GHCR)

ビルド済みイメージがGitHub Container Registryで利用可能です：

**プラットフォームサポート:**
- ✅ **linux/amd64**: 完全にテスト済み・サポート対象
- ⚠️ **linux/arm64**: ビルド済みだがCIでは未テスト（ARM64システムでは動作するはず）

```bash
# 最新イメージをプル
docker pull ghcr.io/kaznak/ssh-workspace:latest

# Helm Chartで使用
helm install workspace ./helm/ssh-workspace \
  --set image.repository=ghcr.io/kaznak/ssh-workspace \
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
| **セキュリティスキャン** | 日次/Push | Trivyによる脆弱性スキャン + SARIFレポート |
| **Helmリリース** | Chart変更 | Chartのパッケージと公開 |
| **Pages Helmリポジトリ** | Chart変更 | GitHub Pages Helmリポジトリ |

### Helm Chartインストール

#### 方法1: OCIレジストリ（推奨）

```bash
# GHCRから直接インストール
helm install workspace \
  oci://ghcr.io/kaznak/charts/ssh-workspace \
  --version 1.0.0 \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

#### 方法2: 従来のHelmリポジトリ

```bash
# リポジトリを追加
helm repo add ssh-workspace https://kaznak.github.io/helm-ssh-workspace/
helm repo update

# Chartをインストール
helm install workspace ssh-workspace/ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

#### 方法3: ローカルインストール

```bash
# リポジトリをクローンしてローカルでインストール
git clone https://github.com/kaznak/helm-ssh-workspace.git
cd helm-ssh-workspace
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
- **作成**: Init Containerにより指定UID/GIDで自動作成（存在しない場合）
- **SSH公開鍵**: **必須** - ConfigMap経由で提供、Init Containerで検証・設定
- **ユーザ名**: **必須** - システムユーザ作成（`useradd`）に使用
- **UID/GID**: オプション（未指定時は自動割り当て）
- **ホームディレクトリ**: 永続化オプション（10GiB）、無効時はemptyDir使用
- **sudo権限**: オプション（デフォルト無効）、Init Container設定時に構成
- **設定ファイル**: ディストリビューションデフォルト使用
- **セキュリティ**: ユーザ作成はInit Containerに分離、メインコンテナは事前設定済みユーザで実行

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

### 権限管理戦略

チャートではボリューム所有権に対して明示的な権限管理を使用します：

- **explicit**: fsGroupなしでの直接UID/GID管理（SetGIDビットなし）
- 必要なcapability（CHOWN、DAC_OVERRIDE、FOWNER）による手動ファイル所有権制御
- 異なるKubernetes環境での一貫した動作を提供

### Pod Security Context
- **runAsNonRoot**: false（root実行必須）
- **readOnlyRootFilesystem**: true（Basicレベル時はfalse）
- **allowPrivilegeEscalation**: false（sudo有効時は自動でtrue）

### Capabilities

#### メインコンテナ
- **drop**: ["ALL"]
- **add**: 
  - 基本capabilities: ["SETUID", "SETGID", "SYS_CHROOT"]
  - 権限管理: ["CHOWN", "DAC_OVERRIDE", "FOWNER"]
  - sudo有効時: ["SETPCAP", "SYS_ADMIN"]

#### Init Container
- **drop**: ["ALL"]
- **add**: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE", "FOWNER"]

### Init Containerアーキテクチャ

SSH Workspaceは、セキュリティ強化のため**デュアルコンテナInit Containerパターン**を採用しています：

#### Init Container (ssh-setup)
- **目的**: ユーザ作成とSSH設定のセットアップ
- **セキュリティコンテキスト**: 
  - `readOnlyRootFilesystem: false`（システム変更に必要）
  - `allowPrivilegeEscalation: true`
  - Capabilities: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`
- **操作内容**:
  - `groupadd`/`useradd`を使用したユーザ・グループ作成
  - SSH ディレクトリ構造の設定（`/home/user/.ssh`）
  - 適切な権限でのSSH authorized_keys設定
  - グループメンバーシップとsudo設定の検証
- **実行時間**: 短時間（設定完了後に終了）
- **ネットワーク公開**: なし（ポート公開なし）

#### メインコンテナ (ssh-workspace)
- **目的**: SSHデーモンサービスのみ
- **セキュリティコンテキスト**:
  - `readOnlyRootFilesystem: true`（最大セキュリティ）
  - `allowPrivilegeEscalation: false`
  - SSH動作に必要な最小限capabilities
- **操作内容**: 
  - SSHデーモンの実行（`/usr/sbin/sshd -D -e`）
  - Init Containerで事前設定されたユーザ・SSH設定を使用
  - 動的なシステム変更は行わない
- **ネットワーク公開**: SSH ポート2222のみ

#### 共有リソース
- **EmptyDir Volume (`/etc`)**: ユーザ・グループ情報とSSH設定
- **EmptyDir/PVC Volume (`/home`)**: ユーザホームディレクトリ
- **ConfigMap**: SSH公開鍵
- **セキュリティ上の利点**:
  - 権限の分離: セットアップ vs ランタイム
  - 攻撃面の削減: メインコンテナはシステムファイルを変更不可
  - 特権操作中のネットワーク公開なし

### ファイルシステム
- **読み取り専用ルート**: セキュリティ強化（メインコンテナ）
- **emptyDir マウント**:
  - /etc: 共有ユーザ設定（Init Containerから）
  - /var/run: PIDファイル（10Mi）
  - /tmp: 一時ファイル・X11ソケット（100Mi）
  - /var/empty: sshd特権分離プロセス用

## 4. サービス・アクセス設定

### Service・Network
| 項目 | デフォルト | 選択肢 |
|------|------------|--------|
| Service Type | ClusterIP | NodePort/LoadBalancer |
| SSH Port | 2222 | カスタマイズ可能 |
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

### Pod Disruption Budget (PDB) 考慮事項

**⚠️ 重要: Pod Disruption Budgetはサポートされていません**

このHelm Chartは、以下のアーキテクチャ制約により意図的にPDBサポートを含んでいません：

1. **シングルレプリカ設計**: SSH Workspaceは単一Pod（`replicas: 1`）で動作します：
   - 各ワークスペースは永続セッション状態を持つ単一ユーザー専用
   - ホームディレクトリ永続化は`ReadWriteOnce` PVC（単一ノードアクセスのみ）を使用
   - 複数レプリカはSSHセッション継続性とファイル整合性を破損させる

2. **Recreate戦略**: デプロイメントは`strategy: type: Recreate`を使用：
   - 新しいPodを開始する前にクリーンシャットダウンを保証
   - 永続ボリュームのデータ破損を防止
   - PDBのローリングアップデート前提と非互換

3. **運用影響**: `minAvailable: 1`でPDBを追加すると：
   - 全てのクラスターメンテナンス作業を永続的にブロック
   - ノードドレイン時のPod退避を阻止
   - 手動介入が必要なデッドロック状況を作成

**推奨アプローチ**: クラスターメンテナンス時は、計画的ダウンタイムを設定し、ワークスペースユーザーと連携してください。永続ホームディレクトリによりPod再起動時にもデータ損失はありません。

## 6. 高度な設定

### ホームディレクトリ永続化

SSH Workspaceは、様々な用途に対応する柔軟なホームディレクトリ永続化オプションを提供します：

#### 要件
1. **作業データの永続化と再利用** - 新規および既存PVCの両方をサポート
2. **適切なデータ分離** - 適切なデータ組織化のためのサブディレクトリマウント機能

#### 設定オプション

##### 基本永続化（新規PVC）
```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: "fast-ssd"  # オプション、空の場合はデフォルトを使用
```

##### 既存PVCの使用
```yaml
persistence:
  enabled: true
  existingClaim: "my-existing-data"  # 既存PVCを使用
  # existingClaimが指定された場合、sizeとstorageClassは無視される
```

##### サブディレクトリマウント
PVCから特定のサブディレクトリをマウント。以下の用途に便利：
- 複数のワークスペース間での大きなPVCの共有
- ユーザー、プロジェクト、環境によるデータ組織化
- 既存のデータ構造の活用

```yaml
persistence:
  enabled: true
  existingClaim: "shared-team-storage"
  subPath: "users/developer"  # このサブディレクトリのみをマウント
```

##### 高度な例

**マルチユーザー共有ストレージ:**
```yaml
persistence:
  enabled: true
  existingClaim: "department-storage"
  subPath: "workspaces/{{ .Values.user.name }}"
```

**プロジェクトベース組織化:**
```yaml
persistence:
  enabled: true
  existingClaim: "project-data"
  subPath: "environments/dev/users/{{ .Values.user.name }}"
```

**完全な設定リファレンス:**
```yaml
persistence:
  enabled: true              # 永続化の有効/無効
  existingClaim: ""          # 既存PVC名（オプション）
  subPath: ""                # PVC内のサブディレクトリ（オプション）
  size: 10Gi                 # 新規PVCのサイズ（existingClaimが設定されている場合は無視）
  storageClass: ""           # 新規PVCのStorageClass（オプション）
  accessModes:
    - ReadWriteOnce          # アクセスモード（シングルユーザーワークスペースにはRWOが必要）
```

#### 実装メモ
- `existingClaim`が空の場合、`{release-name}-ssh-workspace-home`という名前の新規PVCが作成される
- `subPath`は空（PVC全体をマウント）またはサブディレクトリパスを指定可能
- サブディレクトリが存在しない場合は自動的に作成される
- マウントされたディレクトリ内のファイル操作は制限なく正常に動作する

### テスト設定

#### SSH テストキー
自動テストやCI/CDパイプライン用に専用のテストSSHキーを設定できます：

```yaml
ssh:
  testKeys:
    enabled: true
    keyPairs:
      - publicKey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrShAQgt+9ZuPDQ1L2KrSwKxL8BEcqhytt7X3ZLZxai test-key@helm-test"
        privateKey: |
          -----BEGIN OPENSSH PRIVATE KEY-----
          b3BlbnNzaC1QlkeXktZZlnBUKmhp4AAAAC1lZQI5NTE5AAAAIGrShAQgt+9ZuPDQ1L2K
          rSwKxL8BEcqhytt7X3ZLZxaiAAAAFHRlc3Qta2V5QGhlbG0tdGVzdA==
          -----END OPENSSH PRIVATE KEY-----
```

**セキュリティ注意事項:**
- テストキーは`helm.sh/hook-delete-policy: hook-succeeded`でKubernetes Secretに保存
- Secretは**テスト完了後に自動削除**される
- テストキーは**テスト実行中のみ存在**（通常2-3分間）
- 秘密鍵はログや永続ストレージに露出されない

#### テストRBAC設定
```yaml
tests:
  rbac:
    create: true  # テスト用のServiceAccount、Role、RoleBindingを作成
```

SSH接続検証と権限チェックを含む包括的なテストを有効にします。

#### デバッグ設定
デプロイメントの問題をトラブルシューティングするためのデバッグモードが利用可能です：

```bash
# chmod失敗分析用のデバッグモードを有効化（開発・トラブルシューティング専用）
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com" \
  --set-string 'extraEnvVars[0].name=SSH_WORKSPACE_DEBUG_CHMOD_FAILURES' \
  --set-string 'extraEnvVars[0].value=true'
```

**重要なセキュリティ警告:**
- `SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true` はauthorized_keysのchmodが失敗してもコンテナ起動を許可します
- **デフォルト**: `false`（安全） - chmodが失敗するとコンテナが終了し、安全でないデプロイメントを防止
- **有効時**: 詳細な診断情報を提供しますが、ファイル権限が不適切（600ではなく644）になる可能性があります
- **用途**: 開発時のトラブルシューティングのみ、**本番環境では絶対に使用禁止**
- **影響**: 有効にすると、不適切なファイル権限でSSHアクセスが動作し、セキュリティ脆弱性を作成する可能性があります

このデバッグモードは、ファイルシステムの制限や権限不足によりchmod操作が失敗する可能性がある開発環境での権限問題の診断を支援するために設計されています。

### 運用設定

#### ノード配置とスケジューリング
```yaml
# 特定ノードをターゲット
nodeSelector:
  kubernetes.io/arch: amd64
  node.kubernetes.io/instance-type: m5.large

# ノードtaintの許容
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "ssh-workspaces"
    effect: "NoSchedule"

# Pod affinity ルール
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: ssh-workspace
          topologyKey: kubernetes.io/hostname
```

#### メタデータとラベル付け
```yaml
# 全リソース用の追加ラベル
labels:
  environment: production
  team: platform
  cost-center: "12345"

# 追加アノテーション
annotations:
  monitoring.coreos.com/scrape: "true"
  backup.velero.io/backup-volumes: "home"
```

### 高度な監視

#### Prometheus統合
```yaml
monitoring:
  enabled: true
  port: 9312
  serviceMonitor:
    enabled: true      # Prometheus Operator用のServiceMonitorを作成
    interval: 30s      # メトリクス収集頻度
```

**利用可能なメトリクス:**
- SSH接続数と期間
- 認証成功/失敗率
- リソース使用率（CPU、メモリ、ディスク）

## 7. 開発環境セットアップ

SSH Workspaceには、開発用パッケージマネージャーとツールをインストールするための包括的なセットアップスクリプトが含まれています。

### ステップ1: パッケージマネージャーのインストール

まず、基盤となるパッケージマネージャー（Linuxbrew、NVM経由のNode.js、Rust）をインストールします：

```bash
# 全パッケージマネージャーをインストール
/opt/ssh-workspace/bin/user-package-managers.sh

# または特定のパッケージマネージャーのみをインストール
/opt/ssh-workspace/bin/user-package-managers.sh --homebrew-only
/opt/ssh-workspace/bin/user-package-managers.sh --node-only  
/opt/ssh-workspace/bin/user-package-managers.sh --rust-only
```

**機能:**
- **Linuxbrew**: Linux用の現代的なパッケージマネージャー
- **Node.js**: NVM経由での自動バージョン検出付きモダンJavaScriptランタイム
- **Rust**: システムプログラミング言語とツールチェーン
- **安全性・セキュリティ**: 公式インストール方法、HTTPS ダウンロード、検証チェック

### ステップ2: 開発ツールのインストール

パッケージマネージャーのインストール後、包括的な開発ツールをインストールします：

```bash
# 全開発ツールをインストール（ステップ1のパッケージマネージャーが必要）
/opt/ssh-workspace/bin/install-user-packages.sh
```

**インストールされるツール:**
- **コマンドラインツール**: `ripgrep`, `jq`, `stow`, `htop`, `tree`, `tmux`, `screen`
- **Kubernetes ツール**: `kubectl`, `helm`, `kustomize`, `helmfile`, `sops`, `age`, `talosctl`
- **Helm プラグイン**: `helm-diff`, `helm-git`, `helm-s3`, `helm-secrets`
- **Python ツール**: `uv` (現代的なPythonパッケージマネージャー)
- **オントロジーツール**: `raptor`, `jena` (セマンティックWeb開発)
- **Node.js ツール**: `@anthropic-ai/claude-code` (Claude Code CLI)
- **Rust ツール**: `cargo-edit`, `cargo-watch` と `rustfmt`, `clippy`

**環境変数:**
```bash
# 最新バージョンを自動検出（デフォルト動作）
/opt/ssh-workspace/bin/user-package-managers.sh

# またはステップ1用に特定バージョンをカスタマイズ
NVM_VERSION=v0.39.0 NODE_VERSION=18 /opt/ssh-workspace/bin/user-package-managers.sh

# ステップ2用にNode.jsバージョンをカスタマイズ
NODE_VERSION=18 /opt/ssh-workspace/bin/install-user-packages.sh
```

**インストール後:**
```bash
# シェル環境をリロード
source ~/.bashrc

# インストール確認
brew --version
node --version
cargo --version

# インストールしたツールを使用
kubectl version --client
helm version
jq --version
tmux -V
```

## 8. Helm Chart・技術仕様

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
  - name: Nakamura Kazutaka
    email: kaznak.at.work@ipebble.org
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
  port: 2222 # SSHポート
  config: {} # カスタム設定
  testKeys: # 自動テスト用テストSSHキー（オプション）
    enabled: false # テストキー機能の有効化
    keyPairs: [] # テストキーペア（公開鍵 + 秘密鍵）

persistence:
  enabled: false # 永続化有効/無効
  size: 10Gi # ストレージサイズ
  storageClass: "" # ストレージクラス
  accessModes: [ReadWriteOnce] # アクセスモード

security:
  level: standard # basic/standard/high
  securityContext: {} # 追加Container Security Context
  podSecurityContext: {} # 追加Pod Security Context

service:
  type: ClusterIP # Service Type
  port: 2222 # Service Port

resources: {} # CPU・メモリ制限
timezone: UTC # タイムゾーン（tzdataパッケージ）

# ノード配置とスケジューリング
nodeSelector: {} # ノード選択制約
tolerations: [] # ノードtaintの許容
affinity: {} # Pod affinity/anti-affinity ルール

# 追加メタデータ
labels: {} # 追加Podとリソースラベル
annotations: {} # 追加Podとリソースアノテーション

# 高可用性と運用
podDisruptionBudget:
  enabled: false # Pod Disruption Budgetの有効化
  minAvailable: 1 # 中断時の最小利用可能レプリカ数

monitoring:
  enabled: false # ssh_exporter有効/無効
  port: 9312 # メトリクスポート
  serviceMonitor:
    enabled: false # Prometheus用ServiceMonitorの作成
    interval: 30s # メトリクス収集間隔

ingress:
  enabled: false # Ingress有効/無効
  className: "" # Ingressクラス名
  annotations: {} # Ingressアノテーション
  hosts: [] # Ingressホスト設定
  tls: [] # TLS設定

# テスト設定
tests:
  rbac:
    create: true # テスト用ServiceAccountとRBACの作成

# デプロイ時決定パラメータ以外は全てデフォルト値設定済み
```

### Helm機能
- **Schema**: values.schema.jsonによる型検証
- **Init Containerパターン**: ユーザセットアップとSSHサービスの安全なデュアルコンテナアーキテクチャ
- **Hooks**: 
  - pre-install: SSH公開鍵形式検証（Init Container実行前）
  - post-install: SSH接続確認
  - pre-upgrade: 互換性とデータ移行チェック
  - test: エンドツーエンドSSH接続テスト
- **NOTES.txt**: SSH接続手順、Init Containerステータス、永続化警告、トラブルシューティング
- **Labels**: app.kubernetes.io/* 標準ラベル
- **必須パラメータ**: SSH公開鍵、ユーザ名
- **Values設計**: デプロイ時決定事項以外は全てオプション（デフォルト値提供）

## 9. セキュリティ監視

### 自動セキュリティスキャン

このプロジェクトでは包括的なセキュリティ監視を実装：

- **日次脆弱性スキャン**: コンテナセキュリティのためのTrivy自動スキャン
- **SARIF統合**: SARIF（Static Analysis Results Interchange Format）形式でGitHub Security統合
- **GitHub Securityタブ**: `/security/code-scanning`で詳細な脆弱性レポートを表示
- **リアルタイムアラート**: 新しいセキュリティ問題の自動通知
- **コンプライアンスレポート**: 監査・コンプライアンス用の標準化セキュリティレポート

### SARIFセキュリティレポート

自動セキュリティスキャン結果を表示:
- **SARIFレポート**: [Code Scanning結果](https://github.com/kaznak/helm-ssh-workspace/security/code-scanning) - SARIF形式のTrivy脆弱性スキャン

**ナビゲーション**: リポジトリ → Securityタブ → Code scanning

### その他のセキュリティ機能

- **Dependabot**: [依存関係アラート](https://github.com/kaznak/helm-ssh-workspace/security/dependabot) - 依存関係脆弱性管理（SARIFとは別機能）
- **セキュリティ概要**: [セキュリティダッシュボード](https://github.com/kaznak/helm-ssh-workspace/security) - 完全なセキュリティ概要
- **Security Policy**: `SECURITY.md` - 責任ある開示ガイドライン

## 10. 制限事項

- **単一ユーザー専用**: マルチユーザー非対応
- **root実行必須**: セキュリティコンテキストで制限
- **永続化範囲**: ホームディレクトリのみ
- **X11転送**: ローカルホスト経由のみ
- **外部公開ポート**: SSH以外は不可
- **追加パッケージ**: カスタムイメージで対応