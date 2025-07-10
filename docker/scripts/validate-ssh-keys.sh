#!/bin/bash
# NAME: validate-ssh-keys.sh
# SYNOPSIS: SSH key validation script
# Design references: [see:K2L8-HOSTVALID], [see:H9F7-KEYFORMAT], [see:T6K9-PRIVFORMAT]

set -Cu -Ee -o pipefail
shopt -s nullglob

# 基本変数の初期化
stime=$(date +%Y%m%d%H%M%S%Z)
pname=$(basename $0)
based=$(readlink -f $(dirname $0)/..)
tmpd=$(mktemp -d)

# ログ出力設定
logd=$tmpd/log
mkdir -p $logd
exec 3>&2

# エラーハンドリング
error_msg=""
error_status=0

BEFORE_EXIT() {
    [[ -d "$tmpd" ]] && rm -rf "$tmpd"
}

ERROR_HANDLER() {
    error_status=$?
    MSG "ERROR at line $1: $error_msg"
    exit $error_status
}

trap 'BEFORE_EXIT' EXIT
trap 'ERROR_HANDLER ${LINENO}' ERR

# ログ関数
MSG() { 
    printf '%s %s[%s]: %s\n' "$(date)" "$pname" "$$" "$*" >&3
}

PROGRESS() {
    MSG "PROGRESS(${BASH_LINENO[0]}): $*"
}

# ヘルプ機能
print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

# メイン処理開始
command="$1"
target="$2"

# 引数チェック
error_msg="Usage: $0 <host-keys|authorized-keys|private-keys|k8s-hook> [target]"
[[ -z "$command" ]] && ERROR_HANDLER ${LINENO}

PROGRESS "Starting SSH key validation: $command"

# コマンド別処理
case "$command" in
    "host-keys")
        PROGRESS "Validating SSH host keys"
        error_count=0
        
        # RSA host key validation
        error_msg="RSA host key file not found"
        [[ ! -f "/etc/dropbear/dropbear_rsa_host_key" ]] && ERROR_HANDLER ${LINENO}
        
        temp_pub_key="$tmpd/rsa_host_pub"
        error_msg="Cannot extract RSA public key from Dropbear key"
        dropbearkey -y -f "/etc/dropbear/dropbear_rsa_host_key" | grep "^ssh-" > "$temp_pub_key" || ERROR_HANDLER ${LINENO}
        
        key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
        error_msg="Invalid RSA host key format"
        [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
        
        key_bits=$(echo "$key_info" | awk '{print $1}')
        key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
        
        error_msg="RSA host key is too weak ($key_bits bits). Minimum 2048 bits required"
        [[ "$key_type" == "RSA" && "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
        
        [[ "$key_type" == "RSA" && "$key_bits" -lt 4096 ]] && MSG "WARNING: RSA host key is $key_bits bits. 4096 bits recommended"
        MSG "INFO: Valid $key_type host key ($key_bits bits) found"
        
        # Ed25519 host key validation
        error_msg="Ed25519 host key file not found"
        [[ ! -f "/etc/dropbear/dropbear_ed25519_host_key" ]] && ERROR_HANDLER ${LINENO}
        
        temp_pub_key="$tmpd/ed25519_host_pub"
        error_msg="Cannot extract Ed25519 public key from Dropbear key"
        dropbearkey -y -f "/etc/dropbear/dropbear_ed25519_host_key" | grep "^ssh-" > "$temp_pub_key" || ERROR_HANDLER ${LINENO}
        
        key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
        error_msg="Invalid Ed25519 host key format"
        [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
        
        key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
        error_msg="Expected Ed25519 key type, got $key_type"
        [[ "$key_type" != "ED25519" ]] && ERROR_HANDLER ${LINENO}
        
        MSG "INFO: Valid Ed25519 host key found"
        MSG "SUCCESS: All SSH host keys are valid"
        ;;
        
    "authorized-keys")
        error_msg="authorized_keys file path required"
        [[ -z "$target" ]] && ERROR_HANDLER ${LINENO}
        
        error_msg="authorized_keys file not found: $target"
        [[ ! -f "$target" ]] && ERROR_HANDLER ${LINENO}
        
        PROGRESS "Validating authorized_keys: $target"
        line_num=0
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            line_num=$((line_num + 1))
            
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            temp_key="$tmpd/key_$line_num"
            echo "$line" > "$temp_key"
            
            key_info=$(ssh-keygen -lf "$temp_key" 2>/dev/null)
            error_msg="Invalid public key format on line $line_num"
            [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
            
            key_bits=$(echo "$key_info" | awk '{print $1}')
            key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
            
            case "$key_type" in
                "RSA")
                    error_msg="RSA key on line $line_num is too weak ($key_bits bits). Minimum 2048 bits required"
                    [[ "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
                    [[ "$key_bits" -lt 4096 ]] && MSG "WARNING: RSA key on line $line_num is $key_bits bits. 4096 bits recommended"
                    ;;
                "ED25519")
                    MSG "INFO: Ed25519 key on line $line_num is using recommended algorithm"
                    ;;
                *)
                    error_msg="Unsupported key type $key_type on line $line_num. Only RSA and Ed25519 are supported"
                    ERROR_HANDLER ${LINENO}
                    ;;
            esac
            
            MSG "INFO: Valid $key_type key ($key_bits bits) on line $line_num"
        done < "$target"
        
        MSG "SUCCESS: All authorized_keys are valid"
        ;;
        
    "private-keys")
        error_msg="SSH directory path required"
        [[ -z "$target" ]] && ERROR_HANDLER ${LINENO}
        
        [[ ! -d "$target" ]] && {
            MSG "INFO: SSH directory not found: $target"
            exit 0
        }
        
        PROGRESS "Validating private keys in: $target"
        
        # Find all private key files
        private_keys=$(find "$target" -name "id_*" -not -name "*.pub" -type f 2>/dev/null || true)
        
        [[ -z "$private_keys" ]] && {
            MSG "INFO: No private keys found in $target"
            exit 0
        }
        
        for key_file in $private_keys; do
            PROGRESS "Validating private key: $key_file"
            
            error_msg="Private key file not found: $key_file"
            [[ ! -f "$key_file" ]] && ERROR_HANDLER ${LINENO}
            
            key_info=$(ssh-keygen -lf "$key_file" 2>/dev/null)
            error_msg="Invalid private key format in $key_file"
            [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
            
            key_bits=$(echo "$key_info" | awk '{print $1}')
            key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
            
            case "$key_type" in
                "RSA")
                    error_msg="RSA private key in $key_file is too weak ($key_bits bits). Minimum 2048 bits required"
                    [[ "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
                    [[ "$key_bits" -lt 4096 ]] && MSG "WARNING: RSA private key in $key_file is $key_bits bits. 4096 bits recommended"
                    ;;
                "ED25519")
                    MSG "INFO: Ed25519 private key in $key_file is using recommended algorithm"
                    ;;
                *)
                    error_msg="Unsupported private key type $key_type in $key_file. Only RSA and Ed25519 are supported"
                    ERROR_HANDLER ${LINENO}
                    ;;
            esac
            
            MSG "INFO: Valid $key_type private key ($key_bits bits) in $key_file"
        done
        
        MSG "SUCCESS: All private keys are valid"
        ;;
        
    "k8s-hook")
        namespace="$2"
        host_secret="$3"
        pub_secret="$4"
        priv_secret="$5"
        
        error_msg="Usage: $0 k8s-hook <namespace> <host-secret> <pub-secret> [priv-secret]"
        [[ -z "$namespace" || -z "$host_secret" || -z "$pub_secret" ]] && ERROR_HANDLER ${LINENO}
        
        PROGRESS "Kubernetes Hook SSH Key Validation"
        MSG "Namespace: $namespace"
        MSG "Host Secret: $host_secret"
        MSG "Public Secret: $pub_secret"
        MSG "Private Secret: $priv_secret"
        
        # Validate host keys from Kubernetes secret
        PROGRESS "Validating SSH host keys from secret"
        error_msg="Host keys secret not found: $host_secret"
        kubectl get secret "$host_secret" -n "$namespace" >/dev/null 2>&1 || ERROR_HANDLER ${LINENO}
        
        # Ensure /etc/dropbear directory exists
        mkdir -p /etc/dropbear 2>/dev/null || true
        
        # Extract and validate RSA host key
        PROGRESS "Extracting RSA host key"
        kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.rsa_host_key}' | base64 -d > /etc/dropbear/dropbear_rsa_host_key
        chmod 600 /etc/dropbear/dropbear_rsa_host_key
        
        temp_pub_key="$tmpd/rsa_host_pub"
        error_msg="Cannot extract RSA public key from Dropbear key"
        dropbearkey -y -f "/etc/dropbear/dropbear_rsa_host_key" | grep "^ssh-" > "$temp_pub_key" || ERROR_HANDLER ${LINENO}
        
        key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
        error_msg="Invalid RSA host key format"
        [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
        
        key_bits=$(echo "$key_info" | awk '{print $1}')
        key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
        error_msg="RSA host key is too weak ($key_bits bits). Minimum 2048 bits required"
        [[ "$key_type" == "RSA" && "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
        
        MSG "INFO: Valid $key_type host key ($key_bits bits)"
        
        # Extract and validate Ed25519 host key
        PROGRESS "Extracting Ed25519 host key"
        kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.ed25519_host_key}' | base64 -d > /etc/dropbear/dropbear_ed25519_host_key
        chmod 600 /etc/dropbear/dropbear_ed25519_host_key
        
        temp_pub_key="$tmpd/ed25519_host_pub"
        error_msg="Cannot extract Ed25519 public key from Dropbear key"
        dropbearkey -y -f "/etc/dropbear/dropbear_ed25519_host_key" | grep "^ssh-" > "$temp_pub_key" || ERROR_HANDLER ${LINENO}
        
        key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
        error_msg="Invalid Ed25519 host key format"
        [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
        
        MSG "INFO: Valid Ed25519 host key"
        
        # Validate public keys from Kubernetes secret
        PROGRESS "Validating SSH public keys from secret"
        kubectl get secret "$pub_secret" -n "$namespace" >/dev/null 2>&1 || {
            MSG "WARNING: SSH public keys secret not found: $pub_secret"
        }
        
        [[ $(kubectl get secret "$pub_secret" -n "$namespace" >/dev/null 2>&1; echo $?) -eq 0 ]] && {
            kubectl get secret "$pub_secret" -n "$namespace" -o jsonpath='{.data.authorized_keys}' | base64 -d > "$tmpd/authorized_keys"
            
            line_num=0
            while IFS= read -r line || [[ -n "$line" ]]; do
                line_num=$((line_num + 1))
                
                # Skip empty lines and comments
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                
                temp_key="$tmpd/pubkey_$line_num"
                echo "$line" > "$temp_key"
                
                key_info=$(ssh-keygen -lf "$temp_key" 2>/dev/null)
                error_msg="Invalid public key format on line $line_num in authorized_keys"
                [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
                
                key_bits=$(echo "$key_info" | awk '{print $1}')
                key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
                
                case "$key_type" in
                    "RSA")
                        error_msg="RSA key on line $line_num is too weak ($key_bits bits). Minimum 2048 bits required"
                        [[ "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
                        ;;
                    "ED25519")
                        MSG "INFO: Ed25519 key on line $line_num is using recommended algorithm"
                        ;;
                    *)
                        error_msg="Unsupported key type $key_type on line $line_num. Only RSA and Ed25519 are supported"
                        ERROR_HANDLER ${LINENO}
                        ;;
                esac
                
                MSG "INFO: Valid $key_type public key ($key_bits bits) on line $line_num"
            done < "$tmpd/authorized_keys"
        }
        
        # Validate private keys if specified
        [[ -n "$priv_secret" && "$priv_secret" != "null" ]] && {
            PROGRESS "Validating SSH private keys from secret"
            kubectl get secret "$priv_secret" -n "$namespace" >/dev/null 2>&1 || {
                MSG "INFO: SSH private keys secret not found: $priv_secret"
                priv_secret=""
            }
            
            [[ -n "$priv_secret" ]] && {
                mkdir -p "$tmpd/ssh_keys"
                kubectl get secret "$priv_secret" -n "$namespace" -o json | jq -r '.data | to_entries[] | "\(.key) \(.value)"' | while read -r key_name key_data; do
                    echo "$key_data" | base64 -d > "$tmpd/ssh_keys/$key_name"
                    
                    key_info=$(ssh-keygen -lf "$tmpd/ssh_keys/$key_name" 2>/dev/null)
                    error_msg="Invalid private key format in $key_name"
                    [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
                    
                    key_bits=$(echo "$key_info" | awk '{print $1}')
                    key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
                    
                    case "$key_type" in
                        "RSA")
                            error_msg="RSA private key $key_name is too weak ($key_bits bits). Minimum 2048 bits required"
                            [[ "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
                            ;;
                        "ED25519")
                            MSG "INFO: Ed25519 private key $key_name is using recommended algorithm"
                            ;;
                        *)
                            error_msg="Unsupported private key type $key_type in $key_name. Only RSA and Ed25519 are supported"
                            ERROR_HANDLER ${LINENO}
                            ;;
                    esac
                    
                    MSG "INFO: Valid $key_type private key ($key_bits bits) in $key_name"
                done
            }
        }
        
        MSG "SUCCESS: All SSH key validations passed"
        ;;
        
    *)
        print_help
        exit 1
        ;;
esac

MSG "SUCCESS: SSH key validation completed"