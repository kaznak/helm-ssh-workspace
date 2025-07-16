# helm-ssh-workspace

Dropbear SSH サーバを利用したセキュアな SSH ワークスペースを提供する Helm チャートおよび Docker イメージ。

## 特徴

- **非特権実行**: Kubernetes 上でユーザランドでの安全な運用
- **SSH 鍵認証**: パスワード認証を無効化したセキュアな接続
- **永続化対応**: ホームディレクトリとSSH鍵の永続化をサポート

## 背景

CLI 型の AI エージェントと共同開発を行うためには、シェルアクセスが必要である。SSH サーバとして OpenSSH が広く使われているが、Kubernetes 上での運用には以下の課題がある。

- sshd は特権プロセスとしての運用を前提として開発されており、ユーザランドでの運用が困難
- 特権システムコールを利用した権限管理機能が実装されており、これを活用するには特権が必要

よりシンプルな SSH サーバである Dropbear SSH を利用することで、Kubernetes 上での運用が容易になると期待される。

## クイックスタート

### 前提条件
- Kubernetes クラスタ
- Helm 3.x

### インストール

1. SSH鍵ペアを生成
```bash
ssh-keygen -t ed25519 -f ~/.ssh/workspace_key -N ""
```

2. OCI形式のHelmチャートをインストール
```bash
helm install my-workspace oci://ghcr.io/kaznak/charts/ssh-workspace \
  --version 0.7.7 \
  --set ssh.publicKeys.authorizedKeys="$(cat ~/.ssh/workspace_key.pub)"
```

3. SSH接続
```bash
kubectl port-forward service/my-workspace-ssh-workspace 2222:2222 &
ssh -i ~/.ssh/workspace_key -p 2222 developer@localhost
```

## 設定

### 主要パラメータ

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `ssh.publicKeys.authorizedKeys` | SSH公開鍵 | 必須 |
| `user.name` | ユーザ名 | `developer` |
| `persistence.enabled` | 永続化の有効化 | `false` |

### 設定例

```yaml
# values.yaml
ssh:
  publicKeys:
    authorizedKeys: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx... user@example.com"

user:
  name: developer
  uid: 1000
  gid: 1000

persistence:
  enabled: true
  storageClass: standard
  size: 10Gi
```

## ライセンス

MIT License

## コンテナツールの使用について

このSSHワークスペースには、Podman（Docker互換）が含まれています。

### <span id="U3K7-ROOTLESS">[U3K7-ROOTLESS]</span> Rootless Podman の制限

Podmanはrootlessモード（非特権ユーザ）で動作するため、以下の制限があります：

- **ユーザネームスペースが必要**: ホストでユーザネームスペースが有効化されている必要があります
- **共有マウントの制限**: 一部のマウント操作で警告が表示される場合があります

### ユーザネームスペース設定

#### Kubernetesクラスタでの設定

**一般的なKubernetes:**
```bash
# ノード上でユーザネームスペースを有効化
sysctl kernel.unprivileged_userns_clone=1
sysctl user.max_user_namespaces=15000
```

**Talos Linux:**
```yaml
# talos-config.yaml
machine:
  sysctls:
    kernel.unprivileged_userns_clone: "1"
    user.max_user_namespaces: "15000"
```

設定後、クラスタノードの再起動が必要です。

### トラブルシューティング

**エラー例:**
```
cannot clone: Operation not permitted
user namespaces are not enabled in /proc/sys/user/max_user_namespaces
```

**確認方法:**
```bash
# ユーザネームスペースの状態確認
cat /proc/sys/user/max_user_namespaces
# 0: 無効, >0: 有効
```

**回避策:**
- クラスタ管理者にユーザネームスペース有効化を依頼
- 代替手段としてKubernetes Job/Podでコンテナ操作を実行
- 開発環境では別のコンテナランタイムを使用

## 参考情報

- [Dropbear SSH](https://github.com/mkj/dropbear)
- [Dropbear SSH Documentation](https://matt.ucc.asn.au/dropbear/dropbear.html)
- [Podman Rootless Documentation](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode)
