#!/bin/bash
# SSH host key generation script
# Design references: [T8Q4-AUTOGEN], [R6N7-CRYPTO]

set -e

# Configuration
RSA_KEY_SIZE=4096
HOST_KEY_DIR="/etc/dropbear"
RSA_KEY_FILE="${HOST_KEY_DIR}/dropbear_rsa_host_key"
ED25519_KEY_FILE="${HOST_KEY_DIR}/dropbear_ed25519_host_key"

generate_rsa_key() {
    echo "Generating RSA host key (${RSA_KEY_SIZE} bits)..."
    if dropbearkey -t rsa -s "$RSA_KEY_SIZE" -f "$RSA_KEY_FILE"; then
        echo "SUCCESS: RSA host key generated at $RSA_KEY_FILE"
        chmod 600 "$RSA_KEY_FILE"
        return 0
    else
        echo "ERROR: Failed to generate RSA host key"
        return 1
    fi
}

generate_ed25519_key() {
    echo "Generating Ed25519 host key..."
    if dropbearkey -t ed25519 -f "$ED25519_KEY_FILE"; then
        echo "SUCCESS: Ed25519 host key generated at $ED25519_KEY_FILE"
        chmod 600 "$ED25519_KEY_FILE"
        return 0
    else
        echo "ERROR: Failed to generate Ed25519 host key"
        return 1
    fi
}

main() {
    local force_regenerate=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_regenerate=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-f|--force] [-h|--help]"
                echo "  -f, --force    Force regeneration of existing keys"
                echo "  -h, --help     Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Create host key directory if it doesn't exist
    mkdir -p "$HOST_KEY_DIR"
    
    local error_count=0
    
    # Generate RSA key
    if [ "$force_regenerate" = true ] || [ ! -f "$RSA_KEY_FILE" ]; then
        if ! generate_rsa_key; then
            error_count=$((error_count + 1))
        fi
    else
        echo "INFO: RSA host key already exists at $RSA_KEY_FILE (use -f to force regeneration)"
    fi
    
    # Generate Ed25519 key
    if [ "$force_regenerate" = true ] || [ ! -f "$ED25519_KEY_FILE" ]; then
        if ! generate_ed25519_key; then
            error_count=$((error_count + 1))
        fi
    else
        echo "INFO: Ed25519 host key already exists at $ED25519_KEY_FILE (use -f to force regeneration)"
    fi
    
    if [ "$error_count" -eq 0 ]; then
        echo "SUCCESS: SSH host key generation completed"
        
        # Basic validation - check if files exist and have content
        echo "Verifying generated key files..."
        for key_file in "$RSA_KEY_FILE" "$ED25519_KEY_FILE"; do
            if [ -f "$key_file" ] && [ -s "$key_file" ]; then
                echo "INFO: Key file exists and has content: $key_file"
            else
                echo "WARNING: Key file missing or empty: $key_file"
                error_count=$((error_count + 1))
            fi
        done
        
        if [ "$error_count" -eq 0 ]; then
            echo "SUCCESS: All key files verified"
            exit 0
        else
            echo "FAILED: Key file verification failed"
            exit 1
        fi
    else
        echo "FAILED: $error_count errors occurred during key generation"
        exit 1
    fi
}

main "$@"