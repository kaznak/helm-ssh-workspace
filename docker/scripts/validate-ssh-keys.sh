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

validate_dropbear_key() {
    local key_file="$1"
    local key_type="$2"
    
    if [ ! -f "$key_file" ]; then
        echo "ERROR: Dropbear key file not found: $key_file"
        return 1
    fi
    
    if [ ! -s "$key_file" ]; then
        echo "ERROR: Dropbear key file is empty: $key_file"
        return 1
    fi
    
    # Extract public key from dropbear private key and validate it
    local temp_pub_key=$(mktemp)
    if dropbearkey -y -f "$key_file" | grep "^ssh-" > "$temp_pub_key"; then
        if validate_public_key "$temp_pub_key"; then
            echo "INFO: Valid $key_type Dropbear key found in $key_file"
            rm -f "$temp_pub_key"
            return 0
        else
            echo "ERROR: Invalid $key_type Dropbear key in $key_file"
            rm -f "$temp_pub_key"
            return 1
        fi
    else
        echo "ERROR: Cannot extract public key from Dropbear key: $key_file"
        rm -f "$temp_pub_key"
        return 1
    fi
}

validate_host_keys() {
    local error_count=0
    
    echo "=== Validating SSH host keys ==="
    
    # Validate RSA host key
    if ! validate_dropbear_key "/etc/dropbear/dropbear_rsa_host_key" "RSA"; then
        error_count=$((error_count + 1))
    fi
    
    # Validate Ed25519 host key
    if ! validate_dropbear_key "/etc/dropbear/dropbear_ed25519_host_key" "Ed25519"; then
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

# Kubernetes Hook validation function
validate_k8s_hook() {
    local namespace="$1"
    local host_secret="$2"
    local pub_secret="$3"
    local priv_secret="$4"
    
    local validation_failed=false
    
    echo "=== Kubernetes Hook SSH Key Validation ==="
    echo "Namespace: $namespace"
    echo "Host Secret: $host_secret"
    echo "Public Secret: $pub_secret"
    echo "Private Secret: $priv_secret"
    
    # Validate host keys from Kubernetes secret
    echo "=== Validating SSH host keys ==="
    if kubectl get secret "$host_secret" -n "$namespace" >/dev/null 2>&1; then
        # Ensure /etc/dropbear directory exists and is writable
        mkdir -p /etc/dropbear 2>/dev/null || true
        
        # Extract host keys to expected locations
        echo "Extracting RSA host key..."
        kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.rsa_host_key}' | base64 -d > /etc/dropbear/dropbear_rsa_host_key
        chmod 600 /etc/dropbear/dropbear_rsa_host_key
        
        echo "Extracting Ed25519 host key..."
        kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.ed25519_host_key}' | base64 -d > /etc/dropbear/dropbear_ed25519_host_key
        chmod 600 /etc/dropbear/dropbear_ed25519_host_key
        
        echo "Validating extracted host keys..."
        if ! validate_host_keys; then
            validation_failed=true
        fi
    else
        echo "ERROR: Host keys secret not found: $host_secret"
        validation_failed=true
    fi
    
    # Validate public keys from Kubernetes secret
    echo "=== Validating SSH public keys ==="
    if kubectl get secret "$pub_secret" -n "$namespace" >/dev/null 2>&1; then
        kubectl get secret "$pub_secret" -n "$namespace" -o jsonpath='{.data.authorized_keys}' | base64 -d > /tmp/authorized_keys
        if ! validate_authorized_keys "/tmp/authorized_keys"; then
            validation_failed=true
        fi
    else
        echo "WARNING: SSH public keys secret not found: $pub_secret"
    fi
    
    # Validate private keys from Kubernetes secret (if specified)
    if [ -n "$priv_secret" ] && [ "$priv_secret" != "null" ]; then
        echo "=== Validating SSH private keys ==="
        if kubectl get secret "$priv_secret" -n "$namespace" >/dev/null 2>&1; then
            # Extract all private keys
            mkdir -p /tmp/ssh_keys
            kubectl get secret "$priv_secret" -n "$namespace" -o json | jq -r '.data | to_entries[] | "\(.key) \(.value)"' | while read -r key_name key_data; do
                echo "$key_data" | base64 -d > "/tmp/ssh_keys/$key_name"
            done
            
            if ! validate_private_keys "/tmp/ssh_keys"; then
                validation_failed=true
            fi
        else
            echo "INFO: SSH private keys secret not found: $priv_secret"
        fi
        
        # Check for key duplication between public and private secrets
        echo "=== Checking for key duplication ==="
        if kubectl get secret "$pub_secret" -n "$namespace" >/dev/null 2>&1 && kubectl get secret "$priv_secret" -n "$namespace" >/dev/null 2>&1; then
            local pub_keys priv_keys
            pub_keys=$(kubectl get secret "$pub_secret" -n "$namespace" -o json | jq -r '.data | keys[]')
            priv_keys=$(kubectl get secret "$priv_secret" -n "$namespace" -o json | jq -r '.data | keys[]')
            
            for pub_key in $pub_keys; do
                for priv_key in $priv_keys; do
                    if [ "$pub_key" = "$priv_key" ]; then
                        echo "ERROR: Duplicate key found in both public and private secrets: $pub_key"
                        validation_failed=true
                    fi
                done
            done
        fi
    fi
    
    if [ "$validation_failed" = true ]; then
        echo "FAILED: SSH key validation failed"
        return 1
    else
        echo "SUCCESS: All SSH key validations passed"
        return 0
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
        "k8s-hook")
            # For Kubernetes Hook validation
            # Usage: validate-ssh-keys.sh k8s-hook <namespace> <host-secret> <pub-secret> [priv-secret]
            local namespace="$2"
            local host_secret="$3"
            local pub_secret="$4"
            local priv_secret="$5"
            
            if [ -z "$namespace" ] || [ -z "$host_secret" ] || [ -z "$pub_secret" ]; then
                echo "Usage: $0 k8s-hook <namespace> <host-secret> <pub-secret> [priv-secret]"
                exit 1
            fi
            
            validate_k8s_hook "$namespace" "$host_secret" "$pub_secret" "$priv_secret"
            ;;
        *)
            echo "Usage: $0 <host-keys|authorized-keys|private-keys|k8s-hook> [target]"
            echo "  host-keys: Validate SSH host keys"
            echo "  authorized-keys <file>: Validate authorized_keys file"
            echo "  private-keys <dir>: Validate private keys in SSH directory"
            echo "  k8s-hook <namespace> <host-secret> <pub-secret> [priv-secret]: Validate keys from Kubernetes secrets"
            exit 1
            ;;
    esac
}

main "$@"