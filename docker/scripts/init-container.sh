#!/bin/bash
set -e

# Init Container script for SSH Workspace
# This script sets up user, SSH configuration, and system files

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
    # Copy SSH host keys from Secret
    cp /etc/ssh-host-keys/ssh_host_* /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key
    chmod 644 /etc/ssh/ssh_host_*_key.pub
    echo "✓ SSH host keys loaded from Secret"
else
    # Generate SSH host keys directly in /etc/ssh (always needed since image has them removed)
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

# Copy SSH public keys
if [ -d "/etc/ssh-keys" ]; then
    cat /etc/ssh-keys/* > "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || true
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
    
    # Set correct permissions (must be readable only by owner)
    chmod 600 "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null && echo "✓ Set authorized_keys permissions to 600" || {
        echo "❌ CRITICAL: Cannot set authorized_keys permissions - SSH authentication will fail!"
        echo "Current authorized_keys permissions: $(stat -c %a "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || echo "unknown")"
        echo "This is a security risk and SSH will reject the key file."
        exit 1
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