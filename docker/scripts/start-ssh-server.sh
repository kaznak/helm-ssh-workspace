#!/bin/bash
# NAME: start-ssh-server.sh
# SYNOPSIS: SSH workspace complete setup and startup script
# Design references: [see:B3Q8-PORT], [see:V4J1-HOSTKEY], [see:K2L8-HOSTVALID], [see:Y4F1-USER]

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
USER_UID="${SSH_UID:-1000}"
USER_GID="${SSH_GID:-1000}"
SSH_PORT="${SSH_PORT:-2222}"
HOME_DIR="/home/${USERNAME}"
SSH_DIR="${HOME_DIR}/.ssh"
DROPBEAR_DIR="${SSH_DIR}/dropbear"

PROGRESS "SSH Workspace Complete Setup"
MSG "Username: ${USERNAME}"
MSG "UID: ${USER_UID}"
MSG "GID: ${USER_GID}"
MSG "SSH Port: ${SSH_PORT}"
MSG "Home Directory: ${HOME_DIR}"
MSG "Dropbear Keys Directory: ${DROPBEAR_DIR}"

# Phase 1: User and Environment Setup (as root)
PROGRESS "Phase 1: User and Environment Setup"

# グループ作成
PROGRESS "Creating user and group"
MSG "Creating group ${USERNAME} with GID ${USER_GID}"
error_msg="Failed to create group ${USERNAME}"
groupadd -g "${USER_GID}" "${USERNAME}"

# ユーザ作成
MSG "Creating user ${USERNAME} with UID ${USER_UID}"
error_msg="Failed to create user ${USERNAME}"
# ホームディレクトリの存在確認
if [[ -d "${HOME_DIR}" ]] && [[ -n "$(ls -A "${HOME_DIR}" 2>/dev/null || true)" ]]; then
    MSG "Home directory exists with files, creating user without -m option"
    useradd -u "${USER_UID}" -g "${USER_GID}" -d "${HOME_DIR}" -s /bin/bash "${USERNAME}"
else
    MSG "Home directory empty or non-existent, creating user with -m option to copy skeleton files"
    useradd -u "${USER_UID}" -g "${USER_GID}" -d "${HOME_DIR}" -s /bin/bash -m "${USERNAME}"
fi

# SSHディレクトリ作成
PROGRESS "Creating SSH directories"
mkdir -p "${SSH_DIR}"
mkdir -p "${DROPBEAR_DIR}"

# SSHホストキーのコピー
PROGRESS "Setting up SSH host keys"

# RSA host key (必須)
PROGRESS "Copying RSA host key"
error_msg="RSA host key not found in /mnt/ssh-host-keys/rsa_host_key"
[[ -f /mnt/ssh-host-keys/rsa_host_key ]]
cp /mnt/ssh-host-keys/rsa_host_key "${DROPBEAR_DIR}/dropbear_rsa_host_key"
chmod 600 "${DROPBEAR_DIR}/dropbear_rsa_host_key"
MSG "RSA host key configured"

# Ed25519 host key (必須)
PROGRESS "Copying Ed25519 host key"
error_msg="Ed25519 host key not found in /mnt/ssh-host-keys/ed25519_host_key"
[[ -f /mnt/ssh-host-keys/ed25519_host_key ]]
cp /mnt/ssh-host-keys/ed25519_host_key "${DROPBEAR_DIR}/dropbear_ed25519_host_key"
chmod 600 "${DROPBEAR_DIR}/dropbear_ed25519_host_key"
MSG "Ed25519 host key configured"

# SSH公開鍵のコピー (必須)
PROGRESS "Setting up SSH public keys"
PROGRESS "Copying authorized_keys"
error_msg="Authorized keys not found in /mnt/ssh-public-keys/authorized_keys"
[[ -f /mnt/ssh-public-keys/authorized_keys ]]
cp /mnt/ssh-public-keys/authorized_keys "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"
MSG "Authorized keys configured"

# SSH秘密鍵のコピー (オプショナル)
PROGRESS "Setting up SSH private keys"
if [[ -d /mnt/ssh-private-keys ]] ; then
    ls /mnt/ssh-private-keys
    true
else
    MSG "INFO: No private keys directory found"
fi |
while read -r key_name; do
    PROGRESS "Copying private key: $key_name"
    cp "/mnt/ssh-private-keys/$key_name" "${SSH_DIR}/$key_name"
    chmod 600 "${SSH_DIR}/$key_name"
done

# ファイル所有権設定
PROGRESS "Setting file ownership"
error_msg="Failed to set file ownership"
chown -R "${USER_UID}:${USER_GID}" "${SSH_DIR}"

# ホームディレクトリの権限設定（Dropbearのセキュリティ要件）
PROGRESS "Setting home directory permissions for Dropbear security"
error_msg="Failed to set home directory permissions"
chown "${USER_UID}:${USER_GID}" "${HOME_DIR}"
chmod 755 "${HOME_DIR}"
MSG "Home directory permissions set to 755 for Dropbear requirements"

# セットアップ検証
PROGRESS "Setup Verification"
MSG "SSH directory contents:"
error_msg="SSH directory not accessible"
ls -la "${SSH_DIR}"
error_msg="Dropbear directory not accessible"
ls -la "${DROPBEAR_DIR}"

MSG "SUCCESS: SSH environment setup completed"

# Phase 2: Start SSH Server (as target user)
PROGRESS "Phase 2: SSH Server Startup"

# SSHキー存在確認
PROGRESS "Verifying SSH host keys"
RSA_KEY="${DROPBEAR_DIR}/dropbear_rsa_host_key"
ED25519_KEY="${DROPBEAR_DIR}/dropbear_ed25519_host_key"

error_msg="RSA host key not found at ${RSA_KEY}"
[[ -f "${RSA_KEY}" ]]

error_msg="Ed25519 host key not found at ${ED25519_KEY}"
[[ -f "${ED25519_KEY}" ]]

MSG "Host keys verified successfully"

# authorized_keys確認 (必須)
PROGRESS "Verifying authorized_keys"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
error_msg="Authorized keys not found at ${AUTHORIZED_KEYS}. SSH workspace requires valid authorized_keys for user authentication"
[[ -f "${AUTHORIZED_KEYS}" ]]
MSG "Authorized keys found at ${AUTHORIZED_KEYS}"

# Dropbear起動
PROGRESS "Switching to user ${USERNAME} (${USER_UID}:${USER_GID}) to start Dropbear"
MSG "Command: dropbear -F -E -p ${SSH_PORT} -r ${RSA_KEY} -r ${ED25519_KEY} -D ${SSH_DIR}"

# 指定ユーザでdropbear実行
error_msg="Failed to start Dropbear SSH server"
exec su -c "exec dropbear -F -E -p ${SSH_PORT} -r ${RSA_KEY} -r ${ED25519_KEY} -D ${SSH_DIR}" "${USERNAME}"