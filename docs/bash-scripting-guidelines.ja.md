# シェルスクリプト作成指針

## 基本構造
以下のテンプレートスタイルでシェルスクリプトを作成してください：

**参考テンプレート**: https://gist.githubusercontent.com/kaznak/56d450339dc9c154b96c04d9161676f6/raw/3c04209215a68419975d3c58d80560d1b38f634e/shellscript-template.sh

### 1. ヘッダー部分
```bash
#!/bin/bash
# NAME: スクリプト名
# SYNOPSIS: 使用方法の説明
# (必要に応じて他のドキュメント情報)
```

### 2. 厳格なbashオプション設定
```bash
set -Cu -Ee -o pipefail
shopt -s nullglob
```

### 3. 基本変数の初期化
```bash
stime=$(date +%Y%m%d%H%M%S%Z)  # 実行開始時刻
pname=$(basename $0)           # スクリプト名
based=$(readlink -f $(dirname $0)/..)  # ベースディレクトリ
tmpd=$(mktemp -d)             # 一時ディレクトリ
```

### 4. ログ出力設定
```bash
# ログディレクトリ作成
logd=$tmpd/log
mkdir -p $logd

# ファイルディスクリプタ3を冗長出力用として設定
exec 3>&2  # 冗長出力を表示する場合
# exec 3>/dev/null  # 冗長出力を抑制する場合

# デバッグ時は以下のコメントアウトを外す
# set -vx

# ログファイル出力時は以下のコメントアウトを外す
# exec 3>&2 2>$logd/$pname.$stime.$$.log
```

### 5. エラーハンドリング
```bash
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
```

### 6. ログ関数
```bash
MSG() { 
    printf '%s %s[%s]: %s\n' "$(date)" "$pname" "$$" "$*" >&3
}

PROGRESS() {
    MSG "PROGRESS(${BASH_LINENO[0]}): $*"
}
```

### 7. ヘルプ機能
```bash
print_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}
```

### 8. 中間処理結果のファイル管理
```bash
# 変数ではなく一時ファイルに中間結果を保存
grep "pattern" input.txt > "$tmpd/filtered.txt"
sort "$tmpd/filtered.txt" > "$tmpd/sorted.txt"
uniq "$tmpd/sorted.txt" > "$tmpd/result.txt"

# teeを使用してファイル出力とログ出力を同時実行（デバッグ時）
grep "pattern" input.txt | tee "$tmpd/filtered.txt" >&3
sort "$tmpd/filtered.txt" | tee "$tmpd/sorted.txt" >&3
uniq "$tmpd/sorted.txt" | tee "$tmpd/result.txt" >&3

# ファイルからデータを読み取って処理
while read line; do
    process "$line"
done < "$tmpd/result.txt"

# 複数のプロセスで同じデータを共有
wc -l < "$tmpd/result.txt" > "$tmpd/count.txt"
PROGRESS "処理対象: $(cat "$tmpd/count.txt") 行"
```

### 9. メイン処理の書き方
- **早期終了パターン**: `[[ 条件 ]] && exit 1`
- **エラーメッセージ事前設定**: 条件チェック前に `error_msg="メッセージ"` を設定
- **if-then-elseの入れ子は避ける**: 線形な上から下への処理フロー
- **バックグラウンド処理**: 必要に応じて子プロセスでエラーチェック
- **中間結果はファイル管理**: 大きなデータや複雑な処理結果は変数ではなく `$tmpd` 内のファイルに保存

### 10. 重要な原則
- プログラム的構造（複雑な関数、制御フロー）は避ける
- 上から下に読める線形構造
- trapによるエラーハンドリングとリソース管理
- MSG()/PROGRESS()によるログ出力
- 一時ファイル/ディレクトリの自動クリーンアップ

このスタイルでシェルスクリプトを作成してください。