#!/bin/bash
set -e

# Init Container script for SSH Workspace
# This script sets up user, SSH configuration, and system files

# =============================================================================
# SSH_WORKSPACE_DEBUG_CHMOD_FAILURES Environment Variable
# =============================================================================
# 
# **Purpose**: Enable diagnostic mode for chmod operation failures
# 
# **Background**: 
# During development and troubleshooting of Kubernetes permission issues,
# it's sometimes necessary to continue container initialization even when
# chmod operations fail, to allow SSH connectivity tests to proceed and
# gather diagnostic information.
# 
# **Normal Behavior (Default)**:
# - chmod failures on security-critical files (like authorized_keys) cause
#   immediate script termination with exit code 1
# - This ensures security requirements are strictly enforced
# 
# **Debug Mode Behavior**:
# - chmod failures are logged and marked for detection by test validation
# - Script continues execution to allow SSH connectivity testing
# - Test validation will ultimately fail the deployment if chmod failed
# 
# **Usage**:
# Set SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true in container environment:
# 
# Example in Helm values.yaml:
# ```yaml
# deployment:
#   env:
#     SSH_WORKSPACE_DEBUG_CHMOD_FAILURES: "true"
# ```
# 
# Example in kubectl:
# ```bash
# kubectl set env deployment/ssh-workspace SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true
# ```
# 
# **Security Warning**: 
# This debug mode should NEVER be used in production environments as it
# allows containers to start with potentially insecure file permissions.
# Only use during development and troubleshooting.
# 
# **Related Files**:
# - docker/scripts/entrypoint.sh: Detects chmod failures from init container
# - helm/ssh-workspace/templates/tests/permission-validation-test.yaml: 
#   Final validation that fails deployment if chmod failed
# 
# =============================================================================

echo "Starting SSH Workspace initialization (Init Container)..."

# Check required environment variables
if [ -z "$SSH_USER" ]; then
    echo "Error: SSH_USER is not set" >&2
    exit 1
fi

# Default values
SSH_USER_UID="${SSH_USER_UID:-1000}"
SSH_USER_GID="${SSH_USER_GID:-1000}"
SSH_USER_SHELL="${SSH_USER_SHELL:-/bin/bash}"
SSH_USER_SUDO="${SSH_USER_SUDO:-false}"
ETC_TARGET_DIR="${ETC_TARGET_DIR:-/etc-new}"

echo "Creating user: $SSH_USER (uid=$SSH_USER_UID, gid=$SSH_USER_GID)"

# Create group and user
groupadd -g "$SSH_USER_GID" "$SSH_USER" 2>/dev/null || true

# Create user without home directory first, then handle home directory separately
useradd -u "$SSH_USER_UID" -g "$SSH_USER_GID" -s "$SSH_USER_SHELL" -M "$SSH_USER" 2>/dev/null || true

# Ensure home directory exists and has correct ownership
# (This handles both empty and pre-existing volumes)
mkdir -p "/home/$SSH_USER"
chown "$SSH_USER:$SSH_USER" "/home/$SSH_USER"
chmod 755 "/home/$SSH_USER"  # Remove SetGID bit and set proper permissions
echo "✓ Home directory prepared for $SSH_USER"

# Handle additional groups
if [ -n "$SSH_USER_ADDITIONAL_GROUPS" ]; then
    IFS=',' read -ra GROUPS <<< "$SSH_USER_ADDITIONAL_GROUPS"
    for group in "${GROUPS[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace
        if getent group "$group" >/dev/null 2>&1; then
            usermod -aG "$group" "$SSH_USER"
            echo "✓ Added $SSH_USER to group: $group"
        else
            echo "Warning: Group '$group' does not exist" >&2
        fi
    done
fi

# Generate or copy SSH host keys directly to /etc/ssh
echo "Setting up SSH host keys..."

if [ -f "/etc/ssh-host-keys/ssh_host_rsa_key" ]; then
    # Use SSH host keys from Secret (mounted with correct permissions)
    # Create symbolic links to maintain file permissions set by Kubernetes
    echo "Linking SSH host keys from Secret (preserving mount permissions)..."
    for key_file in /etc/ssh-host-keys/ssh_host_*; do
        if [ -f "$key_file" ]; then
            key_name=$(basename "$key_file")
            ln -sf "$key_file" "/etc/ssh/$key_name"
            echo "  ✓ Linked $key_name"
        fi
    done
    echo "✓ SSH host keys linked from Secret (no copying required)"
else
    # Generate SSH host keys directly in /etc/ssh (always needed since image has them removed)
    echo "Generating new SSH host keys..."
    ssh-keygen -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N ""
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ""
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
    echo "✓ Generated new SSH host keys"
fi

# Copy system files including SSH host keys to writable location (for readOnlyRootFilesystem)
# This prepared configuration will be mounted as read-only in the Main Container
echo "Preparing system configuration..."
echo "Target directory: $ETC_TARGET_DIR"
rsync -a \
    --exclude='/etc/hostname' \
    --exclude='/etc/hosts' \
    --exclude='/etc/resolv.conf' \
    --exclude='/etc/mtab' \
    /etc/ "$ETC_TARGET_DIR/"

echo "✓ System configuration copied with SSH host keys"

# Setup SSH directory and keys
# Create .ssh directory with correct permissions from the start
install -d -m 700 -o "$SSH_USER" -g "$SSH_USER" "/home/$SSH_USER/.ssh"

# Create SSH authorized_keys from ConfigMap mount
# This provides better security isolation and follows Kubernetes best practices
echo "Creating authorized_keys from ConfigMap mount..."

# Check if ConfigMap mounted authorized_keys exists
if [ -f "/etc/ssh-client-keys/authorized_keys" ]; then
    echo "Copying SSH public keys from ConfigMap to authorized_keys..."
    cp "/etc/ssh-client-keys/authorized_keys" "/home/$SSH_USER/.ssh/authorized_keys"
    echo "✓ SSH public keys copied from ConfigMap"
else
    # Fallback to environment variable for backward compatibility
    if [ -n "$SSH_PUBLIC_KEYS" ]; then
        echo "⚠️ ConfigMap not found, falling back to environment variables..."
        echo "$SSH_PUBLIC_KEYS" > "/home/$SSH_USER/.ssh/authorized_keys"
        echo "✓ SSH public keys written from environment variables"
    else
        echo "❌ ERROR: No SSH public keys found in ConfigMap or environment variables"
        echo "Creating empty authorized_keys file"
        touch "/home/$SSH_USER/.ssh/authorized_keys"
    fi
fi

# Set correct permissions for home directory and SSH files
# Security Design: Init Container must establish secure permissions for SSH operation
# Note: fsGroup in podSecurityContext should handle volume ownership, but explicit chmod may be needed
echo "Setting up home directory permissions..."

# Check if home directory has correct ownership (fsGroup should handle this)
echo "=== Checking fsGroup configuration in Init Container ==="
echo "Current process info:"
echo "  Running as: $(id)"
echo "  Process groups: $(id -G)"

HOME_OWNER=$(stat -c %U "/home/$SSH_USER" 2>/dev/null || echo "unknown")
HOME_GROUP=$(stat -c %G "/home/$SSH_USER" 2>/dev/null || echo "unknown")
HOME_PERMS=$(stat -c %a "/home/$SSH_USER" 2>/dev/null || echo "unknown")
echo "Home directory stats:"
echo "  Owner: $HOME_OWNER:$HOME_GROUP"
echo "  Permissions: $HOME_PERMS"

# Check if any volume mounts have SetGID bit
echo "Volume mount permissions:"
mount | grep "/home/$SSH_USER" && {
    echo "  Mount detected for home directory"
}
df -h "/home/$SSH_USER" | tail -1

# Set home directory permissions based on permission strategy
# CRITICAL: fsGroup strategy sets SetGID bit (02000) which must be preserved
CURRENT_PERMS=$(stat -c %a "/home/$SSH_USER" 2>/dev/null || echo "000")
SETGID_CHECK=$((0$CURRENT_PERMS & 02000))

echo "Permission strategy analysis:"
echo "  Current permissions: $CURRENT_PERMS"
echo "  SetGID bit detected: $SETGID_CHECK"
echo "  Permission strategy: ${SSH_PERMISSION_STRATEGY:-explicit}"

if [ "${SSH_PERMISSION_STRATEGY:-explicit}" = "fsgroup" ]; then
    echo "fsGroup strategy: Preserving Kubernetes-managed permissions"
    echo "  fsGroup should have set proper ownership and SetGID bit"
    echo "  Skipping explicit chmod to preserve SetGID bit"
    if [ "$SETGID_CHECK" = "0" ]; then
        echo "⚠️ WARNING: fsGroup strategy expected but no SetGID bit found"
        echo "This may indicate fsGroup is not working properly"
    else
        echo "✓ SetGID bit present - fsGroup strategy working correctly"
    fi
else
    echo "Explicit strategy: Setting explicit permissions (755)"
    if [ "$CURRENT_PERMS" != "755" ]; then
        chmod 755 "/home/$SSH_USER" 2>/dev/null && echo "✓ Set home directory permissions to 755" || {
            echo "⚠️ WARNING: Could not set home directory permissions to 755"
            echo "Current permissions: $(stat -c %a "/home/$SSH_USER" 2>/dev/null || echo "unknown")"
            echo "This may cause issues with SSH user sessions"
        }
    else
        echo "✓ Home directory already has correct permissions (755)"
    fi
fi

# Set authorized_keys permissions and ownership if file exists
if [ -f "/home/$SSH_USER/.ssh/authorized_keys" ]; then
    # CRITICAL: authorized_keys must be owned by the SSH user for SSH authentication to work
    echo "=== Setting authorized_keys ownership and permissions ==="
    
    # Show current status
    echo "Before ownership change:"
    stat -c "  authorized_keys: %U:%G (%a)" "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "  Cannot stat authorized_keys"
    
    # Set correct ownership first (critical for SSH security)
    chown "$SSH_USER:$SSH_USER" "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null && echo "✓ Set authorized_keys ownership to $SSH_USER:$SSH_USER" || {
        echo "❌ CRITICAL: Cannot set authorized_keys ownership - SSH authentication will fail!"
        echo "Current authorized_keys ownership: $(stat -c %U:%G "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "unknown")"
        echo "SSH requires the authorized_keys file to be owned by the SSH user."
        exit 1
    }
    
    # === CHMOD FAILURE DIAGNOSIS ===
    echo "=== Starting chmod 600 failure diagnosis ==="
    
    # 候補1: ファイルシステム制限の調査
    echo "【候補1: emptyDirファイルシステム制限】"
    mount | grep "/home" || echo "No /home mount found"
    findmnt "/home/$SSH_USER" 2>/dev/null || echo "Cannot get mount details for /home/$SSH_USER"
    
    # 候補2: SecurityContext権限の実際の確認
    echo "【候補2: SecurityContext権限確認】"
    capsh --print 2>/dev/null || echo "capsh not available"
    cat /proc/self/status | grep Cap || echo "Cannot read capabilities"
    
    # 候補3: ファイル作成方法と属性の確認
    echo "【候補3: ファイル作成方法確認】"
    ls -la /etc/ssh-client-keys/ || echo "Cannot list source keys"
    stat -c "%a %U:%G %n" /etc/ssh-client-keys/* 2>/dev/null || echo "Cannot stat source keys"
    lsattr "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "lsattr not available or no attributes"
    
    # 候補4: 代替作成方法でのテスト
    echo "【候補4: 代替作成方法テスト】"
    cp "/home/$SSH_USER/.ssh/authorized_keys" /tmp/test-auth-keys 2>/dev/null && {
        echo "Copied to /tmp - testing chmod on copy:"
        chmod 600 /tmp/test-auth-keys && echo "✓ chmod works on /tmp copy" || echo "❌ chmod fails even on /tmp copy"
        rm -f /tmp/test-auth-keys
    } || echo "Cannot copy file to /tmp"
    
    # 候補5: 詳細なエラー情報の取得（straceが利用可能な場合）
    echo "【候補5: 詳細エラー情報】"
    echo "Testing chmod with detailed error reporting..."
    
    # Set correct permissions (must be readable only by owner)
    chmod 600 "/home/$SSH_USER/.ssh/authorized_keys" && echo "✓ Set authorized_keys permissions to 600" || {
        CHMOD_EXIT_CODE=$?
        echo "❌ chmod failed with exit code: $CHMOD_EXIT_CODE"
        
        # Mark chmod failure for later detection by tests
        echo "CHMOD_FAILED" > /tmp/chmod_failure_marker
        echo "authorized_keys chmod failed with exit code $CHMOD_EXIT_CODE" >> /tmp/chmod_failure_marker
        
        # 詳細診断
        echo "Current file status:"
        stat -c "  Permissions: %a (%A)" "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "  Cannot stat file"
        stat -c "  Owner: %U:%G (%u:%g)" "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "  Cannot get ownership"
        stat -c "  Size: %s bytes" "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "  Cannot get size"
        
        echo "Process info:"
        id || echo "Cannot get process id"
        
        echo "Capabilities info:"
        if [ -f /proc/self/status ]; then
            grep -i "cap" /proc/self/status 2>/dev/null || echo "Cannot read capabilities from /proc/self/status"
        fi
        
        # Try to check specific capability
        if command -v capsh >/dev/null 2>&1; then
            echo "Current capabilities (capsh):"
            capsh --print 2>/dev/null || echo "capsh command failed"
        fi
        
        # Check file immutable attributes
        echo "File attributes check:"
        if command -v lsattr >/dev/null 2>&1; then
            lsattr "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "lsattr not available or failed"
        fi
        
        echo "Directory permissions:"
        stat -c "  .ssh dir: %a (%A) %U:%G" "/home/$SSH_USER/.ssh" 2>/dev/null || echo "  Cannot stat .ssh dir"
        stat -c "  home dir: %a (%A) %U:%G" "/home/$SSH_USER" 2>/dev/null || echo "  Cannot stat home dir"
        
        echo "Filesystem information:"
        df -T "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "Cannot get filesystem type"
        mount | grep "/home/$SSH_USER" 2>/dev/null || echo "No specific mount for home directory"
        findmnt -T "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "findmnt not available"
        
        # straceが利用可能な場合の詳細トレース
        if command -v strace >/dev/null 2>&1; then
            echo "Attempting strace analysis (if available):"
            strace -e chmod chmod 600 "/home/$SSH_USER/.ssh/authorized_keys" 2>&1 | head -10 || echo "strace failed or not available"
        else
            echo "strace not available for detailed analysis"
        fi
        
        echo "=== chmod診断完了 - 権限変更に失敗しました ==="
        
        # Check if debug mode is enabled for chmod failures
        if [ "${SSH_WORKSPACE_DEBUG_CHMOD_FAILURES:-false}" = "true" ]; then
            echo "⚠️ DEBUG MODE: chmod failure detected but continuing due to SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true"
            echo "⚠️ WARNING: This container may have insecure file permissions!"
            echo "⚠️ DEBUG MODE should NEVER be used in production environments"
        else
            echo "❌ CRITICAL SECURITY FAILURE: authorized_keys file permissions cannot be secured"
            echo "❌ SSH authentication requires authorized_keys to have 600 permissions"
            echo "❌ Terminating initialization to prevent insecure deployment"
            echo ""
            echo "To enable debug mode for troubleshooting (NOT for production):"
            echo "Set environment variable: SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true"
            exit 1
        fi
    }
    
    # Verify final status
    echo "After ownership and permission changes:"
    stat -c "  authorized_keys: %U:%G (%a)" "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "  Cannot stat authorized_keys"
fi
echo "✓ Home directory and SSH permissions set for $SSH_USER"

# Add user to sudo group if sudo is enabled
if [ "$SSH_USER_SUDO" = "true" ]; then
    if getent group sudo >/dev/null 2>&1; then
        usermod -aG sudo "$SSH_USER"
        echo "✓ Added $SSH_USER to sudo group"
    fi
fi

echo "✓ SSH Workspace initialization completed successfully"