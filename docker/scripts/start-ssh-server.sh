#!/bin/bash
# SSH workspace complete setup and startup script
# Design references: [[see:B3Q8-PORT]](../../README.ja.md#B3Q8-PORT), [[see:V4J1-HOSTKEY]](../../README.ja.md#V4J1-HOSTKEY), [[see:K2L8-HOSTVALID]](../../docs/design.md#K2L8-HOSTVALID), [[see:Y4F1-USER]](../../README.ja.md#Y4F1-USER)

set -e

# Configuration
USERNAME="${SSH_USERNAME:-developer}"
USER_UID="${SSH_UID:-1000}"
USER_GID="${SSH_GID:-1000}"
SSH_PORT="${SSH_PORT:-2222}"
HOME_DIR="/home/${USERNAME}"
SSH_DIR="${HOME_DIR}/.ssh"
DROPBEAR_DIR="${SSH_DIR}/dropbear"

echo "=== SSH Workspace Complete Setup ==="
echo "Username: ${USERNAME}"
echo "UID: ${USER_UID}"
echo "GID: ${USER_GID}"
echo "SSH Port: ${SSH_PORT}"
echo "Home Directory: ${HOME_DIR}"
echo "Dropbear Keys Directory: ${DROPBEAR_DIR}"

# Phase 1: User and Environment Setup (as root)
echo "=== Phase 1: User and Environment Setup ==="

# Create user and group if they don't exist
echo "Creating user and group..."
if ! getent group "${USER_GID}" >/dev/null; then
    echo "Creating group ${USERNAME} with GID ${USER_GID}"
    groupadd -g "${USER_GID}" "${USERNAME}"
else
    echo "Group with GID ${USER_GID} already exists"
fi

if ! id "${USERNAME}" >/dev/null 2>&1; then
    echo "Creating user ${USERNAME} with UID ${USER_UID}"
    useradd -u "${USER_UID}" -g "${USER_GID}" -d "${HOME_DIR}" -s /bin/bash "${USERNAME}"
else
    echo "User ${USERNAME} already exists"
fi

# Create SSH directories
echo "Creating SSH directories..."
mkdir -p "${SSH_DIR}"
mkdir -p "${DROPBEAR_DIR}"

# Copy SSH host keys from mounted secrets
echo "Setting up SSH host keys..."
if [ -f /mnt/ssh-host-keys/rsa_host_key ]; then
    echo "Copying RSA host key..."
    cp /mnt/ssh-host-keys/rsa_host_key "${DROPBEAR_DIR}/dropbear_rsa_host_key"
    chmod 600 "${DROPBEAR_DIR}/dropbear_rsa_host_key"
    echo "RSA host key configured"
else
    echo "WARNING: RSA host key not found in /mnt/ssh-host-keys/rsa_host_key"
fi

if [ -f /mnt/ssh-host-keys/ed25519_host_key ]; then
    echo "Copying Ed25519 host key..."
    cp /mnt/ssh-host-keys/ed25519_host_key "${DROPBEAR_DIR}/dropbear_ed25519_host_key"
    chmod 600 "${DROPBEAR_DIR}/dropbear_ed25519_host_key"
    echo "Ed25519 host key configured"
else
    echo "WARNING: Ed25519 host key not found in /mnt/ssh-host-keys/ed25519_host_key"
fi

# Copy SSH public keys (authorized_keys) from mounted secrets
echo "Setting up SSH public keys..."
if [ -f /mnt/ssh-public-keys/authorized_keys ]; then
    echo "Copying authorized_keys..."
    cp /mnt/ssh-public-keys/authorized_keys "${SSH_DIR}/authorized_keys"
    chmod 600 "${SSH_DIR}/authorized_keys"
    echo "Authorized keys configured"
else
    echo "WARNING: Authorized keys not found in /mnt/ssh-public-keys/authorized_keys"
fi

# Copy SSH private keys if they exist
if [ -d /mnt/ssh-private-keys ]; then
    echo "Setting up SSH private keys..."
    for key_file in /mnt/ssh-private-keys/*; do
        if [ -f "$key_file" ]; then
            key_name=$(basename "$key_file")
            echo "Copying private key: $key_name"
            cp "$key_file" "${SSH_DIR}/$key_name"
            chmod 600 "${SSH_DIR}/$key_name"
        fi
    done
    echo "Private keys configured"
else
    echo "INFO: No private keys directory found"
fi

# Set proper ownership
echo "Setting file ownership..."
chown -R "${USER_UID}:${USER_GID}" "${SSH_DIR}"

# Verify setup
echo "=== Setup Verification ==="
echo "SSH directory contents:"
ls -la "${SSH_DIR}" || echo "SSH directory not accessible"
if [ -d "${DROPBEAR_DIR}" ]; then
    echo "Dropbear directory contents:"
    ls -la "${DROPBEAR_DIR}" || echo "Dropbear directory not accessible"
fi

echo "SUCCESS: SSH environment setup completed"

# Phase 2: Start SSH Server (as target user)
echo "=== Phase 2: SSH Server Startup ==="

# Verify SSH keys exist
echo "Verifying SSH host keys..."
RSA_KEY="${DROPBEAR_DIR}/dropbear_rsa_host_key"
ED25519_KEY="${DROPBEAR_DIR}/dropbear_ed25519_host_key"

if [ ! -f "${RSA_KEY}" ]; then
    echo "ERROR: RSA host key not found at ${RSA_KEY}"
    exit 1
fi

if [ ! -f "${ED25519_KEY}" ]; then
    echo "ERROR: Ed25519 host key not found at ${ED25519_KEY}"
    exit 1
fi

echo "Host keys verified successfully"

# Verify authorized_keys exists
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
if [ ! -f "${AUTHORIZED_KEYS}" ]; then
    echo "WARNING: Authorized keys not found at ${AUTHORIZED_KEYS}"
    echo "SSH authentication may not work properly"
else
    echo "Authorized keys found at ${AUTHORIZED_KEYS}"
fi

# Switch to target user and start Dropbear
echo "Switching to user ${USERNAME} (${USER_UID}:${USER_GID}) to start Dropbear..."
echo "Command: dropbear -F -p ${SSH_PORT} -r ${RSA_KEY} -r ${ED25519_KEY}"

# Use su to switch to the target user and start dropbear
exec su -c "exec dropbear -F -p ${SSH_PORT} -r ${RSA_KEY} -r ${ED25519_KEY}" "${USERNAME}"