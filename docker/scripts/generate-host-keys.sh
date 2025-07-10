#!/bin/bash
# NAME: generate-host-keys.sh
# SYNOPSIS: SSH host key generation script
# 
# USAGE:
#     generate-host-keys.sh <namespace> <secret_name>
#     generate-host-keys.sh [-h|--help]
#
# OPTIONS:
#     -h, --help     Show this help message
#
# DESCRIPTION:
#     Generate SSH host keys and create Kubernetes secret
#
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
    echo "$pname pid:$$ stime:$stime etime:$(date +%Y%m%d%H%M%S%Z) $@" >&3
}

PROGRESS() {
    MSG "PROGRESS(${BASH_LINENO[0]}): $*"
}

# ヘルプ機能
print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

# 設定
RSA_KEY_SIZE=4096
HOST_KEY_DIR="/etc/dropbear"
RSA_KEY_FILE="${HOST_KEY_DIR}/dropbear_rsa_host_key"
ED25519_KEY_FILE="${HOST_KEY_DIR}/dropbear_ed25519_host_key"

# メイン処理開始
PROGRESS "Starting SSH host key generation"

# ヘルプ処理または引数数チェック
if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
    print_help
    exit 0
elif [[ $# -ne 2 ]]; then
    print_help
    exit 1
fi

# 引数取得
namespace="$1"
secret_name="$2"

# ディレクトリ作成
mkdir -p "$HOST_KEY_DIR"
PROGRESS "Kubernetes SSH Host Key Generation"
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
dropbearkey -t rsa -s "$RSA_KEY_SIZE" -f "$RSA_KEY_FILE"
chmod 600 "$RSA_KEY_FILE"

# RSA鍵ファイル検証
error_msg="RSA key file missing or empty: $RSA_KEY_FILE"
[[ -s "$RSA_KEY_FILE" ]]
MSG "SUCCESS: RSA host key generated and verified at $RSA_KEY_FILE"

# Ed25519鍵生成
PROGRESS "Generating Ed25519 host key"
error_msg="Failed to generate Ed25519 host key"
dropbearkey -t ed25519 -f "$ED25519_KEY_FILE"
chmod 600 "$ED25519_KEY_FILE"

# Ed25519鍵ファイル検証
error_msg="Ed25519 key file missing or empty: $ED25519_KEY_FILE"
[[ -s "$ED25519_KEY_FILE" ]]
MSG "SUCCESS: Ed25519 host key generated and verified at $ED25519_KEY_FILE"

# Secret作成
PROGRESS "Creating Kubernetes secret: $secret_name"
error_msg="Failed to create Kubernetes secret"
kubectl create secret generic "$secret_name" \
    --from-file=rsa_host_key="$RSA_KEY_FILE" \
    --from-file=ed25519_host_key="$ED25519_KEY_FILE" \
    -n "$namespace"

# リソースポリシー注釈追加 [R8N9-REUSE]
error_msg="Failed to add resource policy annotation"
kubectl annotate secret "$secret_name" \
    "helm.sh/resource-policy=keep" \
    -n "$namespace"

MSG "SUCCESS: SSH host keys secret created successfully: $secret_name"