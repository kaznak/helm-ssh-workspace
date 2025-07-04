# SSH Workspace Docker Image

SSH経由でアクセス可能なワークスペース環境のDockerイメージです。

## 📁 ディレクトリ構造

```
docker/
├── Dockerfile              # メインイメージ定義
├── .dockerignore          # Docker build除外設定
├── README.md              # 英語ドキュメント
├── README.ja.md           # このファイル
├── config/                # 設定ファイル
│   └── sshd_config        # SSH設定
└── scripts/               # 実行スクリプト
    ├── entrypoint.sh      # メインコンテナ初期化
    └── init-container.sh  # Init Container設定（Kubernetes）
```

## 🚀 イメージのビルド

```bash
# プロジェクトルートから
cd docker
docker build -t ssh-workspace:latest .

# または、プロジェクトルートから
docker build -f docker/Dockerfile -t ssh-workspace:latest .
```

## ⚙️ 環境変数

| 変数名 | 必須 | デフォルト | 説明 |
|--------|------|-----------|------|
| `SSH_USER` | ✅ | - | SSHユーザー名 |
| `SSH_PUBLIC_KEYS` | ✅ | - | SSH公開鍵（改行区切り） |
| `SSH_USER_UID` | ❌ | 1000 | ユーザーUID |
| `SSH_USER_GID` | ❌ | 1000 | ユーザーGID |
| `SSH_USER_SHELL` | ❌ | /bin/bash | ログインシェル |
| `SSH_USER_SUDO` | ❌ | false | sudo権限 |
| `SSH_USER_ADDITIONAL_GROUPS` | ❌ | - | 追加グループ（カンマ区切り） |
| `TZ` | ❌ | UTC | タイムゾーン（例: Asia/Tokyo） |

**注意**: `ETC_TARGET_DIR`はKubernetes Init Containerで内部的に使用されます（`/etc-new`に固定）。

## 📂 オプションマウント

| パス | 用途 | 必須 | 代替手段 |
|------|------|------|----------|
| `/etc/ssh-keys/authorized_keys` | SSH公開鍵 | ❌ | `SSH_PUBLIC_KEYS`環境変数を使用 |
| `/home/{username}` | ホームディレクトリ | ❌ | 一時ストレージを使用 |

## 🔧 使用例

### 基本的な実行（推奨）

環境変数を使用する方法：

```bash
docker run -d \
  --name ssh-workspace \
  -p 2222:2222 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  ssh-workspace:latest

# SSH接続
ssh developer@localhost -p 2222
```

### 基本的な実行（ファイルマウント）

ファイルマウント方式：

```bash
# SSH公開鍵を準備
echo "ssh-ed25519 AAAAC3... user@example.com" > authorized_keys

# コンテナ実行
docker run -d \
  --name ssh-workspace \
  -p 2222:2222 \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace:latest
```

### 複数SSH鍵の設定

```bash
# 複数のSSH鍵（改行区切り）
docker run -d \
  -p 2222:2222 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user1@example.com
ssh-rsa AAAAB3... user2@example.com
ssh-ed25519 AAAAC3... user3@example.com" \
  ssh-workspace:latest
```

### 永続化ありの実行

```bash
# ホームディレクトリを永続化
docker volume create ssh-workspace-home

docker run -d \
  --name ssh-workspace \
  -p 2222:2222 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  -e SSH_USER_SUDO=true \
  -e TZ=Asia/Tokyo \
  -v ssh-workspace-home:/home/developer \
  ssh-workspace:latest
```

### タイムゾーン設定

```bash
# 利用可能なタイムゾーン確認
docker run --rm ssh-workspace:latest timedatectl list-timezones | head -20

# 日本時間で実行
docker run -d \
  -e TZ=Asia/Tokyo \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace:latest

# アメリカ東部時間で実行
docker run -d \
  -e TZ=America/New_York \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace:latest
```

## 🔒 セキュリティ機能

- SSH公開鍵認証のみ（パスワード認証無効）
- SSHポート2222（非特権ポート）
- 権限分離プロセス使用
- 最小限の権限で実行
- SSHホストキーはKubernetes Secret経由で提供（イメージに含まない）

## 🛠️ 開発者向け

### スクリプトの修正

1. `scripts/` ディレクトリのスクリプトを編集
2. イメージを再ビルド
3. テスト実行

### 設定の変更

1. `config/sshd_config` を編集
2. イメージを再ビルド
3. 設定確認: `docker exec container-name /usr/sbin/sshd -T`

## 🐞 トラブルシューティング

### よくある問題

1. **権限エラー**
   ```bash
   # authorized_keysの権限確認
   docker exec container-name ls -la /etc/ssh-keys/
   ```

2. **SSH接続失敗**
   ```bash
   # ログ確認
   docker logs container-name
   
   # SSH設定確認
   docker exec container-name /usr/sbin/sshd -T
   ```

3. **ユーザー作成失敗**
   ```bash
   # 環境変数確認
   docker exec container-name env | grep SSH_USER
   ```