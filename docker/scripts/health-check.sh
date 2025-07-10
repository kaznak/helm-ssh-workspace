#!/bin/bash
# Health check script for SSH workspace
# Design reference: [R6Q9-READINESS]

set -e

# Configuration
USERNAME="${SSH_USERNAME:-developer}"
SSH_PORT="${SSH_PORT:-2222}"
DROPBEAR_DIR="/home/${USERNAME}/.ssh/dropbear"

# Check if Dropbear process is running
if ! pgrep dropbear > /dev/null; then
    echo "ERROR: Dropbear SSH server process not found"
    exit 1
fi

# Check if SSH port is listening using ss
if ! ss -ln | grep -q ":${SSH_PORT} "; then
    echo "ERROR: SSH port ${SSH_PORT} is not listening"
    exit 1
fi

# Check if SSH host keys exist in the correct location
if [ ! -f "${DROPBEAR_DIR}/dropbear_rsa_host_key" ]; then
    echo "ERROR: RSA host key not found at ${DROPBEAR_DIR}/dropbear_rsa_host_key"
    exit 1
fi

if [ ! -f "${DROPBEAR_DIR}/dropbear_ed25519_host_key" ]; then
    echo "ERROR: Ed25519 host key not found at ${DROPBEAR_DIR}/dropbear_ed25519_host_key"
    exit 1
fi

echo "SSH workspace health check passed"
exit 0