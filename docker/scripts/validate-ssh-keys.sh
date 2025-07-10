#!/bin/bash
# NAME: validate-ssh-keys.sh
# SYNOPSIS: SSH key validation script
#
# USAGE:
#     validate-ssh-keys.sh <namespace> <host-secret> <pub-secret> [priv-secret]
#     validate-ssh-keys.sh [-h|--help]
#
# OPTIONS:
#     -h, --help     Show this help message
#
# DESCRIPTION:
#     Validate SSH keys from Kubernetes secrets and install to container
#
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
PROGRESS "Starting SSH key validation"

# ヘルプ処理または引数数チェック
if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
    print_help
    exit 0
elif [[ $# -lt 3 || $# -gt 4 ]]; then
    print_help
    exit 1
fi

# 引数取得
namespace="$1"
host_secret="$2"
pub_secret="$3"
priv_secret="${4:-}"

PROGRESS "Kubernetes SSH Key Validation"
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
rm -f /etc/dropbear/dropbear_rsa_host_key
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
rm -f /etc/dropbear/dropbear_ed25519_host_key
kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.ed25519_host_key}' | base64 -d > /etc/dropbear/dropbear_ed25519_host_key
chmod 600 /etc/dropbear/dropbear_ed25519_host_key

temp_pub_key="$tmpd/ed25519_host_pub"
error_msg="Cannot extract Ed25519 public key from Dropbear key"
dropbearkey -y -f "/etc/dropbear/dropbear_ed25519_host_key" | grep "^ssh-" > "$temp_pub_key" || ERROR_HANDLER ${LINENO}

key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
error_msg="Invalid Ed25519 host key format"
[[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}

key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
error_msg="Expected Ed25519 key, got $key_type"
[[ "$key_type" != "ED25519" ]] && ERROR_HANDLER ${LINENO}

MSG "INFO: Valid Ed25519 host key"

# Validate public keys from authorized_keys secret
PROGRESS "Validating authorized keys from secret"
error_msg="Public keys secret not found: $pub_secret"
kubectl get secret "$pub_secret" -n "$namespace" >/dev/null 2>&1 || ERROR_HANDLER ${LINENO}

# Create user-specific SSH directory
mkdir -p /home/user/.ssh
chmod 700 /home/user/.ssh

# Extract authorized_keys
kubectl get secret "$pub_secret" -n "$namespace" -o jsonpath='{.data.authorized_keys}' | base64 -d > /home/user/.ssh/authorized_keys
chmod 600 /home/user/.ssh/authorized_keys

# Validate each line in authorized_keys
line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_number++))
    
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Validate the public key
    temp_pub_key="$tmpd/auth_key_$line_number"
    echo "$line" > "$temp_pub_key"
    
    key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
    if [[ -z "$key_info" ]]; then
        error_msg="Invalid public key format at line $line_number"
        ERROR_HANDLER ${LINENO}
    fi
    
    key_bits=$(echo "$key_info" | awk '{print $1}')
    key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
    
    case "$key_type" in
        "RSA")
            error_msg="RSA public key at line $line_number is too weak ($key_bits bits). Minimum 2048 bits required"
            [[ "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
            [[ "$key_bits" -lt 4096 ]] && MSG "WARNING: RSA public key at line $line_number is $key_bits bits. 4096 bits recommended"
            ;;
        "ED25519")
            MSG "INFO: Ed25519 public key at line $line_number is using recommended algorithm"
            ;;
        *)
            error_msg="Unsupported public key type $key_type at line $line_number. Only RSA and Ed25519 are supported"
            ERROR_HANDLER ${LINENO}
            ;;
    esac
    
    MSG "INFO: Valid $key_type public key ($key_bits bits) at line $line_number"
done < /home/user/.ssh/authorized_keys

# Validate private keys if provided
if [[ -n "$priv_secret" ]]; then
    PROGRESS "Validating private keys from secret"
    
    # Check if private keys secret exists
    if kubectl get secret "$priv_secret" -n "$namespace" >/dev/null 2>&1; then
        # Extract private keys to user SSH directory
        if kubectl get secret "$priv_secret" -n "$namespace" -o jsonpath='{.data.id_rsa}' >/dev/null 2>&1; then
            kubectl get secret "$priv_secret" -n "$namespace" -o jsonpath='{.data.id_rsa}' | base64 -d > /home/user/.ssh/id_rsa
            chmod 600 /home/user/.ssh/id_rsa
            
            # Validate RSA private key
            temp_pub_key="$tmpd/priv_rsa_pub"
            error_msg="Cannot extract public key from RSA private key"
            ssh-keygen -y -f "/home/user/.ssh/id_rsa" > "$temp_pub_key" 2>/dev/null || ERROR_HANDLER ${LINENO}
            
            key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
            error_msg="Invalid RSA private key format"
            [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
            
            key_bits=$(echo "$key_info" | awk '{print $1}')
            key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
            
            case "$key_type" in
                "RSA")
                    error_msg="RSA private key is too weak ($key_bits bits). Minimum 2048 bits required"
                    [[ "$key_bits" -lt 2048 ]] && ERROR_HANDLER ${LINENO}
                    [[ "$key_bits" -lt 4096 ]] && MSG "WARNING: RSA private key is $key_bits bits. 4096 bits recommended"
                    ;;
                *)
                    error_msg="Expected RSA private key, got $key_type"
                    ERROR_HANDLER ${LINENO}
                    ;;
            esac
            
            MSG "INFO: Valid RSA private key ($key_bits bits)"
        fi
        
        if kubectl get secret "$priv_secret" -n "$namespace" -o jsonpath='{.data.id_ed25519}' >/dev/null 2>&1; then
            kubectl get secret "$priv_secret" -n "$namespace" -o jsonpath='{.data.id_ed25519}' | base64 -d > /home/user/.ssh/id_ed25519
            chmod 600 /home/user/.ssh/id_ed25519
            
            # Validate Ed25519 private key
            temp_pub_key="$tmpd/priv_ed25519_pub"
            error_msg="Cannot extract public key from Ed25519 private key"
            ssh-keygen -y -f "/home/user/.ssh/id_ed25519" > "$temp_pub_key" 2>/dev/null || ERROR_HANDLER ${LINENO}
            
            key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
            error_msg="Invalid Ed25519 private key format"
            [[ -z "$key_info" ]] && ERROR_HANDLER ${LINENO}
            
            key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
            error_msg="Expected Ed25519 private key, got $key_type"
            [[ "$key_type" != "ED25519" ]] && ERROR_HANDLER ${LINENO}
            
            MSG "INFO: Valid Ed25519 private key"
        fi
    else
        MSG "WARNING: Private keys secret not found: $priv_secret"
    fi
fi

MSG "SUCCESS: SSH key validation completed"