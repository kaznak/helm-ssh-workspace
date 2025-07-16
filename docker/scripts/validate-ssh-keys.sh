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
    MSG "line:$1 ERROR status ${PIPESTATUS[@]}"
    [[ "$error_msg" ]] && MSG "$error_msg"
    touch "$tmpd/ERROR"    # for child process error detection
    MSG "line:$1 EXIT with error."
    exit 1        # root process trigger BEFORE_EXIT function
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
kubectl get secret "$host_secret" -n "$namespace" >&3

# Ensure /etc/dropbear directory exists
mkdir -p /etc/dropbear 2>/dev/null || true

# Extract and validate RSA host key
PROGRESS "Extracting RSA host key"
rm -f /etc/dropbear/dropbear_rsa_host_key
kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.rsa_host_key}' |
    base64 -d > /etc/dropbear/dropbear_rsa_host_key
chmod 600 /etc/dropbear/dropbear_rsa_host_key

temp_pub_key="$tmpd/rsa_host_pub"
error_msg="Cannot extract RSA public key from Dropbear key"
dropbearkey -y -f "/etc/dropbear/dropbear_rsa_host_key" |
    grep "^ssh-" > "$temp_pub_key"

key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
error_msg="Invalid RSA host key format"
[[ -n "$key_info" ]]

key_bits=$(echo "$key_info" | awk '{print $1}')
key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
error_msg="RSA host key is too weak ($key_bits bits). Minimum 2048 bits required"
[[ "$key_type" != "RSA" || "$key_bits" -ge 2048 ]]

MSG "INFO: Valid $key_type host key ($key_bits bits)"

# Extract and validate Ed25519 host key
PROGRESS "Extracting Ed25519 host key"
rm -f /etc/dropbear/dropbear_ed25519_host_key
kubectl get secret "$host_secret" -n "$namespace" -o jsonpath='{.data.ed25519_host_key}' |
    base64 -d > /etc/dropbear/dropbear_ed25519_host_key
chmod 600 /etc/dropbear/dropbear_ed25519_host_key

temp_pub_key="$tmpd/ed25519_host_pub"
error_msg="Cannot extract Ed25519 public key from Dropbear key"
dropbearkey -y -f "/etc/dropbear/dropbear_ed25519_host_key" |
    grep "^ssh-" > "$temp_pub_key"

key_info=$(ssh-keygen -lf "$temp_pub_key" 2>/dev/null)
error_msg="Invalid Ed25519 host key format"
[[ -n "$key_info" ]]

key_type=$(echo "$key_info" | awk '{print $NF}' | tr -d '()')
error_msg="Expected Ed25519 key, got $key_type"
[[ "$key_type" == "ED25519" ]]

MSG "INFO: Valid Ed25519 host key"

# Validate public keys from authorized_keys secret
PROGRESS "Validating authorized keys from secret"
error_msg="Public keys secret not found: $pub_secret"
kubectl get secret "$pub_secret" -n "$namespace" >&3

# Create user-specific SSH directory
mkdir -p /home/user/.ssh
chmod 700 /home/user/.ssh

# Extract authorized_keys
kubectl get secret "$pub_secret" -n "$namespace" -o jsonpath='{.data.authorized_keys}' |
    base64 -d > /home/user/.ssh/authorized_keys
chmod 600 /home/user/.ssh/authorized_keys

# Validate each line in authorized_keys using stream processing
# 前処理とファイル分割を直接パイプで接続
grep -vE '^[[:space:]]*($|#)' /home/user/.ssh/authorized_keys |
    awk '{
        filename = "'"$tmpd"'/auth_key_" NR
        print $0 > filename
        close(filename)
        print NR " " filename
    }' |
    while read -r line_number temp_pub_key; do
        error_msg="Invalid public key format at line $line_number"
        echo -n "$line_number "
        ssh-keygen -lf "$temp_pub_key"
    done |
# line_number key_bits fingerprint comment key_type
awk '
function MSG(level, msg) {
    print "'"$pname pid:$$ stime:$stime etime:$(date +%Y%m%d%H%M%S%Z) "'" level ": " msg > "/dev/fd/3"
}
$5=="(RSA)" && $2<2048 {
    MSG("ERROR", "RSA public key at line " $1 " is too weak (" $2 " bits). Minimum 2048 bits required")
    exit 1
}
$5=="(RSA)" && $2>=2048 && $2<4096 {
    MSG("WARNING", "RSA public key at line " $1 " is " $2 " bits. 4096 bits recommended")
    MSG("INFO", "Valid RSA public key (" $2 " bits) at line " $1)
    next
}
$5=="(RSA)" && $2>=4096 {
    MSG("INFO", "Valid RSA public key (" $2 " bits) at line " $1)
    next
}
$5=="(ED25519)" {
    MSG("INFO", "Ed25519 public key at line " $1 " is using recommended algorithm")
    MSG("INFO", "Valid ED25519 public key (256 bits) at line " $1)
    next
}
{
    MSG("ERROR", "Unsupported public key type " $5 " at line " $1 ". Only RSA and Ed25519 are supported")
    exit 1
}
'

# Validate private keys if provided
[[ -z "$priv_secret" ]] && {
    MSG "INFO: No private keys secret specified"
    MSG "SUCCESS: SSH key validation completed"
    exit 0
}

PROGRESS "Validating private keys from secret"

# Extract private keys data from secret
error_msg="Failed to extract private keys data from secret: $priv_secret"
kubectl get secret "$priv_secret" -n "$namespace" -o json |
    jq -r '.data' |
    tee "$tmpd/priv_keys_data.json" >&3

error_msg="Failed to validate private keys data format"
jq -r 'keys[]' "$tmpd/priv_keys_data.json" |
while read -r key_name ; do
    kfile="$tmpd/priv_keys_data.$key_name"

    error_msg="Failed to extract private key for $key_name"
    jq -r ".$key_name|@base64d" "$tmpd/priv_keys_data.json" |
        tee "$kfile" >&3

    pfile="$kfile.pub"
    ssh-keygen -y -f "$kfile" |
        tee "$pfile" >&3 || {
        # Check if the extracted data is actually a private key
        MSG "NOTICE Skipping $key_name - not a valid SSH private key"
        continue
    }

    ifile="$kfile.info"
    ssh-keygen -lf "$pfile" |
        tee "$ifile" >&3

    echo "$key_name" "$(cat "$ifile")"
done |
awk '
function MSG(level, msg) {
    print "'"$pname pid:$$ stime:$stime etime:$(date +%Y%m%d%H%M%S%Z) "'" level ": " msg > "/dev/fd/3"
}
{ 
    key_name = $1; key_bits = $2; fingerprint = $3; comment = $4 ; key_type = $NF
}
key_type == "(RSA)" && key_bits < 2048 {
    MSG("ERROR", "RSA private key " key_name " is too weak (" key_bits " bits). Minimum 2048 bits required")
    exit 1
}
key_type == "(RSA)" && key_bits >= 2048 && key_bits < 4096 {
    MSG("WARNING", "RSA private key " key_name " is " key_bits " bits. 4096 bits recommended")
    MSG("INFO", "Valid RSA private key " key_name " (" key_bits " bits)")
    next
}
key_type == "(RSA)" && key_bits >= 4096 {
    MSG("INFO", "Valid RSA private key " key_name " (" key_bits " bits)")
    next
}
key_type == "(ED25519)" {
    MSG("INFO", "Ed25519 private key " key_name " is using recommended algorithm")
    MSG("INFO", "Valid ED25519 private key " key_name " (256 bits)")
    next
}
{
    MSG("ERROR", "Unsupported private key type " key_type " for " key_name ". Only RSA and Ed25519 are supported")
    exit 1
}
'

MSG "SUCCESS: SSH key validation completed"