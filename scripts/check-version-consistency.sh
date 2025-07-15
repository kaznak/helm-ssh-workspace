#!/bin/bash
# NAME: check-version-consistency.sh
# SYNOPSIS: バージョン番号整合性チェックスクリプト
# DESCRIPTION: プロジェクト内の複数箇所に記載されたバージョン番号の整合性をチェック

set -Cu -Ee -o pipefail
shopt -s nullglob

stime=$(date +%Y%m%d%H%M%S%Z)
pname=$(basename $0)
based=$(readlink -f $(dirname $0)/..)
tmpd=$(mktemp -d)

logd=$tmpd/log
mkdir -p $logd

exec 3>&2

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

MSG() { 
    echo "$pname pid:$$ stime:$stime etime:$(date +%Y%m%d%H%M%S%Z) $@" >&3
}

PROGRESS() {
    MSG "PROGRESS(${BASH_LINENO[0]}): $*"
}

print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

# ヘルプ表示処理
[[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]] && {
    print_help
    exit 0
}

PROGRESS "バージョン番号抽出"

error_msg="Failed to extract Helm Chart version"
grep '^version:' "$based/helm/Chart.yaml" |
sed 's/version: *//g' |
# バージョン種別を付与
sed 's/$/ Helm Chart version/' |
tee -a "$tmpd/version_summary.txt" >&3

error_msg="Failed to extract Helm App version"
grep '^appVersion:' "$based/helm/Chart.yaml" |
sed 's/appVersion: *"*//g' |
sed 's/"*$//g' |
# バージョン種別を付与
sed 's/$/ Helm App version/' |
tee -a "$tmpd/version_summary.txt" >&3

error_msg="Failed to extract Helm image tag"
grep '  tag:' "$based/helm/values.yaml" |
sed 's/.*tag: *"*//g' | sed 's/"*$//g' | sed 's/^v//g' |
# バージョン種別を付与
sed 's/$/ Helm image tag/' |
tee -a "$tmpd/version_summary.txt" >&3

error_msg="Failed to extract README version"
grep -- '--version' "$based/README.md" |
sed 's/.*--version *//g' |
sed 's/ .*//g' |
# バージョン種別を付与
sed 's/$/ README version/' |
tee -a "$tmpd/version_summary.txt" >&3

PROGRESS "不整合チェック"

awk -F' ' '{print $1}' "$tmpd/version_summary.txt" |
sort -u |
wc -l |
tee "$logd/version_count.txt" >&3
error_msg="ERROR ❌ バージョン番号が一致していません"
[ $(cat "$logd/version_count.txt") -eq 1 ]

MSG "INFO ✅ すべてのバージョン番号が一致しています"
exit 0
