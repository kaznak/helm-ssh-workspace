#!/bin/bash
# SSH key validation script
# Design references: [K2L8-HOSTVALID], [H9F7-KEYFORMAT], [T6K9-PRIVFORMAT]

set -e

validate_public_key() {
    local key_file="$1"
    local key_type
    local key_bits
    
    if [ ! -f "$key_file" ]; then
        echo "ERROR: Public key file not found: $key_file"
        return 1
    fi
    
    # Get key information
    key_info=$(ssh-keygen -lf "$key_file" 2>/dev/null) || {
        echo "ERROR: Invalid public key format in $key_file"
        return 1
    }
    
    key_bits=$(echo "$key_info" | awk '{print $1}')
    key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
    
    case "$key_type" in
        "RSA")
            if [ "$key_bits" -lt 2048 ]; then
                echo "ERROR: RSA key in $key_file is too weak ($key_bits bits). Minimum 2048 bits required."
                return 1
            elif [ "$key_bits" -lt 4096 ]; then
                echo "WARNING: RSA key in $key_file is $key_bits bits. 4096 bits recommended."
            fi
            ;;
        "ED25519")
            echo "INFO: Ed25519 key in $key_file is using recommended algorithm."
            ;;
        *)
            echo "ERROR: Unsupported key type $key_type in $key_file. Only RSA and Ed25519 are supported."
            return 1
            ;;
    esac
    
    echo "INFO: Valid $key_type key ($key_bits bits) found in $key_file"
    return 0
}

validate_private_key() {
    local key_file="$1"
    local key_type
    local key_bits
    
    if [ ! -f "$key_file" ]; then
        echo "ERROR: Private key file not found: $key_file"
        return 1
    fi
    
    # Get key information
    key_info=$(ssh-keygen -lf "$key_file" 2>/dev/null) || {
        echo "ERROR: Invalid private key format in $key_file"
        return 1
    }
    
    key_bits=$(echo "$key_info" | awk '{print $1}')
    key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
    
    case "$key_type" in
        "RSA")
            if [ "$key_bits" -lt 2048 ]; then
                echo "ERROR: RSA private key in $key_file is too weak ($key_bits bits). Minimum 2048 bits required."
                return 1
            elif [ "$key_bits" -lt 4096 ]; then
                echo "WARNING: RSA private key in $key_file is $key_bits bits. 4096 bits recommended."
            fi
            ;;
        "ED25519")
            echo "INFO: Ed25519 private key in $key_file is using recommended algorithm."
            ;;
        *)
            echo "ERROR: Unsupported private key type $key_type in $key_file. Only RSA and Ed25519 are supported."
            return 1
            ;;
    esac
    
    echo "INFO: Valid $key_type private key ($key_bits bits) found in $key_file"
    return 0
}

validate_host_keys() {
    local error_count=0
    
    echo "=== Validating SSH host keys ==="
    
    # Validate RSA host key
    if ! validate_public_key "/etc/dropbear/dropbear_rsa_host_key"; then
        error_count=$((error_count + 1))
    fi
    
    # Validate Ed25519 host key
    if ! validate_public_key "/etc/dropbear/dropbear_ed25519_host_key"; then
        error_count=$((error_count + 1))
    fi
    
    if [ "$error_count" -eq 0 ]; then
        echo "SUCCESS: All SSH host keys are valid"
        return 0
    else
        echo "FAILED: $error_count SSH host key validation errors"
        return 1
    fi
}

validate_authorized_keys() {
    local authorized_keys_file="$1"
    local error_count=0
    local line_num=0
    
    if [ ! -f "$authorized_keys_file" ]; then
        echo "ERROR: authorized_keys file not found: $authorized_keys_file"
        return 1
    fi
    
    echo "=== Validating authorized_keys ==="
    
    # Create temporary file for each key
    local temp_dir=$(mktemp -d)
    
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Create temporary file for this key
        local temp_key="$temp_dir/key_$line_num"
        echo "$line" > "$temp_key"
        
        echo "Validating key on line $line_num..."
        if ! validate_public_key "$temp_key"; then
            error_count=$((error_count + 1))
        fi
        
        rm -f "$temp_key"
    done < "$authorized_keys_file"
    
    rm -rf "$temp_dir"
    
    if [ "$error_count" -eq 0 ]; then
        echo "SUCCESS: All authorized_keys are valid"
        return 0
    else
        echo "FAILED: $error_count authorized_keys validation errors"
        return 1
    fi
}

validate_private_keys() {
    local ssh_dir="$1"
    local error_count=0
    
    if [ ! -d "$ssh_dir" ]; then
        echo "INFO: SSH directory not found: $ssh_dir"
        return 0
    fi
    
    echo "=== Validating private keys ==="
    
    # Find all private key files
    local private_keys
    private_keys=$(find "$ssh_dir" -name "id_*" -not -name "*.pub" -type f 2>/dev/null || true)
    
    if [ -z "$private_keys" ]; then
        echo "INFO: No private keys found in $ssh_dir"
        return 0
    fi
    
    for key_file in $private_keys; do
        echo "Validating private key: $key_file"
        if ! validate_private_key "$key_file"; then
            error_count=$((error_count + 1))
        fi
    done
    
    if [ "$error_count" -eq 0 ]; then
        echo "SUCCESS: All private keys are valid"
        return 0
    else
        echo "FAILED: $error_count private key validation errors"
        return 1
    fi
}

# Main function
main() {
    local command="$1"
    local target="$2"
    
    case "$command" in
        "host-keys")
            validate_host_keys
            ;;
        "authorized-keys")
            validate_authorized_keys "$target"
            ;;
        "private-keys")
            validate_private_keys "$target"
            ;;
        *)
            echo "Usage: $0 <host-keys|authorized-keys|private-keys> [target]"
            echo "  host-keys: Validate SSH host keys"
            echo "  authorized-keys <file>: Validate authorized_keys file"
            echo "  private-keys <dir>: Validate private keys in SSH directory"
            exit 1
            ;;
    esac
}

main "$@"