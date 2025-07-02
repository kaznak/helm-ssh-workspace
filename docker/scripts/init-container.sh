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
useradd -m -u "$SSH_USER_UID" -g "$SSH_USER_GID" -s "$SSH_USER_SHELL" "$SSH_USER" 2>/dev/null || true

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

# Copy system files to writable location (for readOnlyRootFilesystem)
echo "Preparing system configuration..."
echo "Target directory: $ETC_TARGET_DIR"
rsync -a \
    --exclude='/etc/hostname' \
    --exclude='/etc/hosts' \
    --exclude='/etc/resolv.conf' \
    --exclude='/etc/mtab' \
    /etc/ "$ETC_TARGET_DIR/"

# Ensure SSH directory exists
mkdir -p "$ETC_TARGET_DIR/ssh"

echo "✓ System configuration files copied with user data"

# Copy SSH host keys from Secret (if they exist)
if [ -f "/etc/ssh-host-keys/ssh_host_rsa_key" ]; then
    cp /etc/ssh-host-keys/ssh_host_* "$ETC_TARGET_DIR/ssh/"
    chmod 600 "$ETC_TARGET_DIR/ssh/ssh_host_"*"_key"
    chmod 644 "$ETC_TARGET_DIR/ssh/ssh_host_"*"_key.pub"
    echo "✓ SSH host keys loaded from Secret"
else
    # Generate SSH host keys on first deployment
    ssh-keygen -t rsa -b 2048 -f "$ETC_TARGET_DIR/ssh/ssh_host_rsa_key" -N ""
    ssh-keygen -t ecdsa -f "$ETC_TARGET_DIR/ssh/ssh_host_ecdsa_key" -N ""
    ssh-keygen -t ed25519 -f "$ETC_TARGET_DIR/ssh/ssh_host_ed25519_key" -N ""
    echo "✓ Generated new SSH host keys (first deployment)"
fi

# Setup SSH directory and keys
mkdir -p "/home/$SSH_USER/.ssh"
chmod 700 "/home/$SSH_USER/.ssh"

# Copy SSH public keys
if [ -d "/etc/ssh-keys" ]; then
    cat /etc/ssh-keys/* > "/home/$SSH_USER/.ssh/authorized_keys" 2>/dev/null || true
fi

# Set correct permissions
if [ -f "/home/$SSH_USER/.ssh/authorized_keys" ]; then
    chmod 600 "/home/$SSH_USER/.ssh/authorized_keys"
    chown -R "$SSH_USER:$SSH_USER" "/home/$SSH_USER/.ssh"
    echo "✓ Set SSH permissions for $SSH_USER"
fi

# Add user to sudo group if sudo is enabled
if [ "$SSH_USER_SUDO" = "true" ]; then
    if getent group sudo >/dev/null 2>&1; then
        usermod -aG sudo "$SSH_USER"
        echo "✓ Added $SSH_USER to sudo group"
    fi
fi

echo "✓ SSH Workspace initialization completed successfully"