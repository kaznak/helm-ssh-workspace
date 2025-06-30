# SSH Workspace Helm Chart

Kubernetes上でSSHアクセス可能なワークスペース環境をデプロイするためのHelm Chartです。

## 📁 ディレクトリ構造

```
helm/
├── ssh-workspace/          # Helm Chart
│   ├── Chart.yaml         # Chart基本情報
│   ├── values.yaml        # デフォルト設定値
│   ├── values.schema.json # 設定値検証スキーマ
│   ├── .helmignore        # パッケージ除外設定
│   └── templates/         # Kubernetesテンプレート
│       ├── _helpers.tpl   # 共通ヘルパー関数
│       ├── configmap.yaml # SSH公開鍵設定
│       ├── secret.yaml    # SSHホストキー
│       ├── deployment.yaml # メインワークロード
│       ├── service.yaml   # ネットワークアクセス
│       ├── pvc.yaml       # 永続化ストレージ
│       ├── ingress.yaml   # 外部アクセス
│       ├── servicemonitor.yaml # 監視設定
│       ├── poddisruptionbudget.yaml # 可用性保証
│       ├── pre-install-hook.yaml   # インストール前検証
│       ├── post-install-hook.yaml  # インストール後確認
│       ├── NOTES.txt      # デプロイ後案内
│       └── tests/         # Helmテスト
│           ├── ssh-connection-test.yaml
│           └── resource-validation-test.yaml
├── example-values.yaml    # 設定例集
└── README.md             # このファイル
```

## 🚀 クイックスタート

### 必須パラメータの設定

```bash
# SSH公開鍵を準備
export SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@example.com"

# 基本的なデプロイ
helm install my-workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="$SSH_PUBLIC_KEY"
```

### アクセス方法

```bash
# ポートフォワード（ClusterIP使用時）
kubectl port-forward svc/my-workspace-ssh-workspace 2222:22

# SSH接続
ssh developer@localhost -p 2222
```

## ⚙️ 主要設定

### 必須設定

```yaml
user:
  name: "username"          # 必須: ユーザー名
ssh:
  publicKeys:               # 必須: SSH公開鍵（配列）
    - "ssh-ed25519 AAAAC3..."
```

### よく使用される設定

```yaml
# 永続化
persistence:
  enabled: true
  size: 20Gi

# sudo権限
user:
  sudo: true

# 外部アクセス
service:
  type: LoadBalancer

# 監視
monitoring:
  enabled: true

# セキュリティレベル
security:
  level: high  # basic/standard/high
```

## 📊 管理コマンド

### インストール・更新

```bash
# インストール
helm install workspace ./ssh-workspace -f values.yaml

# 設定確認
helm template workspace ./ssh-workspace -f values.yaml

# アップグレード
helm upgrade workspace ./ssh-workspace -f values.yaml

# アンインストール
helm uninstall workspace
```

### 監視・デバッグ

```bash
# 状態確認
kubectl get all -l app.kubernetes.io/instance=workspace

# ログ確認
kubectl logs -l app.kubernetes.io/instance=workspace -f

# Helmテスト実行
helm test workspace

# Pod内アクセス（デバッグ用）
kubectl exec -it deployment/workspace-ssh-workspace -- /bin/bash
```

## 🔧 カスタマイズ

### values.yamlの作成

```yaml
# myvalues.yaml
user:
  name: "myuser"
  sudo: true
  additionalGroups:
    - docker

ssh:
  publicKeys:
    - "ssh-ed25519 AAAAC3... user@company.com"

persistence:
  enabled: true
  size: 50Gi
  storageClass: "fast-ssd"

security:
  level: high

service:
  type: LoadBalancer

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true

resources:
  limits:
    cpu: 2
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

### Helm Hooks

| Hook | タイミング | 用途 |
|------|-----------|------|
| pre-install | インストール前 | SSH公開鍵・設定値検証 |
| post-install | インストール後 | 初期化完了確認 |
| test | テスト実行時 | SSH接続・リソース検証 |

## 🔒 セキュリティ機能

### セキュリティレベル

| レベル | 用途 | 特徴 |
|--------|------|------|
| basic | 開発・テスト | 最小限制限 |
| standard | 推奨 | readOnlyRootFilesystem有効 |
| high | 本番環境 | seccomp RuntimeDefault + 厳格SSH設定 |

### セキュリティ機能

- 公開鍵認証のみ（パスワード認証無効）
- Pod Security Context適用
- Capabilities制限
- ネットワークポリシー対応（外部設定）
- リソース分離（emptyDir, PVC）

## 🌐 ネットワークアクセス

### Service Type別アクセス方法

| Type | アクセス方法 | 用途 |
|------|-------------|------|
| ClusterIP | port-forward | 開発・テスト |
| NodePort | NodeIP:NodePort | 内部ネットワーク |
| LoadBalancer | 外部IP:Port | 本番環境 |

### Ingress対応

TCP Ingress Controllerが必要：
- NGINX Ingress Controller
- HAProxy Ingress Controller
- Traefik

## 📈 監視・メトリクス

### 対応メトリクス

- SSH接続数
- レスポンス時間
- 認証失敗数
- リソース使用量（CPU・メモリ・ストレージ）

### Prometheus連携

```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

## 🔄 アップグレード・移行

### アップグレード戦略

- **Recreate**: ダウンタイムあり（デフォルト）
- データ保護: `helm.sh/resource-policy: keep`

### データ保護対象

- PersistentVolumeClaim
- ConfigMap（SSH公開鍵）
- Secret（SSHホストキー）

## 🆘 トラブルシューティング

詳細は [../USAGE.md](../USAGE.md) を参照してください。

### よくある問題

1. **SSH公開鍵が無効**
   ```bash
   helm template workspace ./ssh-workspace --debug
   ```

2. **Pod起動失敗**
   ```bash
   kubectl describe pod -l app.kubernetes.io/instance=workspace
   ```

3. **接続失敗**
   ```bash
   kubectl logs -l app.kubernetes.io/instance=workspace
   ```

## 🧪 テスト

```bash
# 全テスト実行
helm test workspace

# 個別テスト実行
kubectl apply -f templates/tests/ssh-connection-test.yaml
```

## 📝 カスタムChart作成

このChartをベースにカスタマイズ：

1. `Chart.yaml` の名前・バージョン変更
2. `values.yaml` のデフォルト値調整
3. `templates/` のリソース追加・変更
4. `values.schema.json` の検証ルール更新