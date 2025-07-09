#!/bin/bash
# Health check script for SSH workspace
# Design reference: [R6Q9-READINESS]

set -e

# Check if Dropbear process is running
if ! pgrep dropbear > /dev/null; then
    echo "ERROR: Dropbear SSH server process not found"
    exit 1
fi

# Check if SSH port is listening
if ! netstat -ln | grep -q ":2222 "; then
    echo "ERROR: SSH port 2222 is not listening"
    exit 1
fi

# Check if SSH host keys exist
if [ ! -f /etc/dropbear/dropbear_rsa_host_key ]; then
    echo "ERROR: RSA host key not found"
    exit 1
fi

if [ ! -f /etc/dropbear/dropbear_ed25519_host_key ]; then
    echo "ERROR: Ed25519 host key not found"
    exit 1
fi

echo "SSH workspace health check passed"
exit 0