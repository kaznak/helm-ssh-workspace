# 設計書

## 概要

README.ja.mdの要求・要件を満たすDropbear SSH ワークスペースHelmチャートの実装設計。

## 1. 全体アーキテクチャ

### コンポーネント構成

- **Dropbear SSH サーバ**: 非特権で動作するSSHサーバ - [[F01a]](../README.ja.md#f01a), [[S01a]](../README.ja.md#s01a)
- **開発環境**: Linux with linuxbrew + 開発ツール群 - [[F01b]](../README.ja.md#f01b), [[F01b1]](../README.ja.md#f01b1)
- **初期化コンテナ**: SSH鍵・ホストキー生成用 - [[S01c]](../README.ja.md#s01c), [[S01d]](../README.ja.md#s01d)
- **共有ストレージ**: ホームディレクトリ（emptyDir or PVC） - [[F01d]](../README.ja.md#f01d), [[F01d1]](../README.ja.md#f01d1)

### データフロー

1. SSH鍵認証 → Dropbear SSH → シェルアクセス - [[S01b]](../README.ja.md#s01b), [[F01a]](../README.ja.md#f01a)
2. ポートフォワーディング（localhost限定） - [[F01c]](../README.ja.md#f01c), [[F01c1]](../README.ja.md#f01c1)
3. 開発ツール via linuxbrew（ユーザランド） - [[F01b]](../README.ja.md#f01b), [[F01b1]](../README.ja.md#f01b1)

## 2. Docker イメージ設計

### ベースイメージ
Ubuntu/Debian（linuxbrew対応） - [[F01b1]](../README.ja.md#f01b1)

### コンテナ構成
- **非特権ユーザ**: values.yamlで設定可能（デフォルト: `developer`, uid=1000, gid=1000） - [[S01a]](../README.ja.md#s01a), [[F01a]](../README.ja.md#f01a), [[F01e]](../README.ja.md#f01e)
- **Dropbear SSH**: ユーザランドで動作、ポート2222 - [[N01a]](../README.ja.md#n01a), [[S01a]](../README.ja.md#s01a)
- **開発ツール**: linuxbrew経由でインストール - [[F01b]](../README.ja.md#f01b), [[F01b1]](../README.ja.md#f01b1)
- **エントリポイント**: SSH鍵設定 + Dropbear起動 - [[S01b]](../README.ja.md#s01b), [[S01c]](../README.ja.md#s01c)

### 必要パッケージ
- dropbear-bin - [[F01a]](../README.ja.md#f01a)
- linuxbrew依存関係 - [[F01b1]](../README.ja.md#f01b1)
- 基本開発ツール（git, curl, vim等） - [[F01b]](../README.ja.md#f01b)

## 3. Kubernetes リソース設計

### Deployment - [[K01a]](../README.ja.md#k01a)
- replicas: 1（固定） - [[O01c]](../README.ja.md#o01c), [[K01a]](../README.ja.md#k01a)
- securityContext: restricted policy準拠 - [[S01a]](../README.ja.md#s01a)
- containers:
  - main: Dropbear SSH + 開発環境 - [[F01a]](../README.ja.md#f01a), [[F01b]](../README.ja.md#f01b)
  - ports: 2222/tcp - [[N01a]](../README.ja.md#n01a)
  - volumeMounts: home directory - [[F01d]](../README.ja.md#f01d)
  - livenessProbe: SSH接続確認 - [[L01c]](../README.ja.md#l01c)
  - readinessProbe: SSH接続確認 - [[L01c]](../README.ja.md#l01c)

### Service - [[K01b]](../README.ja.md#k01b)
- type: ClusterIP（デフォルト） - [[N01b1]](../README.ja.md#n01b1), [[K01b]](../README.ja.md#k01b)
- port: 2222 - [[N01a]](../README.ja.md#n01a)
- targetPort: 2222 - [[N01a]](../README.ja.md#n01a)

### ConfigMap
- Dropbear設定ファイル - [[F01c]](../README.ja.md#f01c), [[F01c1]](../README.ja.md#f01c1)
- 初期化スクリプト - [[S01c]](../README.ja.md#s01c)

### Secret
- SSH認証鍵 - [[S01b]](../README.ja.md#s01b)
- ホストキー - [[S01c]](../README.ja.md#s01c), [[S01d]](../README.ja.md#s01d)

### PVC（オプション）
- ホームディレクトリ永続化用 - [[F01d]](../README.ja.md#f01d), [[F01d2]](../README.ja.md#f01d2), [[F01d3]](../README.ja.md#f01d3), [[F01d4]](../README.ja.md#f01d4)

## 4. values.yaml 設定項目設計

```yaml
# イメージ設定
image:
  repository: helm-ssh-workspace
  tag: latest
  pullPolicy: IfNotPresent

# ユーザ設定 - [F01e](../README.ja.md#f01e)
user:
  name: developer  # [F01e1](../README.ja.md#f01e1)
  uid: 1000  # [F01e2](../README.ja.md#f01e2)
  gid: 1000  # [F01e3](../README.ja.md#f01e3)

# SSH設定 - [N01a](../README.ja.md#n01a), [S01b](../README.ja.md#s01b)
ssh:
  port: 2222  # [N01a](../README.ja.md#n01a)
  authorizedKeys: []  # SSH公開鍵リスト - [S01b](../README.ja.md#s01b)

# サービス設定 - [N01b](../README.ja.md#n01b), [N01b1](../README.ja.md#n01b1)
service:
  type: ClusterIP  # [N01b1](../README.ja.md#n01b1)
  port: 2222  # [N01a](../README.ja.md#n01a)

# ストレージ設定 - [F01d](../README.ja.md#f01d)
storage:
  type: emptyDir  # emptyDir or persistentVolume - [F01d1](../README.ja.md#f01d1)
  persistentVolume:
    size: 10Gi
    storageClass: ""  # [F01d2](../README.ja.md#f01d2)
    subPath: ""  # [F01d4](../README.ja.md#f01d4)

# リソース制限 - [R01a](../README.ja.md#r01a)
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 100m
    memory: 256Mi

# セキュリティ設定 - [S01](../README.ja.md#s01)
security:
  hostKeysPersistent: true  # [S01d](../README.ja.md#s01d)
  
# ヘルスチェック設定 - [L01c](../README.ja.md#l01c)
healthcheck:
  livenessProbe:
    enabled: true
  readinessProbe:
    enabled: true
```

## 5. セキュリティ実装方針

### Pod Security Standards - [[S01a]](../README.ja.md#s01a)
- runAsNonRoot: true - [[S01a]](../README.ja.md#s01a)
- runAsUser: 1000 - [[S01a]](../README.ja.md#s01a)
- allowPrivilegeEscalation: false - [[S01a]](../README.ja.md#s01a)
- seccompProfile: RuntimeDefault - [[S01a]](../README.ja.md#s01a)
- capabilities: drop ALL - [[S01a]](../README.ja.md#s01a)

### SSH認証 - [[S01b]](../README.ja.md#s01b)
- パスワード認証無効 - [[S01b]](../README.ja.md#s01b)
- 公開鍵認証のみ - [[S01b]](../README.ja.md#s01b)
- authorized_keys via ConfigMap/Secret - [[S01b]](../README.ja.md#s01b)

### 鍵管理 - [[S01c]](../README.ja.md#s01c), [[S01d]](../README.ja.md#s01d)
- ホストキー: 初期化時生成 - [[S01c]](../README.ja.md#s01c)
- PVC or Secret で永続化 - [[S01d]](../README.ja.md#s01d)
- release削除後も保持 - [[S01d]](../README.ja.md#s01d)

## 6. ログ・監視実装方針

### 構造化ログ - [[L01a]](../README.ja.md#l01a)
- JSON形式でログ出力 - [[L01a]](../README.ja.md#l01a)
- Dropbear設定でverbose logging - [[L01a]](../README.ja.md#l01a)
- 接続/切断イベント記録 - [[L01a]](../README.ja.md#l01a)

### メトリクス - [[L01b]](../README.ja.md#l01b)
- SSH接続数: netstat経由 - [[L01b]](../README.ja.md#l01b)
- リソース使用量: /proc/stat, /proc/meminfo - [[L01b]](../README.ja.md#l01b)
- カスタムメトリクス出力スクリプト - [[L01b]](../README.ja.md#l01b)

### ヘルスチェック - [[L01c]](../README.ja.md#l01c)
- livenessProbe: SSH接続テスト - [[L01c]](../README.ja.md#l01c)
- readinessProbe: SSH接続テスト - [[L01c]](../README.ja.md#l01c)
- 定期的なプローブ実行 - [[L01c]](../README.ja.md#l01c)

## 7. 実装優先度と段階

### Phase 1: 基本機能
- Dropbear SSH + 開発環境コンテナ - [[F01a]](../README.ja.md#f01a), [[F01b]](../README.ja.md#f01b)
- 基本的なDeployment/Service - [[K01a]](../README.ja.md#k01a), [[K01b]](../README.ja.md#k01b)
- emptyDir ストレージ - [[F01d1]](../README.ja.md#f01d1)

### Phase 2: 設定可能性
- values.yaml 設定項目実装 - [[N01a]](../README.ja.md#n01a), [[N01b1]](../README.ja.md#n01b1), [[F01d2]](../README.ja.md#f01d2)
- PVC対応 - [[F01d]](../README.ja.md#f01d), [[F01d3]](../README.ja.md#f01d3), [[F01d4]](../README.ja.md#f01d4)
- リソース制限 - [[R01a]](../README.ja.md#r01a)

### Phase 3: セキュリティ・監視
- Pod Security Standards準拠 - [[S01a]](../README.ja.md#s01a)
- ヘルスチェック実装 - [[L01c]](../README.ja.md#l01c)
- 構造化ログ対応 - [[L01a]](../README.ja.md#l01a), [[L01b]](../README.ja.md#l01b)

## 8. 要求・要件マッピング

### 機能要件
- [[F01a]](../README.ja.md#f01a) シングルユーザSSHアクセス → Dropbear SSH + 単一developerユーザ
- [[F01b]](../README.ja.md#f01b) 開発ツール提供 → linuxbrew + 基本ツール
- [[F01b1]](../README.ja.md#f01b1) linuxbrew利用 → 非特権ユーザでのlinuxbrew導入
- [[F01c]](../README.ja.md#f01c) SSHポートフォワーディング → Dropbear設定で有効化
- [[F01c1]](../README.ja.md#f01c1) localhost限定 → Dropbear設定で制限
- [[F01d]](../README.ja.md#f01d) ストレージ選択 → values.yaml設定
- [[F01d1]](../README.ja.md#f01d1) emptyDirデフォルト → デフォルト設定
- [[F01d2]](../README.ja.md#f01d2) StorageClass設定 → values.yaml設定
- [[F01d3]](../README.ja.md#f01d3) PVC永続化 → PVC作成・再利用
- [[F01d4]](../README.ja.md#f01d4) サブディレクトリマウント → PVC subPath設定
- [[F01e]](../README.ja.md#f01e) ユーザ設定 → values.yaml設定
- [[F01e1]](../README.ja.md#f01e1) ユーザ名設定 → values.yaml設定、デフォルトdeveloper
- [[F01e2]](../README.ja.md#f01e2) UID設定 → values.yaml設定、デフォルト1000
- [[F01e3]](../README.ja.md#f01e3) GID設定 → values.yaml設定、デフォルト1000

### リソース管理
- [[R01a]](../README.ja.md#r01a) リソース制限設定 → values.yaml resources設定

### ネットワーク・外部アクセス
- [[N01a]](../README.ja.md#n01a) SSH Port設定 → values.yaml設定、デフォルト2222
- [[N01b]](../README.ja.md#n01b) Service利用 → Service リソース作成
- [[N01b1]](../README.ja.md#n01b1) Service type設定 → values.yaml設定、デフォルトClusterIP
- [[N01c1]](../README.ja.md#n01c1) Ingressなし → Ingress リソース作成しない
- [[N01c2]](../README.ja.md#n01c2) NetworkPolicyなし → NetworkPolicy リソース作成しない

### ログ・監視
- [[L01a]](../README.ja.md#l01a) 構造化ログ → JSON形式ログ出力
- [[L01b]](../README.ja.md#l01b) 監視メトリクス → カスタムメトリクス出力
- [[L01c]](../README.ja.md#l01c) ヘルスチェック → liveness/readiness probe

### セキュリティ
- [[S01a]](../README.ja.md#s01a) restricted policy → securityContext設定
- [[S01b]](../README.ja.md#s01b) SSH鍵認証のみ → Dropbear設定
- [[S01c]](../README.ja.md#s01c) ホストキー生成 → 初期化時生成
- [[S01d]](../README.ja.md#s01d) ホストキー永続化 → PVC/Secret保存

### 運用
- [[O01a]](../README.ja.md#o01a) ダウンタイム許容 → 単一replica
- [[O01b]](../README.ja.md#o01b) 作成・削除運用 → Helmチャートでの管理
- [[O01c]](../README.ja.md#o01c) 自動スケーリング無効 → replica固定

### バックアップ・復旧
- [[B01a]](../README.ja.md#b01a) PVレイヤ機能 → チャート外で提供

### k8s デプロイ構成
- [[K01a]](../README.ja.md#k01a) deployment replicas=1 → Deployment設定
- [[K01b]](../README.ja.md#k01b) service ClusterIP → Service設定
- [[K01c]](../README.ja.md#k01c) ingress なし → Ingress作成しない
- [[K01d]](../README.ja.md#k01d) NetworkPolicy なし → NetworkPolicy作成しない

### リリース形態
- [[RL01a]](../README.ja.md#rl01a) Helmチャート → Helmチャート形式
- [[RL01b]](../README.ja.md#rl01b) 要件確認テスト → helm test実装