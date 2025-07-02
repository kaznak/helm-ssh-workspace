#!/bin/bash
set -e

# エラーハンドリング
trap 'echo "Error: SSH workspace initialization failed" >&2; exit 1' ERR

echo "Starting SSH Workspace initialization..."

# 環境変数の確認
if [ -z "$SSH_USER" ]; then
    echo "Error: SSH_USER environment variable is required" >&2
    exit 1
fi

if [ -z "$SSH_USER_UID" ]; then
    SSH_USER_UID=1000
fi

if [ -z "$SSH_USER_GID" ]; then
    SSH_USER_GID=1000
fi

if [ -z "$SSH_USER_SHELL" ]; then
    SSH_USER_SHELL="/bin/bash"
fi

echo "Configuring user: $SSH_USER (UID: $SSH_USER_UID, GID: $SSH_USER_GID)"

# グループ作成（存在しない場合）
if ! getent group "$SSH_USER_GID" >/dev/null 2>&1; then
    groupadd -g "$SSH_USER_GID" "$SSH_USER"
fi

# ユーザー作成（存在しない場合）
if ! id "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -u "$SSH_USER_UID" -g "$SSH_USER_GID" -s "$SSH_USER_SHELL" "$SSH_USER"
fi

# ホームディレクトリの確認と作成
USER_HOME=$(getent passwd "$SSH_USER" | cut -d: -f6)
if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
    chown "$SSH_USER_UID:$SSH_USER_GID" "$USER_HOME"
fi

# SSH ディレクトリの設定
SSH_DIR="$USER_HOME/.ssh"
mkdir -p "$SSH_DIR"
chown "$SSH_USER_UID:$SSH_USER_GID" "$SSH_DIR"
chmod 700 "$SSH_DIR"

# SSH 公開鍵の設定
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
if [ -f "/etc/ssh-keys/authorized_keys" ]; then
    cp "/etc/ssh-keys/authorized_keys" "$AUTHORIZED_KEYS"
    chown "$SSH_USER_UID:$SSH_USER_GID" "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    echo "SSH public keys configured from mounted file"
else
    echo "Warning: No SSH public keys found at /etc/ssh-keys/authorized_keys"
    exit 1
fi

# sudo権限の設定
if [ "$SSH_USER_SUDO" = "true" ]; then
    echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SSH_USER"
    chmod 440 "/etc/sudoers.d/$SSH_USER"
    echo "Sudo privileges granted to $SSH_USER"
fi

# 追加グループへの所属
if [ -n "$SSH_USER_ADDITIONAL_GROUPS" ]; then
    IFS=',' read -ra GROUPS <<< "$SSH_USER_ADDITIONAL_GROUPS"
    for group in "${GROUPS[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            usermod -a -G "$group" "$SSH_USER"
            echo "Added $SSH_USER to group: $group"
        else
            echo "Warning: Group $group does not exist"
        fi
    done
fi

# タイムゾーン設定
if [ -n "$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    echo "Timezone set to: $TZ"
fi

# SSH ホストキーはHelm Chartで管理（Secret経由）
echo "SSH host keys are managed by Helm Chart via Secret"

# SSH設定の妥当性確認
echo "Validating SSH configuration..."
if ! /usr/sbin/sshd -t; then
    echo "Error: SSH configuration is invalid" >&2
    exit 1
fi

echo "SSH Workspace initialization completed successfully"
echo "Starting SSH daemon for user: $SSH_USER"

# SSH daemon の起動
exec "$@"