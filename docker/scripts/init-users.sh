#!/bin/bash
# Init script for ConfigMap-based user management
# [see:U4N8-USERDB] ConfigMap-based user database initialization

set -Cu -Ee -o pipefail

# Logging functions
MSG() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
PROGRESS() { MSG "PROGRESS: $*"; }
ERROR() { MSG "ERROR: $*"; }

# Error handling
error_msg=""
cleanup() {
    if [[ -n "$error_msg" ]]; then
        ERROR "$error_msg"
        exit 1
    fi
}
trap cleanup EXIT

# Configuration
USER_CONFIG_DIR="${USER_CONFIG_DIR:-/config/users}"
BACKUP_SUFFIX=".backup-$(date +%s)"

PROGRESS "Starting ConfigMap-based user database initialization"

# Validate input files
error_msg="User config directory not found: $USER_CONFIG_DIR"
[[ -d "$USER_CONFIG_DIR" ]]

for file in passwd group shadow; do
    error_msg="Required user config file not found: $USER_CONFIG_DIR/$file"
    [[ -f "$USER_CONFIG_DIR/$file" ]]
done

# Backup existing files
PROGRESS "Backing up existing user database files"
for file in /etc/passwd /etc/group /etc/shadow; do
    error_msg="Failed to backup $file"
    cp "$file" "${file}${BACKUP_SUFFIX}"
    MSG "Backed up $file to ${file}${BACKUP_SUFFIX}"
done

# Merge user database files
PROGRESS "Merging ConfigMap user data with existing system users"

# Merge passwd file
PROGRESS "Processing $USER_CONFIG_DIR/passwd -> /etc/passwd"
error_msg="Failed to merge and sort /etc/passwd and $USER_CONFIG_DIR/passwd"
cat "/etc/passwd" "$USER_CONFIG_DIR/passwd" |
    sort -t: -k1,1 > "/etc/passwd.tmp"

# Check for duplicate usernames (field 1)
duplicates_file="/etc/passwd.tmp.duplicates.username"
cut -d: -f1 "/etc/passwd.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^" $1 ":"}' |
    grep -f - "/etc/passwd.tmp" |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate usernames found in /etc/passwd"
[[ ! -s "$duplicates_file" ]]

# Check for duplicate UIDs (field 3)
duplicates_file="/etc/passwd.tmp.duplicates.uid"
cut -d: -f3 "/etc/passwd.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^[^:]*:[^:]*:" $1 ":"}' |
    grep -f - "/etc/passwd.tmp" |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate UIDs found in /etc/passwd"
[[ ! -s "$duplicates_file" ]]

# Replace original file
error_msg="Failed to replace /etc/passwd"
mv "/etc/passwd.tmp" "/etc/passwd"
MSG "Successfully merged /etc/passwd"

# Merge group file
PROGRESS "Processing $USER_CONFIG_DIR/group -> /etc/group"
error_msg="Failed to merge and sort /etc/group and $USER_CONFIG_DIR/group"
cat "/etc/group" "$USER_CONFIG_DIR/group" |
    sort -t: -k1,1 > "/etc/group.tmp"

# Check for duplicate group names (field 1)
duplicates_file="/etc/group.tmp.duplicates.groupname"
cut -d: -f1 "/etc/group.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^" $1 ":"}' |
    grep -f - "/etc/group.tmp" |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate group names found in /etc/group"
[[ ! -s "$duplicates_file" ]]

# Check for duplicate GIDs (field 3)
duplicates_file="/etc/group.tmp.duplicates.gid"
cut -d: -f3 "/etc/group.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^[^:]*:[^:]*:" $1 ":"}' |
    grep -f - "/etc/group.tmp" |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate GIDs found in /etc/group"
[[ ! -s "$duplicates_file" ]]

# Replace original file
error_msg="Failed to replace /etc/group"
mv "/etc/group.tmp" "/etc/group"
MSG "Successfully merged /etc/group"

# Merge shadow file
PROGRESS "Processing $USER_CONFIG_DIR/shadow -> /etc/shadow"
error_msg="Failed to merge and sort /etc/shadow and $USER_CONFIG_DIR/shadow"
cat "/etc/shadow" "$USER_CONFIG_DIR/shadow" |
    sort -t: -k1,1 > "/etc/shadow.tmp"

# Check for duplicate usernames (field 1) - shadow has no UID/GID fields
duplicates_file="/etc/shadow.tmp.duplicates.username"
cut -d: -f1 "/etc/shadow.tmp" |
    sort |
    uniq -d |
    tee "$duplicates_file" |
    awk '{print "^" $1 ":"}' |
    grep -f - "/etc/shadow.tmp" |
    sed 's/^/ERROR   - /' >&2

# Check if duplicates were found and handle error
error_msg="Duplicate usernames found in /etc/shadow"
[[ ! -s "$duplicates_file" ]]

# Replace original file
error_msg="Failed to replace /etc/shadow"
mv "/etc/shadow.tmp" "/etc/shadow"
MSG "Successfully merged /etc/shadow"

# Set proper permissions
PROGRESS "Setting proper file permissions"
error_msg="Failed to set file permissions"
chmod 644 /etc/passwd /etc/group
chmod 600 /etc/shadow

# Validate the merged files
PROGRESS "Validating merged user database files"
error_msg="User database validation failed"

# Test getent functionality
for file_user in $(cut -d: -f1 "$USER_CONFIG_DIR/passwd"); do
    if ! getent passwd "$file_user" >/dev/null 2>&1; then
        error_msg="User lookup failed for: $file_user"
        exit 1
    fi
    MSG "Validated user: $file_user"
done

for file_group in $(cut -d: -f1 "$USER_CONFIG_DIR/group"); do
    if ! getent group "$file_group" >/dev/null 2>&1; then
        error_msg="Group lookup failed for: $file_group"
        exit 1
    fi
    MSG "Validated group: $file_group"
done

PROGRESS "ConfigMap-based user database initialization completed successfully"

# Display summary
MSG "User database summary:"
MSG "- Users added: $(wc -l < "$USER_CONFIG_DIR/passwd") entries"
MSG "- Groups added: $(wc -l < "$USER_CONFIG_DIR/group") entries"
MSG "- Total system users: $(wc -l < /etc/passwd) entries"
MSG "- Total system groups: $(wc -l < /etc/group) entries"

# Clear error message on success
error_msg=""