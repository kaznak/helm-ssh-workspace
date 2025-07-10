#!/bin/bash
# NAME: generate-host-keys.sh
# SYNOPSIS: SSH host key generation script
# Design references: [see:T8Q4-AUTOGEN], [see:R6N7-CRYPTO]

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
    echo "Usage: $0 [-f|--force] [-h|--help]"
    echo "       $0 k8s-hook <namespace> <secret_name>"
    echo "  -f, --force    Force regeneration of existing keys"
    echo "  -h, --help     Show this help message"
    echo "  k8s-hook       Generate keys and create Kubernetes secret"
}

# 設定
RSA_KEY_SIZE=4096
HOST_KEY_DIR="/etc/dropbear"
RSA_KEY_FILE="${HOST_KEY_DIR}/dropbear_rsa_host_key"
ED25519_KEY_FILE="${HOST_KEY_DIR}/dropbear_ed25519_host_key"

# メイン処理開始
command="$1"

PROGRESS "Starting SSH host key generation"

# ヘルプ処理
[[ "$command" == "-h" || "$command" == "--help" ]] && {
    print_help
    exit 0
}

# ディレクトリ作成
mkdir -p "$HOST_KEY_DIR"

# k8s-hook モード
[[ "$command" == "k8s-hook" ]] && {
    namespace="$2"
    secret_name="$3"
    
    error_msg="Usage: $0 k8s-hook <namespace> <secret_name>"
    [[ -z "$namespace" || -z "$secret_name" ]] && ERROR_HANDLER ${LINENO}
    
    PROGRESS "Kubernetes Hook Host Key Generation"
    MSG "Namespace: $namespace"
    MSG "Secret Name: $secret_name"
    
    # Secret存在チェック
    kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1 && {
        MSG "INFO: SSH host keys secret already exists: $secret_name"
        exit 0
    }
    
    PROGRESS "Generating SSH host keys"
    
    # RSA鍵生成
    PROGRESS "Generating RSA host key (${RSA_KEY_SIZE} bits)"
    error_msg="Failed to generate RSA host key"
    dropbearkey -t rsa -s "$RSA_KEY_SIZE" -f "$RSA_KEY_FILE" || ERROR_HANDLER ${LINENO}
    chmod 600 "$RSA_KEY_FILE"
    MSG "SUCCESS: RSA host key generated at $RSA_KEY_FILE"
    
    # Ed25519鍵生成
    PROGRESS "Generating Ed25519 host key"
    error_msg="Failed to generate Ed25519 host key"
    dropbearkey -t ed25519 -f "$ED25519_KEY_FILE" || ERROR_HANDLER ${LINENO}
    chmod 600 "$ED25519_KEY_FILE"
    MSG "SUCCESS: Ed25519 host key generated at $ED25519_KEY_FILE"
    
    # ファイル検証
    PROGRESS "Verifying generated key files"
    for key_file in "$RSA_KEY_FILE" "$ED25519_KEY_FILE"; do
        error_msg="Key file missing or empty: $key_file"
        [[ ! -f "$key_file" || ! -s "$key_file" ]] && ERROR_HANDLER ${LINENO}
        MSG "INFO: Key file verified: $key_file"
    done
    
    # Secret作成
    PROGRESS "Creating Kubernetes secret: $secret_name"
    error_msg="Failed to create Kubernetes secret"
    kubectl create secret generic "$secret_name" \
        --from-file=rsa_host_key="$RSA_KEY_FILE" \
        --from-file=ed25519_host_key="$ED25519_KEY_FILE" \
        -n "$namespace" || ERROR_HANDLER ${LINENO}
    
    # リソースポリシー注釈追加 [R8N9-REUSE]
    error_msg="Failed to add resource policy annotation"
    kubectl annotate secret "$secret_name" \
        "helm.sh/resource-policy=keep" \
        -n "$namespace" || ERROR_HANDLER ${LINENO}
    
    MSG "SUCCESS: SSH host keys secret created successfully: $secret_name"
    exit 0
}

# 通常モード
force_regenerate=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            force_regenerate=true
            shift
            ;;
        *)
            error_msg="Unknown option: $1"
            ERROR_HANDLER ${LINENO}
            ;;
    esac
done

PROGRESS "Starting normal mode SSH host key generation"

# RSA鍵生成
[[ "$force_regenerate" == true || ! -f "$RSA_KEY_FILE" ]] && {
    PROGRESS "Generating RSA host key (${RSA_KEY_SIZE} bits)"
    error_msg="Failed to generate RSA host key"
    dropbearkey -t rsa -s "$RSA_KEY_SIZE" -f "$RSA_KEY_FILE" || ERROR_HANDLER ${LINENO}
    chmod 600 "$RSA_KEY_FILE"
    MSG "SUCCESS: RSA host key generated at $RSA_KEY_FILE"
} || {
    MSG "INFO: RSA host key already exists at $RSA_KEY_FILE (use -f to force regeneration)"
}

# Ed25519鍵生成
[[ "$force_regenerate" == true || ! -f "$ED25519_KEY_FILE" ]] && {
    PROGRESS "Generating Ed25519 host key"
    error_msg="Failed to generate Ed25519 host key"
    dropbearkey -t ed25519 -f "$ED25519_KEY_FILE" || ERROR_HANDLER ${LINENO}
    chmod 600 "$ED25519_KEY_FILE"
    MSG "SUCCESS: Ed25519 host key generated at $ED25519_KEY_FILE"
} || {
    MSG "INFO: Ed25519 host key already exists at $ED25519_KEY_FILE (use -f to force regeneration)"
}

# ファイル検証
PROGRESS "Verifying generated key files"
for key_file in "$RSA_KEY_FILE" "$ED25519_KEY_FILE"; do
    error_msg="Key file missing or empty: $key_file"
    [[ ! -f "$key_file" || ! -s "$key_file" ]] && ERROR_HANDLER ${LINENO}
    MSG "INFO: Key file verified: $key_file"
done

MSG "SUCCESS: SSH host key generation completed"