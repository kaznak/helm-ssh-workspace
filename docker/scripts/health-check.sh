#!/bin/bash
# NAME: health-check.sh
# SYNOPSIS: Health check script for SSH workspace
# Design reference: [R6Q9-READINESS]

set -Cu -Ee -o pipefail
shopt -s nullglob

# 基本変数の初期化
stime=$(date +%Y%m%d%H%M%S%Z)
pname=$(basename "$0")
tmpd=$(mktemp -d)

# ログ出力設定
logd="$tmpd/log"
mkdir -p "$logd"
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
    echo "$pname pid:$$ stime:$stime etime:$(date +%Y%m%d%H%M%S%Z) $*" >&3
}

PROGRESS() {
    MSG "PROGRESS(${BASH_LINENO[0]}): $*"
}

# ヘルプ機能
print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

# 設定
USERNAME="${SSH_USERNAME:-developer}"
SSH_PORT="${SSH_PORT:-2222}"
DROPBEAR_DIR="/home/${USERNAME}/.ssh/dropbear"

PROGRESS "Starting SSH workspace health check"

# Dropbearプロセスチェック
PROGRESS "Checking Dropbear SSH server process"
error_msg="Dropbear SSH server process not found"
pgrep dropbear >&3
MSG "INFO: Dropbear SSH server process is running"

# SSHポートリスニングチェック
PROGRESS "Checking SSH port ${SSH_PORT} listening status"
error_msg="SSH port ${SSH_PORT} is not listening"
ss -ln | grep -q ":${SSH_PORT} "
MSG "INFO: SSH port ${SSH_PORT} is listening"

# RSAホストキー存在チェック
PROGRESS "Checking RSA host key file"
error_msg="RSA host key not found at ${DROPBEAR_DIR}/dropbear_rsa_host_key"
[[ -f "${DROPBEAR_DIR}/dropbear_rsa_host_key" ]]
MSG "INFO: RSA host key found at ${DROPBEAR_DIR}/dropbear_rsa_host_key"

# Ed25519ホストキー存在チェック
PROGRESS "Checking Ed25519 host key file"
error_msg="Ed25519 host key not found at ${DROPBEAR_DIR}/dropbear_ed25519_host_key"
[[ -f "${DROPBEAR_DIR}/dropbear_ed25519_host_key" ]]
MSG "INFO: Ed25519 host key found at ${DROPBEAR_DIR}/dropbear_ed25519_host_key"

MSG "SUCCESS: SSH workspace health check passed"