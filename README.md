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
  --version 0.7.6 \
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

## 参考情報

- [Dropbear SSH](https://github.com/mkj/dropbear)
- [Dropbear SSH Documentation](https://matt.ucc.asn.au/dropbear/dropbear.html)
