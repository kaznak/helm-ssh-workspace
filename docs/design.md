# 設計書

## 概要

README.ja.mdの要求・要件を満たすDropbear SSH ワークスペースHelmチャートの実装設計。

## 1. 全体アーキテクチャ

### コンポーネント構成

- **Dropbear SSH サーバ**: 非特権で動作するSSHサーバ
- **開発環境**: Linux with linuxbrew + 開発ツール群
- **初期化コンテナ**: SSH鍵・ホストキー生成用
- **共有ストレージ**: ホームディレクトリ（emptyDir or PVC）

### データフロー

1. SSH鍵認証 → Dropbear SSH → シェルアクセス
2. ポートフォワーディング（localhost限定）
3. 開発ツール via linuxbrew（ユーザランド）

## 2. Docker イメージ設計

### ベースイメージ
Ubuntu/Debian（linuxbrew対応）

### コンテナ構成
- **非特権ユーザ**: `developer` (uid=1000)
- **Dropbear SSH**: ユーザランドで動作、ポート2222
- **開発ツール**: linuxbrew経由でインストール
- **エントリポイント**: SSH鍵設定 + Dropbear起動

### 必要パッケージ
- dropbear-bin
- linuxbrew依存関係
- 基本開発ツール（git, curl, vim等）

## 3. Kubernetes リソース設計

### Deployment (K01a)
- replicas: 1（固定）
- securityContext: restricted policy準拠
- containers:
  - main: Dropbear SSH + 開発環境
  - ports: 2222/tcp
  - volumeMounts: home directory
  - livenessProbe: SSH接続確認
  - readinessProbe: SSH接続確認

### Service (K01b)
- type: ClusterIP（デフォルト）
- port: 2222
- targetPort: 2222

### ConfigMap
- Dropbear設定ファイル
- 初期化スクリプト

### Secret
- SSH認証鍵
- ホストキー

### PVC（オプション）
- ホームディレクトリ永続化用

## 4. values.yaml 設定項目設計

```yaml
# イメージ設定
image:
  repository: helm-ssh-workspace
  tag: latest
  pullPolicy: IfNotPresent

# SSH設定 (N01a)
ssh:
  port: 2222
  authorizedKeys: []  # SSH公開鍵リスト

# サービス設定 (N01b, N01b1)
service:
  type: ClusterIP
  port: 2222

# ストレージ設定 (F01d)
storage:
  type: emptyDir  # emptyDir or persistentVolume
  persistentVolume:
    size: 10Gi
    storageClass: ""
    subPath: ""

# リソース制限 (R01a)
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 100m
    memory: 256Mi

# セキュリティ設定 (S01)
security:
  hostKeysPersistent: true
  
# ヘルスチェック設定 (L01c)
healthcheck:
  livenessProbe:
    enabled: true
  readinessProbe:
    enabled: true
```

## 5. セキュリティ実装方針

### Pod Security Standards (S01a)
- runAsNonRoot: true
- runAsUser: 1000
- allowPrivilegeEscalation: false
- seccompProfile: RuntimeDefault
- capabilities: drop ALL

### SSH認証 (S01b)
- パスワード認証無効
- 公開鍵認証のみ
- authorized_keys via ConfigMap/Secret

### 鍵管理 (S01c, S01d)
- ホストキー: 初期化時生成
- PVC or Secret で永続化
- release削除後も保持

## 6. ログ・監視実装方針

### 構造化ログ (L01a)
- JSON形式でログ出力
- Dropbear設定でverbose logging
- 接続/切断イベント記録

### メトリクス (L01b)
- SSH接続数: netstat経由
- リソース使用量: /proc/stat, /proc/meminfo
- カスタムメトリクス出力スクリプト

### ヘルスチェック (L01c)
- livenessProbe: SSH接続テスト
- readinessProbe: SSH接続テスト
- 定期的なプローブ実行

## 7. 実装優先度と段階

### Phase 1: 基本機能
- Dropbear SSH + 開発環境コンテナ
- 基本的なDeployment/Service
- emptyDir ストレージ

### Phase 2: 設定可能性
- values.yaml 設定項目実装
- PVC対応
- リソース制限

### Phase 3: セキュリティ・監視
- Pod Security Standards準拠
- ヘルスチェック実装
- 構造化ログ対応

## 8. 要求・要件マッピング

### 機能要件
- [F01a] シングルユーザSSHアクセス → Dropbear SSH + 単一developerユーザ
- [F01b] 開発ツール提供 → linuxbrew + 基本ツール
- [F01b1] linuxbrew利用 → 非特権ユーザでのlinuxbrew導入
- [F01c] SSHポートフォワーディング → Dropbear設定で有効化
- [F01c1] localhost限定 → Dropbear設定で制限
- [F01d] ストレージ選択 → values.yaml設定
- [F01d1] emptyDirデフォルト → デフォルト設定
- [F01d2] StorageClass設定 → values.yaml設定
- [F01d3] PVC永続化 → PVC作成・再利用
- [F01d4] サブディレクトリマウント → PVC subPath設定

### リソース管理
- [R01a] リソース制限設定 → values.yaml resources設定

### ネットワーク・外部アクセス
- [N01a] SSH Port設定 → values.yaml設定、デフォルト2222
- [N01b] Service利用 → Service リソース作成
- [N01b1] Service type設定 → values.yaml設定、デフォルトClusterIP
- [N01c1] Ingressなし → Ingress リソース作成しない
- [N01c2] NetworkPolicyなし → NetworkPolicy リソース作成しない

### ログ・監視
- [L01a] 構造化ログ → JSON形式ログ出力
- [L01b] 監視メトリクス → カスタムメトリクス出力
- [L01c] ヘルスチェック → liveness/readiness probe

### セキュリティ
- [S01a] restricted policy → securityContext設定
- [S01b] SSH鍵認証のみ → Dropbear設定
- [S01c] ホストキー生成 → 初期化時生成
- [S01d] ホストキー永続化 → PVC/Secret保存

### 運用
- [O01a] ダウンタイム許容 → 単一replica
- [O01b] 作成・削除運用 → Helmチャートでの管理
- [O01c] 自動スケーリング無効 → replica固定

### バックアップ・復旧
- [B01a] PVレイヤ機能 → チャート外で提供

### k8s デプロイ構成
- [K01a] deployment replicas=1 → Deployment設定
- [K01b] service ClusterIP → Service設定
- [K01c] ingress なし → Ingress作成しない
- [K01d] NetworkPolicy なし → NetworkPolicy作成しない

### リリース形態
- [RL01a] Helmチャート → Helmチャート形式
- [RL01b] 要件確認テスト → helm test実装