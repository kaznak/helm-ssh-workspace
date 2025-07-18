#!/bin/bash
# Init script for ConfigMap-based user management
# [see:U4N8-USERDB] ConfigMap-based user database initialization
#
# USAGE:
#     init-users.sh <target_etc_path>
#
# ARGUMENTS:
#     target_etc_path    Target directory for /etc files

set -Cu -Ee -o pipefail

# 基本変数の初期化
stime=$(date +%Y%m%d%H%M%S%Z)
pname=$(basename "$0")
tmpd=$(mktemp -d)

# Logging functions
MSG() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
PROGRESS() { MSG "PROGRESS: $*"; }
ERROR() { MSG "ERROR: $*"; }

# Error handling
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

# Parse command line arguments
ETC_SOURCE="/etc"
ETC_TARGET="$1"

# Help option
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
fi

# Validate arguments
error_msg="Target /etc path is required. Usage: init-users.sh <target_etc_path>"
[[ $# -eq 1 ]]

# Validate that source and target are different
error_msg="Source and target paths cannot be the same. Source: $ETC_SOURCE, Target: $ETC_TARGET"
[[ "$ETC_SOURCE" != "$ETC_TARGET" ]]

# Configuration
USER_CONFIG_DIR="${USER_CONFIG_DIR:-/config/users}"
BACKUP_SUFFIX=".backup-$(date +%s)"

PROGRESS "Starting ConfigMap-based user database initialization"
MSG "ETC_TARGET: $ETC_TARGET"
MSG "ETC_SOURCE: $ETC_SOURCE"
MSG "USER_CONFIG_DIR: $USER_CONFIG_DIR"

# Validate input files
error_msg="User config directory not found: $USER_CONFIG_DIR"
[[ -d "$USER_CONFIG_DIR" ]]

for file in passwd group shadow; do
    error_msg="Required user config file not found: $USER_CONFIG_DIR/$file"
    [[ -f "$USER_CONFIG_DIR/$file" ]]
done

# Check for optional subuid/subgid files for container tools
# Check subuid file exists
error_msg="Optional file check failed: $USER_CONFIG_DIR/subuid"
[[ -f "$USER_CONFIG_DIR/subuid" ]] && MSG "Found: $USER_CONFIG_DIR/subuid" || MSG "Optional file: $USER_CONFIG_DIR/subuid (will be created if needed)"

# Check subgid file exists
error_msg="Optional file check failed: $USER_CONFIG_DIR/subgid"
[[ -f "$USER_CONFIG_DIR/subgid" ]] && MSG "Found: $USER_CONFIG_DIR/subgid" || MSG "Optional file: $USER_CONFIG_DIR/subgid (will be created if needed)"

error_msg=""

# Initialize target /etc files by copying from source (required for emptyDir)
PROGRESS "Initializing target /etc files by copying from source"
MSG "Copying base system files from $ETC_SOURCE to $ETC_TARGET"

# Create target directory if it doesn't exist
mkdir -p "$ETC_TARGET"

# Copy base system files - fail immediately if source doesn't exist
for file in passwd group shadow; do
    error_msg="Source file $ETC_SOURCE/$file not found - cannot initialize"
    [[ -f "$ETC_SOURCE/$file" ]]
    
    error_msg="Failed to copy $file from $ETC_SOURCE to $ETC_TARGET"
    cp "$ETC_SOURCE/$file" "$ETC_TARGET/$file"
    MSG "Copied $ETC_SOURCE/$file to $ETC_TARGET/$file"
done


MSG "Base system files initialized in $ETC_TARGET"

# Backup existing files
PROGRESS "Backing up existing user database files"
for file in passwd group shadow; do
    target_file="$ETC_TARGET/$file"
    error_msg="Failed to backup $target_file"
    cp "$target_file" "${target_file}${BACKUP_SUFFIX}"
    MSG "Backed up $target_file to ${target_file}${BACKUP_SUFFIX}"
done

# Merge user database files
PROGRESS "Merging ConfigMap user data with existing system users"

# Merge passwd file
PROGRESS "Processing $USER_CONFIG_DIR/passwd -> $ETC_TARGET/passwd"
error_msg="Failed to merge and sort $ETC_TARGET/passwd and $USER_CONFIG_DIR/passwd"
cat "$ETC_TARGET/passwd" "$USER_CONFIG_DIR/passwd" |
    sort -t: -k3,3n > "$ETC_TARGET/passwd.tmp"

# Check for duplicate usernames (field 1)
duplicates_file="$ETC_TARGET/passwd.tmp.duplicates.username"
cut -d: -f1 "$ETC_TARGET/passwd.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^" $1 ":"}' |
    { grep -f - "$ETC_TARGET/passwd.tmp" || true; } |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate usernames found in $ETC_TARGET/passwd"
[[ ! -s "$duplicates_file" ]]
error_msg=""

# Check for duplicate UIDs (field 3)
duplicates_file="$ETC_TARGET/passwd.tmp.duplicates.uid"
cut -d: -f3 "$ETC_TARGET/passwd.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^[^:]*:[^:]*:" $1 ":"}' |
    { grep -f - "$ETC_TARGET/passwd.tmp" || true; } |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate UIDs found in $ETC_TARGET/passwd"
[[ ! -s "$duplicates_file" ]]
error_msg=""

# Replace original file
error_msg="Failed to replace $ETC_TARGET/passwd"
mv "$ETC_TARGET/passwd.tmp" "$ETC_TARGET/passwd"
MSG "Successfully merged $ETC_TARGET/passwd"

# Merge group file
PROGRESS "Processing $USER_CONFIG_DIR/group -> $ETC_TARGET/group"
error_msg="Failed to merge and sort $ETC_TARGET/group and $USER_CONFIG_DIR/group"
cat "$ETC_TARGET/group" "$USER_CONFIG_DIR/group" |
    sort -t: -k3,3n > "$ETC_TARGET/group.tmp"

# Check for duplicate group names (field 1)
duplicates_file="$ETC_TARGET/group.tmp.duplicates.groupname"
cut -d: -f1 "$ETC_TARGET/group.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^" $1 ":"}' |
    { grep -f - "$ETC_TARGET/group.tmp" || true; } |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate group names found in $ETC_TARGET/group"
[[ ! -s "$duplicates_file" ]]
error_msg=""

# Check for duplicate GIDs (field 3)
duplicates_file="$ETC_TARGET/group.tmp.duplicates.gid"
cut -d: -f3 "$ETC_TARGET/group.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^[^:]*:[^:]*:" $1 ":"}' |
    { grep -f - "$ETC_TARGET/group.tmp" || true; } |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate GIDs found in $ETC_TARGET/group"
[[ ! -s "$duplicates_file" ]]
error_msg=""

# Replace original file
error_msg="Failed to replace $ETC_TARGET/group"
mv "$ETC_TARGET/group.tmp" "$ETC_TARGET/group"
MSG "Successfully merged $ETC_TARGET/group"

# Merge shadow file
PROGRESS "Processing $USER_CONFIG_DIR/shadow -> $ETC_TARGET/shadow"
error_msg="Failed to merge and sort $ETC_TARGET/shadow and $USER_CONFIG_DIR/shadow"
cat "$ETC_TARGET/shadow" "$USER_CONFIG_DIR/shadow" |
    sort -t: -k1,1 > "$ETC_TARGET/shadow.tmp"

# Check for duplicate usernames (field 1) - shadow has no UID/GID fields
duplicates_file="$ETC_TARGET/shadow.tmp.duplicates.username"
cut -d: -f1 "$ETC_TARGET/shadow.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^" $1 ":"}' |
    { grep -f - "$ETC_TARGET/shadow.tmp" || true; } |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate usernames found in $ETC_TARGET/shadow"
[[ ! -s "$duplicates_file" ]]
error_msg=""

# Replace original file
error_msg="Failed to replace $ETC_TARGET/shadow"
mv "$ETC_TARGET/shadow.tmp" "$ETC_TARGET/shadow"
MSG "Successfully merged $ETC_TARGET/shadow"

# Merge subuid/subgid files for container tools
# Merge subuid file
PROGRESS "Processing $USER_CONFIG_DIR/subuid -> $ETC_TARGET/subuid"
error_msg="Failed to merge subuid file"
cp "$ETC_SOURCE/subuid" "$ETC_TARGET/subuid" || true
cat "$USER_CONFIG_DIR/subuid" >> "$ETC_TARGET/subuid" || true
MSG "Successfully merged $ETC_TARGET/subuid"

# Merge subgid file
PROGRESS "Processing $USER_CONFIG_DIR/subgid -> $ETC_TARGET/subgid"
error_msg="Failed to merge subgid file"
cp "$ETC_SOURCE/subgid" "$ETC_TARGET/subgid" || true
cat "$USER_CONFIG_DIR/subgid" >> "$ETC_TARGET/subgid" || true
MSG "Successfully merged $ETC_TARGET/subgid"

# Set proper permissions
PROGRESS "Setting proper file permissions"
error_msg="Failed to set file permissions"
chmod 644 $ETC_TARGET/passwd $ETC_TARGET/group
chmod 600 $ETC_TARGET/shadow

# Setup skeleton files for container tools
PROGRESS "Setting up skeleton files for container tools"
error_msg="Failed to setup skeleton files"

MSG "Setting up container tools skeleton files"

# Initialize skeleton directory with base files
cp -r /etc/skel-orig/. /etc/skel/

# Create skeleton directories
mkdir -p /etc/skel/.bashrc.d /etc/skel/.local/bin

# Copy container tools configuration files from templates
cp /opt/ssh-workspace/templates/skel/.bashrc.d/podman.sh /etc/skel/.bashrc.d/podman.sh
cp /opt/ssh-workspace/templates/skel/.local/bin/docker /etc/skel/.local/bin/docker
chmod +x /etc/skel/.local/bin/docker

# Append container tools configuration to bashrc
cat /opt/ssh-workspace/templates/skel/bashrc.append >> /etc/skel/.bashrc

MSG "Container tools skeleton files configured"

# Validate the merged files
PROGRESS "Validating merged user database files"

error_msg="User lookup failed"
cut -d: -f1 "$USER_CONFIG_DIR/passwd"   |
awk '{print "^" $1 ":"}' |
xargs -r -I% grep -q % "$ETC_TARGET/passwd"

error_msg="Group lookup failed"
cut -d: -f1 "$USER_CONFIG_DIR/group"   |
awk '{print "^" $1 ":"}' |
xargs -r -I% grep -q % "$ETC_TARGET/group"

PROGRESS "ConfigMap-based user database initialization completed successfully"

# Display summary
MSG "User database summary:"
MSG "- Users added: $(wc -l < "$USER_CONFIG_DIR/passwd") entries"
MSG "- Groups added: $(wc -l < "$USER_CONFIG_DIR/group") entries"
MSG "- Total system users: $(wc -l < $ETC_TARGET/passwd) entries"
MSG "- Total system groups: $(wc -l < $ETC_TARGET/group) entries"

# Set up home directory ownership (required for emptyDir volumes)
PROGRESS "Setting up home directory ownership for SSH user"
error_msg="Failed to setup home directory ownership"

# Get user info from ConfigMap
SSH_USERNAME="${SSH_USERNAME:-developer}"
SSH_UID="${SSH_UID:-1000}"
SSH_GID="${SSH_GID:-1000}"
HOME_DIR="/home/${SSH_USERNAME}"

MSG "Setting up home directory for user: ${SSH_USERNAME} (${SSH_UID}:${SSH_GID})"
MSG "Home directory path: ${HOME_DIR}"

# Set ownership to the SSH user (init container runs as root)
chown "${SSH_UID}:${SSH_GID}" "${HOME_DIR}"
MSG "Set home directory ownership to ${SSH_UID}:${SSH_GID}"


# Clear error message on success
error_msg=""