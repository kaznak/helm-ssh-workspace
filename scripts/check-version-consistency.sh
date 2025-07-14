#!/bin/bash
# [P3R8-VERSION] バージョン番号整合性チェックスクリプト

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# バージョン番号を抽出する関数
extract_helm_chart_version() {
    grep '^version:' "${PROJECT_ROOT}/helm/Chart.yaml" | sed 's/version: *//g'
}

extract_helm_app_version() {
    grep '^appVersion:' "${PROJECT_ROOT}/helm/Chart.yaml" | sed 's/appVersion: *"*//g' | sed 's/"*$//g'
}

extract_helm_image_tag() {
    grep '  tag:' "${PROJECT_ROOT}/helm/values.yaml" | sed 's/.*tag: *"*//g' | sed 's/"*$//g' | sed 's/^v//g'
}

extract_readme_version() {
    grep -- '--version' "${PROJECT_ROOT}/README.md" | sed 's/.*--version *//g' | sed 's/ .*//g'
}

# メイン処理
main() {
    echo "=== バージョン番号整合性チェック ==="
    
    local helm_chart_version helm_app_version helm_image_tag readme_version
    local exit_code=0
    
    helm_chart_version=$(extract_helm_chart_version)
    helm_app_version=$(extract_helm_app_version)
    helm_image_tag=$(extract_helm_image_tag)
    readme_version=$(extract_readme_version)
    
    echo "Helm Chart version: ${helm_chart_version}"
    echo "Helm App version: ${helm_app_version}"
    echo "Helm image tag: ${helm_image_tag}"
    echo "README version: ${readme_version}"
    echo
    
    # バージョン整合性チェック
    if [[ "${helm_chart_version}" != "${helm_app_version}" ]]; then
        echo "❌ ERROR: Helm Chart version (${helm_chart_version}) != App version (${helm_app_version})"
        exit_code=1
    fi
    
    if [[ "${helm_app_version}" != "${helm_image_tag}" ]]; then
        echo "❌ ERROR: Helm App version (${helm_app_version}) != Image tag (${helm_image_tag})"
        exit_code=1
    fi
    
    if [[ "${helm_app_version}" != "${readme_version}" ]]; then
        echo "❌ ERROR: Helm App version (${helm_app_version}) != README version (${readme_version})"
        exit_code=1
    fi
    
    if [[ ${exit_code} -eq 0 ]]; then
        echo "✅ すべてのバージョン番号が一致しています"
    fi
    
    exit ${exit_code}
}

main "$@"