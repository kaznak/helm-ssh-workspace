#!/bin/bash
set -e

# エラーハンドリング
trap 'echo "Error: SSH workspace initialization failed" >&2; exit 1' ERR

echo "Starting SSH Workspace (Main Container)..."
echo "User setup and SSH configuration completed by Init Container"

# タイムゾーン設定
if [ -n "$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    echo "Timezone set to: $TZ"
fi

# SSH ホストキー確認（必須）
if [ -f "/etc/ssh/ssh_host_rsa_key" ] || [ -f "/etc/ssh/ssh_host_ecdsa_key" ] || [ -f "/etc/ssh/ssh_host_ed25519_key" ]; then
    echo "✓ SSH host keys available"
else
    echo "Error: SSH host keys not found - required for SSH daemon startup" >&2
    echo "Expected keys in /etc/ssh/: ssh_host_rsa_key, ssh_host_ecdsa_key, or ssh_host_ed25519_key" >&2
    exit 1
fi

# SSH設定の検証（必須）
echo "Validating SSH configuration..."
if /usr/sbin/sshd -t; then
    echo "✓ SSH configuration is valid"
else
    echo "Error: SSH configuration validation failed" >&2
    exit 1
fi

# SSH_USER 確認（必須）
if [ -z "$SSH_USER" ]; then
    echo "Error: SSH_USER environment variable is required" >&2
    exit 1
fi

echo "SSH Workspace initialization completed successfully"
echo "Starting SSH daemon for user: $SSH_USER"

# SSH daemon の起動
exec "$@"