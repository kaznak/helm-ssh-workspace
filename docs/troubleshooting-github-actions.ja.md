# GitHub Actions トラブルシューティングガイド

## 概要

このドキュメントは、helm-ssh-workspace プロジェクトで発生した GitHub Actions のエラーと、その解決方法について記録したものです。

## 発生した問題

2025年7月1日、GitHub Actions のすべてのワークフローが失敗する問題が発生しました。

### 影響を受けたワークフロー

- CI/CD Pipeline
- Build and Push Docker Image  
- Release Helm Chart
- Security Scan
- GitHub Pages Helm Repository

## エラーの詳細と解決方法

### 1. Helm Chart スキーマ検証エラー

#### エラーメッセージ
```
Error: 1 chart(s) linted, 1 chart(s) failed
==> Linting helm/ssh-workspace
[ERROR] values.yaml: 
- user.name: String length must be greater than or equal to 1
- user.name: Does not match pattern '^[a-z_][a-z0-9_-]*$'
- ssh.publicKeys: Array must have at least 1 items
```

#### 原因
`values.schema.json` で定義された制約と、`values.yaml` のデフォルト値が矛盾していました：

**values.yaml の問題箇所:**
```yaml
user:
  name: ""  # 空文字列
ssh:
  publicKeys: []  # 空配列
```

**values.schema.json の制約:**
```json
"user": {
  "name": {
    "minLength": 1,
    "pattern": "^[a-z_][a-z0-9_-]*$"
  }
},
"ssh": {
  "publicKeys": {
    "minItems": 1
  }
}
```

#### 解決方法
ワークフローで `helm lint` 実行時にテスト値を提供するように修正：

```yaml
- name: Lint Helm Chart
  run: |
    helm lint helm/ssh-workspace \
      --set user.name="testuser" \
      --set 'ssh.publicKeys[0]=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example.com'
```

**注意点:** 配列値を設定する際は、シングルクォートで囲む必要があります。

### 2. Docker ビルドステップの ID 欠落

#### エラーメッセージ
```
Error: Unrecognized named-value: 'steps'. Located at position 1 within expression: steps.build.outputs.digest
```

#### 原因
Docker ビルドステップに `id` が設定されていなかったため、後続のステップから参照できませんでした。

#### 解決方法
```yaml
- name: Build and push Docker image
  id: build  # この行を追加
  uses: docker/build-push-action@v5
```

### 3. Docker Attestation の権限エラー

#### エラーメッセージ
```
Error: Failed to persist attestation: Resource not accessible by integration
```

#### 原因
GitHub Actions のジョブに `attestations: write` 権限が不足していました。

#### 解決方法
```yaml
jobs:
  build:
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write  # この行を追加
```

### 4. Helm Release バージョン処理の不具合

#### 問題
バージョン更新の条件判定が不適切で、期待通りに動作しませんでした。

#### 解決方法
明示的なフラグを使用した条件判定に変更：

```yaml
- name: Set Chart Version
  id: version
  run: |
    if [ "${{ github.event.inputs.chart_version }}" != "auto" ] && [ -n "${{ github.event.inputs.chart_version }}" ]; then
      CHART_VERSION="${{ github.event.inputs.chart_version }}"
      UPDATE_NEEDED=true
    elif [[ $GITHUB_REF == refs/tags/* ]]; then
      CHART_VERSION=${GITHUB_REF#refs/tags/v}
      UPDATE_NEEDED=true
    else
      CHART_VERSION=$(yq eval '.version' helm/ssh-workspace/Chart.yaml)
      UPDATE_NEEDED=false
    fi
    echo "update_needed=${UPDATE_NEEDED}" >> $GITHUB_OUTPUT

- name: Update Chart Version
  if: steps.version.outputs.update_needed == 'true'
```

## 設計上の考慮事項

### values.yaml のデフォルト値について

このプロジェクトでは、意図的に `values.yaml` の必須フィールドを空にしています：

- **理由**: ユーザーに必須値の設定を強制するため
- **影響**: CI/CD でのテスト時には明示的に値を指定する必要がある
- **利点**: ユーザーが設定を忘れることを防ぐ

### 推奨される対処法

1. **開発時**: `helm lint` 実行時は `--set` で値を指定
2. **本番使用時**: 専用の values ファイルを作成して使用
3. **CI/CD**: ワークフロー内でテスト用の値を明示的に設定

## まとめ

これらの問題は、以下の要因の組み合わせで発生しました：

1. 厳密なスキーマ検証と空のデフォルト値の組み合わせ
2. GitHub Actions の権限設定の不足
3. ワークフロー間の依存関係の考慮不足

すべての修正を適用することで、GitHub Actions は正常に動作するようになりました。

## 参考リンク

- [GitHub Actions permissions documentation](https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs)
- [Helm lint documentation](https://helm.sh/docs/helm/helm_lint/)
- [Docker build-push-action documentation](https://github.com/docker/build-push-action)