# SSH Workspace - 使用方法ガイド

SSH WorkspaceはKubernetes上で動作するSSHアクセス可能な開発環境です。

## 🚀 クイックスタート

### 1. 基本的なデプロイ

```bash
# SSH公開鍵を準備（必須）
export SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@example.com"

# 基本的なデプロイ
helm install my-workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="$SSH_PUBLIC_KEY"
```

### 2. 接続方法

```bash
# ポートフォワードでアクセス（ClusterIP使用時）
kubectl port-forward svc/my-workspace-ssh-workspace 2222:22

# SSH接続
ssh developer@localhost -p 2222
```

## 📋 詳細設定

### ユーザー設定

```yaml
user:
  name: "myuser"          # 必須: ユーザー名
  uid: 1001               # オプション: UID
  gid: 1001               # オプション: GID
  shell: /bin/bash        # ログインシェル
  sudo: true              # sudo権限
  additionalGroups:       # 追加グループ
    - docker
    - wheel
```

### タイムゾーン設定

```yaml
timezone: "Asia/Tokyo"    # タイムゾーン設定
```

#### 利用可能なタイムゾーン一覧
```bash
# コンテナ内で確認
kubectl exec deployment/workspace-ssh-workspace -- timedatectl list-timezones

# 主要なタイムゾーン例
# UTC, GMT                    # 協定世界時
# Asia/Tokyo                  # 日本標準時 (JST)
# America/New_York            # アメリカ東部標準時
# America/Los_Angeles         # アメリカ太平洋標準時
# Europe/London               # イギリス
# Europe/Paris                # フランス・ドイツ・中欧
# Asia/Shanghai               # 中国標準時
# Asia/Seoul                  # 韓国標準時
```

### SSH設定

```yaml
ssh:
  publicKeys:             # 必須: SSH公開鍵リスト
    - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user1@example.com"
    - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... user2@example.com"
  port: 22               # SSHポート
  config:                # 追加SSH設定
    MaxAuthTries: "3"
    LoginGraceTime: "30"
```

### 永続化設定

```yaml
persistence:
  enabled: true           # 永続化有効
  size: 50Gi             # ストレージサイズ
  storageClass: "ssd"    # ストレージクラス
  accessModes:
    - ReadWriteOnce
```

### セキュリティレベル

```yaml
security:
  level: standard         # basic | standard | high
  # basic:    開発・テスト用（最小限制限）
  # standard: 推奨設定（readOnlyRootFilesystem有効）
  # high:     本番環境用（seccomp + 厳格設定）
```

## 🌐 外部アクセス設定

### NodePort使用

```yaml
service:
  type: NodePort
  port: 22
  nodePort: 30022        # オプション: 固定NodePort
```

### LoadBalancer使用

```yaml
service:
  type: LoadBalancer
  port: 22
```

### Ingress使用（TCP）

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/tcp-services-configmap: "default/tcp-services"
  hosts:
    - host: ssh.example.com
      paths:
        - path: /
          pathType: Prefix
```

## 📊 監視設定

```yaml
monitoring:
  enabled: true           # ssh_exporter有効
  port: 9312             # メトリクスポート
  serviceMonitor:
    enabled: true         # Prometheus ServiceMonitor
    interval: 30s         # スクレイプ間隔
```

## 🛠️ 管理コマンド

### デプロイメント管理

```bash
# インストール
helm install workspace ./ssh-workspace -f values.yaml

# アップグレード
helm upgrade workspace ./ssh-workspace -f values.yaml

# アンインストール（データ保持）
helm uninstall workspace

# 完全削除（データも削除）
helm uninstall workspace
kubectl delete pvc workspace-ssh-workspace-home
kubectl delete configmap workspace-ssh-workspace-ssh-keys
kubectl delete secret workspace-ssh-workspace-host-keys
```

### 状態確認

```bash
# 全リソース確認
kubectl get all -l app.kubernetes.io/instance=workspace

# ログ確認
kubectl logs -l app.kubernetes.io/instance=workspace -f

# テスト実行
helm test workspace
```

### デバッグ

```bash
# Pod内に入る（トラブルシューティング）
kubectl exec -it deployment/workspace-ssh-workspace -- /bin/bash

# SSH設定確認
kubectl exec -it deployment/workspace-ssh-workspace -- /usr/sbin/sshd -T

# 公開鍵確認
kubectl get configmap workspace-ssh-workspace-ssh-keys -o yaml
```

## 🔧 トラブルシューティング

### よくある問題

1. **接続拒否される**
   ```bash
   # Pod状態確認
   kubectl get pods -l app.kubernetes.io/instance=workspace
   
   # ログ確認
   kubectl logs -l app.kubernetes.io/instance=workspace --tail=50
   ```

2. **認証失敗**
   ```bash
   # 公開鍵設定確認
   kubectl get configmap workspace-ssh-workspace-ssh-keys -o yaml
   
   # SSH接続テスト（詳細ログ）
   ssh -vvv user@host -p port
   ```

3. **Pod起動失敗**
   ```bash
   # イベント確認
   kubectl describe pod -l app.kubernetes.io/instance=workspace
   
   # 設定値検証
   helm template workspace ./ssh-workspace -f values.yaml --debug
   ```

## 📝 設定例

### 開発環境

```yaml
user:
  name: "developer"
  sudo: true
ssh:
  publicKeys:
    - "ssh-ed25519 AAAAC3... dev@localhost"
security:
  level: basic
monitoring:
  enabled: true
```

### 本番環境

```yaml
user:
  name: "prod-user"
  uid: 2000
  gid: 2000
  sudo: false
ssh:
  publicKeys:
    - "ssh-ed25519 AAAAC3... user@company.com"
persistence:
  enabled: true
  size: 100Gi
  storageClass: "premium-ssd"
security:
  level: high
service:
  type: LoadBalancer
resources:
  limits:
    cpu: 2
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## 🔒 セキュリティベストプラクティス

1. **常に最新のセキュリティレベルを使用**
   ```yaml
   security:
     level: high  # 本番環境では必須
   ```

2. **強力なSSH鍵を使用**
   ```bash
   # ED25519鍵生成（推奨）
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

3. **永続化を有効にして定期バックアップ**
   ```yaml
   persistence:
     enabled: true
   ```

4. **リソース制限の設定**
   ```yaml
   resources:
     limits:
       cpu: 1
       memory: 2Gi
   ```

5. **監視の有効化**
   ```yaml
   monitoring:
     enabled: true
   ```

## 📞 サポート

- 問題報告: [GitHub Issues](https://github.com/example/ssh-workspace/issues)
- ドキュメント: [Wiki](https://github.com/example/ssh-workspace/wiki)
- FAQ: [Troubleshooting Guide](https://github.com/example/ssh-workspace/docs/faq.md)