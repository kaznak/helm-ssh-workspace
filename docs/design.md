# 設計書

## 概要

README.ja.mdの要求・要件を満たすDropbear SSH ワークスペースHelmチャートの実装設計。

## 全体アーキテクチャ

### コンポーネント構成

- **Dropbear SSH サーバ**: 非特権で動作するSSHサーバ - [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL), [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- **開発環境**: Linux with linuxbrew + 開発ツール群 - [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS), [[M4J7-BREW]](../README.ja.md#M4J7-BREW)
- **初期化コンテナ**: SSH鍵・ホストキー生成用 - [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY), [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)
- **共有ストレージ**: ホームディレクトリ（emptyDir or PVC） - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME), [[T1H8-EMPTY]](../README.ja.md#T1H8-EMPTY)

### データフロー

- SSH鍵認証 → Dropbear SSH → シェルアクセス - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH), [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL)
- ポートフォワーディング（localhost限定） - [[X8D2-FORWARD]](../README.ja.md#X8D2-FORWARD), [[L9K6-LOCAL]](../README.ja.md#L9K6-LOCAL)
- 開発ツール via linuxbrew（ユーザランド） - [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS), [[M4J7-BREW]](../README.ja.md#M4J7-BREW)

## Docker イメージ設計

### ベースイメージ
Ubuntu/Debian（linuxbrew対応） - [[M4J7-BREW]](../README.ja.md#M4J7-BREW)

### コンテナ構成
- **非特権ユーザ**: values.yamlで設定可能（デフォルト: `developer`, uid=1000, gid=1000） - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT), [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL), [[Y4F1-USER]](../README.ja.md#Y4F1-USER)
- **Dropbear SSH**: ユーザランドで動作、ポート2222 - [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT), [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- **開発ツール**: linuxbrew経由でインストール - [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS), [[M4J7-BREW]](../README.ja.md#M4J7-BREW)
- **エントリポイント**: SSH鍵設定 + Dropbear起動 - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH), [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY)

### 必要パッケージ
- dropbear-bin - [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL)
- linuxbrew依存関係 - [[M4J7-BREW]](../README.ja.md#M4J7-BREW)
- 基本開発ツール（git, curl, vim等） - [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS)

## Kubernetes リソース設計

### Deployment - [[J8R2-DEPLOY]](../README.ja.md#J8R2-DEPLOY)
- replicas: 1（固定） - [[G9W8-FIXED]](../README.ja.md#G9W8-FIXED), [[J8R2-DEPLOY]](../README.ja.md#J8R2-DEPLOY)
- securityContext: restricted policy準拠 - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- containers:
  - main: Dropbear SSH + 開発環境 - [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL), [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS)
  - ports: 2222/tcp - [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT)
  - volumeMounts: home directory - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME)
  - livenessProbe: SSH接続確認 - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)
  - readinessProbe: SSH接続確認 - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)

### Service - [[N4V9-SVC]](../README.ja.md#N4V9-SVC)
- type: ClusterIP（デフォルト） - [[E4L7-CLUSTER]](../README.ja.md#E4L7-CLUSTER), [[N4V9-SVC]](../README.ja.md#N4V9-SVC)
- port: 2222 - [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT)
- targetPort: 2222 - [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT)

### ConfigMap
- Dropbear設定ファイル - [[X8D2-FORWARD]](../README.ja.md#X8D2-FORWARD), [[L9K6-LOCAL]](../README.ja.md#L9K6-LOCAL)
- 初期化スクリプト - [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY)

### Secret
- SSH認証鍵 - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH)
- ホストキー - [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY), [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)

### PVC（オプション）
- ホームディレクトリ永続化用 - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME), [[R7P4-STORAGE]](../README.ja.md#R7P4-STORAGE), [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST), [[C6B2-SUBDIR]](../README.ja.md#C6B2-SUBDIR)

## values.yaml 設定項目設計

```yaml
# イメージ設定
image:
  repository: helm-ssh-workspace
  tag: latest
  pullPolicy: IfNotPresent

# ユーザ設定 - [Y4F1-USER](../README.ja.md#Y4F1-USER)
user:
  name: developer  # [G8W5-USERNAME](../README.ja.md#G8W5-USERNAME)
  uid: 1000  # [Z2S7-UID](../README.ja.md#Z2S7-UID)
  gid: 1000  # [A9T3-GID](../README.ja.md#A9T3-GID)

# SSH設定 - [B3Q8-PORT](../README.ja.md#B3Q8-PORT), [L6H3-KEYAUTH](../README.ja.md#L6H3-KEYAUTH)
ssh:
  port: 2222  # [B3Q8-PORT](../README.ja.md#B3Q8-PORT)
  authorizedKeys: []  # SSH公開鍵リスト - [L6H3-KEYAUTH](../README.ja.md#L6H3-KEYAUTH)

# サービス設定 - [W9F5-SERVICE](../README.ja.md#W9F5-SERVICE), [E4L7-CLUSTER](../README.ja.md#E4L7-CLUSTER)
service:
  type: ClusterIP  # [E4L7-CLUSTER](../README.ja.md#E4L7-CLUSTER)
  port: 2222  # [B3Q8-PORT](../README.ja.md#B3Q8-PORT)

# ストレージ設定 - [V5Q3-HOME](../README.ja.md#V5Q3-HOME)
storage:
  type: emptyDir  # emptyDir or persistentVolume - [T1H8-EMPTY](../README.ja.md#T1H8-EMPTY)
  persistentVolume:
    size: 10Gi
    storageClass: ""  # [R7P4-STORAGE](../README.ja.md#R7P4-STORAGE)
    subPath: ""  # [C6B2-SUBDIR](../README.ja.md#C6B2-SUBDIR)

# リソース制限 - [J1X6-LIMIT](../README.ja.md#J1X6-LIMIT)
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 100m
    memory: 256Mi

# セキュリティ設定 - [T9D5-SEC](../README.ja.md#T9D5-SEC)
security:
  hostKeysPersistent: true  # [R8N9-REUSE](../README.ja.md#R8N9-REUSE)
  
# ヘルスチェック設定 - [Q1P4-HEALTH](../README.ja.md#Q1P4-HEALTH)
healthcheck:
  livenessProbe:
    enabled: true
  readinessProbe:
    enabled: true
```

## セキュリティ実装方針

### Pod Security Standards - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- runAsNonRoot: true - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- runAsUser: 1000 - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- allowPrivilegeEscalation: false - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- seccompProfile: RuntimeDefault - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- capabilities: drop ALL - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)

### SSH認証 - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH)
- パスワード認証無効 - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH)
- 公開鍵認証のみ - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH)
- authorized_keys via ConfigMap/Secret - [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH)

### 鍵管理 - [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY), [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)
- ホストキー: 初期化時生成 - [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY)
- PVC or Secret で永続化 - [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)
- release削除後も保持 - [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)

## ログ・監視実装方針

### 構造化ログ - [[K5G2-STRUCT]](../README.ja.md#K5G2-STRUCT)
- JSON形式でログ出力 - [[K5G2-STRUCT]](../README.ja.md#K5G2-STRUCT)
- Dropbear設定でverbose logging - [[K5G2-STRUCT]](../README.ja.md#K5G2-STRUCT)
- 接続/切断イベント記録 - [[K5G2-STRUCT]](../README.ja.md#K5G2-STRUCT)

### メトリクス - [[F7C8-METRICS]](../README.ja.md#F7C8-METRICS)
- SSH接続数: netstat経由 - [[F7C8-METRICS]](../README.ja.md#F7C8-METRICS)
- リソース使用量: /proc/stat, /proc/meminfo - [[F7C8-METRICS]](../README.ja.md#F7C8-METRICS)
- カスタムメトリクス出力スクリプト - [[F7C8-METRICS]](../README.ja.md#F7C8-METRICS)

### ヘルスチェック - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)
- livenessProbe: SSH接続テスト - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)
- readinessProbe: SSH接続テスト - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)
- 定期的なプローブ実行 - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)

## 実装優先度と段階

### Phase 1: 基本機能
- Dropbear SSH + 開発環境コンテナ - [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL), [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS)
- 基本的なDeployment/Service - [[J8R2-DEPLOY]](../README.ja.md#J8R2-DEPLOY), [[N4V9-SVC]](../README.ja.md#N4V9-SVC)
- emptyDir ストレージ - [[T1H8-EMPTY]](../README.ja.md#T1H8-EMPTY)

### Phase 2: 設定可能性
- values.yaml 設定項目実装 - [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT), [[E4L7-CLUSTER]](../README.ja.md#E4L7-CLUSTER), [[R7P4-STORAGE]](../README.ja.md#R7P4-STORAGE)
- PVC対応 - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME), [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST), [[C6B2-SUBDIR]](../README.ja.md#C6B2-SUBDIR)
- リソース制限 - [[J1X6-LIMIT]](../README.ja.md#J1X6-LIMIT)

### Phase 3: セキュリティ・監視
- Pod Security Standards準拠 - [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- ヘルスチェック実装 - [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH)
- 構造化ログ対応 - [[K5G2-STRUCT]](../README.ja.md#K5G2-STRUCT), [[F7C8-METRICS]](../README.ja.md#F7C8-METRICS)

## 要求・要件マッピング

### 機能要件
- [[P3R8-SHELL]](../README.ja.md#P3R8-SHELL) シングルユーザSSHアクセス → Dropbear SSH + 単一developerユーザ
- [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS) 開発ツール提供 → linuxbrew + 基本ツール
- [[M4J7-BREW]](../README.ja.md#M4J7-BREW) linuxbrew利用 → 非特権ユーザでのlinuxbrew導入
- [[X8D2-FORWARD]](../README.ja.md#X8D2-FORWARD) SSHポートフォワーディング → Dropbear設定で有効化
- [[L9K6-LOCAL]](../README.ja.md#L9K6-LOCAL) localhost限定 → Dropbear設定で制限
- [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME) ストレージ選択 → values.yaml設定
- [[T1H8-EMPTY]](../README.ja.md#T1H8-EMPTY) emptyDirデフォルト → デフォルト設定
- [[R7P4-STORAGE]](../README.ja.md#R7P4-STORAGE) StorageClass設定 → values.yaml設定
- [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST) PVC永続化 → PVC作成・再利用
- [[C6B2-SUBDIR]](../README.ja.md#C6B2-SUBDIR) サブディレクトリマウント → PVC subPath設定
- [[Y4F1-USER]](../README.ja.md#Y4F1-USER) ユーザ設定 → values.yaml設定
- [[G8W5-USERNAME]](../README.ja.md#G8W5-USERNAME) ユーザ名設定 → values.yaml設定、デフォルトdeveloper
- [[Z2S7-UID]](../README.ja.md#Z2S7-UID) UID設定 → values.yaml設定、デフォルト1000
- [[A9T3-GID]](../README.ja.md#A9T3-GID) GID設定 → values.yaml設定、デフォルト1000

### リソース管理
- [[J1X6-LIMIT]](../README.ja.md#J1X6-LIMIT) リソース制限設定 → values.yaml resources設定

### ネットワーク・外部アクセス
- [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT) SSH Port設定 → values.yaml設定、デフォルト2222
- [[W9F5-SERVICE]](../README.ja.md#W9F5-SERVICE) Service利用 → Service リソース作成
- [[E4L7-CLUSTER]](../README.ja.md#E4L7-CLUSTER) Service type設定 → values.yaml設定、デフォルトClusterIP
- [[U8N4-INGRESS]](../README.ja.md#U8N4-INGRESS) Ingressなし → Ingress リソース作成しない
- [[I2M6-NETPOL]](../README.ja.md#I2M6-NETPOL) NetworkPolicyなし → NetworkPolicy リソース作成しない

### ログ・監視
- [[K5G2-STRUCT]](../README.ja.md#K5G2-STRUCT) 構造化ログ → JSON形式ログ出力
- [[F7C8-METRICS]](../README.ja.md#F7C8-METRICS) 監視メトリクス → カスタムメトリクス出力
- [[Q1P4-HEALTH]](../README.ja.md#Q1P4-HEALTH) ヘルスチェック → liveness/readiness probe

### セキュリティ
- [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT) restricted policy → securityContext設定
- [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH) SSH鍵認証のみ → Dropbear設定
- [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY) ホストキー生成 → 初期化時生成
- [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE) ホストキー永続化 → PVC/Secret保存

### 運用
- [[Y3S2-DOWN]](../README.ja.md#Y3S2-DOWN) ダウンタイム許容 → 単一replica
- [[C5Q4-TEMP]](../README.ja.md#C5Q4-TEMP) 作成・削除運用 → Helmチャートでの管理
- [[G9W8-FIXED]](../README.ja.md#G9W8-FIXED) 自動スケーリング無効 → replica固定

### バックアップ・復旧
- [[Z4T5-NOPROV]](../README.ja.md#Z4T5-NOPROV) PVレイヤ機能 → チャート外で提供

### k8s デプロイ構成
- [[J8R2-DEPLOY]](../README.ja.md#J8R2-DEPLOY) deployment replicas=1 → Deployment設定
- [[N4V9-SVC]](../README.ja.md#N4V9-SVC) service ClusterIP → Service設定
- [[H1C6-NOING]](../README.ja.md#H1C6-NOING) ingress なし → Ingress作成しない
- [[B7X5-NONP]](../README.ja.md#B7X5-NONP) NetworkPolicy なし → NetworkPolicy作成しない

### リリース形態
- [[W5I2-HELM]](../README.ja.md#W5I2-HELM) Helmチャート → Helmチャート形式
- [[U9A4-TEST]](../README.ja.md#U9A4-TEST) 要件確認テスト → helm test実装