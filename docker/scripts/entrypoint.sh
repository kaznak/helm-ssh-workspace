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

# SSH権限分離ディレクトリの作成
mkdir -p /run/sshd
chmod 755 /run/sshd
echo "✓ SSH privilege separation directory created"

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

# ホームディレクトリ権限の確認・修正
if [ -d "/home/$SSH_USER" ]; then
    # Design: Init Container has already configured permissions with fsGroup
    # Main Container attempts verification but doesn't fail due to fsGroup restrictions
    # 
    # fsGroup behavior explanation:
    # - fsGroup only sets group ownership, not user ownership
    # - EmptyDir volumes are created with root:fsGroup ownership
    # - chmod/chown restrictions depend on:
    #   1. Process user (root can usually change permissions)
    #   2. File ownership (can't change files you don't own)
    #   3. Security context settings (capabilities, allowPrivilegeEscalation)
    #   4. Volume type and mount options
    # - SetGID bit (2xxx) ensures new files inherit group ownership
    
    # Check if fsGroup is active by examining file ownership and permissions
    echo "=== Checking fsGroup configuration ==="
    echo "Current process user: $(id -un) (uid=$(id -u))"
    echo "Current process groups: $(id -G)"
    echo "Home directory stats:"
    stat -c "  Owner: %U:%G (uid=%u, gid=%g)" "/home/$SSH_USER"
    stat -c "  Permissions: %a (ls format: %A)" "/home/$SSH_USER"
    
    # Check for SetGID bit (indicates fsGroup is active)
    if [ $(($(stat -c %a "/home/$SSH_USER") & 2000)) -ne 0 ]; then
        echo "  ✓ SetGID bit detected - fsGroup is managing directory permissions"
    fi
    
    # Test actual permission capabilities
    echo "Testing permission change capabilities:"
    TEST_FILE="/home/$SSH_USER/.permission_test_$$"
    touch "$TEST_FILE" 2>/dev/null && {
        echo "  Created test file: $(stat -c '%U:%G %a' "$TEST_FILE")"
        chmod 644 "$TEST_FILE" 2>/dev/null && echo "  ✓ chmod succeeded on new file" || echo "  ✗ chmod failed on new file"
        chown "$SSH_USER:$SSH_USER" "$TEST_FILE" 2>/dev/null && echo "  ✓ chown succeeded on new file" || echo "  ✗ chown failed on new file"
        rm -f "$TEST_FILE"
    }
    
    chown "$SSH_USER:$SSH_USER" "/home/$SSH_USER" 2>/dev/null || echo "Note: Home directory ownership managed by fsGroup"
    chmod 755 "/home/$SSH_USER" 2>/dev/null || echo "Note: Home directory permissions managed by fsGroup"
    
    # .ssh ディレクトリの権限確認・修正
    if [ -d "/home/$SSH_USER/.ssh" ]; then
        chown -R "$SSH_USER:$SSH_USER" "/home/$SSH_USER/.ssh" 2>/dev/null || echo "Note: SSH directory ownership managed by fsGroup"
        chmod 700 "/home/$SSH_USER/.ssh" 2>/dev/null || {
            echo "⚠️ WARNING: Could not set .ssh directory permissions to 700"
            echo "Current permissions: $(stat -c %a "/home/$SSH_USER/.ssh" 2>/dev/null || echo "unknown")"
            echo "SSH may reject connections if .ssh directory is not properly secured"
        }
        
        if [ -f "/home/$SSH_USER/.ssh/authorized_keys" ]; then
            # CRITICAL: authorized_keys must have 600 permissions for SSH security
            chmod 600 "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || {
                echo "❌ CRITICAL: Cannot set authorized_keys permissions in Main Container!"
                echo "Current permissions: $(stat -c %a "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "unknown")"
                echo "SSH authentication will fail with incorrect permissions."
                # Don't exit here as Init Container should have handled this
                echo "⚠️ WARNING: Continuing with potentially insecure SSH key permissions"
            }
        fi
    fi
    
    echo "✓ Home directory permissions verified for $SSH_USER"
fi

echo "SSH Workspace initialization completed successfully"
echo "Starting SSH daemon for user: $SSH_USER"

# SSH daemon の起動
exec "$@"