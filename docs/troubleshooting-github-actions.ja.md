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
4. Pre-installフックでのネットワーク依存とパッケージ管理の問題
5. 無効なテストデータ（SSH公開鍵）の使用
6. ワークフロー修正時の部分的な置換による不整合

## 教訓

### CI/CD設計時の注意点
- **ネットワーク依存の最小化**: 外部パッケージのダウンロードを避け、必要な機能が既に含まれるイメージを使用
- **テストデータの品質**: 実際の本番データと同じ形式・制約を満たすテストデータを使用
- **設定の一元化**: 同じ値を複数箇所で使用する場合は環境変数やテンプレート化を検討

### トラブルシューティングのアプローチ
1. **段階的なデバッグ**: 詳細なログ出力を追加して問題箇所を特定
2. **根本原因の追求**: 表面的な症状ではなく、根本的な原因を特定
3. **包括的な修正確認**: 一括置換や修正後は全体を確認

すべての修正を適用することで、GitHub Actions は正常に動作するようになりました。

### 5. Helm Template の --validate フラグエラー

#### エラーメッセージ
```
Error: Kubernetes cluster unreachable: Get "http://localhost:8080/version": dial tcp [::1]:8080: connect: connection refused
```

#### 原因
`helm template --validate` コマンドは Kubernetes API サーバーへの接続を必要としますが、CI 環境には Kubernetes クラスターが存在しません。

#### 解決方法
`--validate` フラグを削除：

```yaml
- name: Validate Helm Chart
  run: |
    helm template test helm/ssh-workspace \
      --set user.name="testuser" \
      --set 'ssh.publicKeys[0]=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example.com'
    # --validate を削除
```

**注意:** `helm template` は純粋なテンプレート検証を行い、`--validate` は追加で Kubernetes API の検証を行います。CI 環境では前者で十分です。

### 6. Pre-install フックでのパッケージインストールタイムアウト

#### エラーメッセージ
```
Error: INSTALLATION FAILED: failed pre-install: 1 error occurred:
	* timed out waiting for the condition
```

#### 原因
`alpine:3.18` イメージを使用したpre-installフックで `apk add openssh-keygen` を実行していましたが：
1. `openssh-keygen` は存在しないパッケージ名（正しくは `openssh-client`）
2. パッケージダウンロードでネットワークアクセスが必要
3. CI環境での不安定なネットワーク接続

#### 解決方法
SSH-workspaceイメージを使用してネットワーク依存を排除：

```yaml
# 修正前
- name: ssh-key-validator
  image: alpine:3.18
  command:
  - /bin/sh
  - -c
  - |
    apk add --no-cache openssh-keygen
    # ssh-keygen validation...

# 修正後
- name: ssh-key-validator
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
  - /bin/sh
  - -c
  - |
    # ssh-keygen validation (already available)
```

### 7. 無効なSSH公開鍵形式による検証失敗

#### エラーメッセージ
```
Error: INSTALLATION FAILED: context deadline exceeded
```

#### 原因
テスト用のダミーSSH公開鍵が無効な形式でした：
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example.com
```
SSH ED25519鍵のbase64部分が短すぎて、`ssh-keygen -l -f -` による検証が失敗していました。

#### 解決方法
有効なSSH ED25519公開鍵に置換：

```yaml
# 修正前（無効）
--set 'ssh.publicKeys[0]=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example.com'

# 修正後（有効）
--set 'ssh.publicKeys[0]=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXdG3HVN1wyFVldcqtOp4Ou6+CrSBEvvE1Ll4QUArje test@example.com'
```

### 8. ワークフローでの部分的な置換による不整合

#### 問題
`replace_all=true` での一括置換時に、一部のステップでSSH鍵が更新されない問題が発生。

#### 原因
コマンドラインの微妙な差異により、完全一致せず一部の置換が失敗：
- `helm lint` ステップ：置換成功
- `helm template` ステップ：置換失敗（古い鍵が残存）
- `helm install` ステップ：置換失敗（古い鍵が残存）

#### 解決方法
各ステップを個別に確認し、手動で修正：

```bash
# 問題の特定
grep -n "ssh.publicKeys" .github/workflows/ci.yml

# 個別修正
# 69行目と80行目の古いSSH鍵を新しい有効な鍵に置換
```

#### 予防策
- 複数箇所で同じ値を使用する場合は、環境変数として定義
- 一括置換後は必ず全ファイルを確認
- テンプレート化やDRY原則の適用を検討

### 9. Init Container での chmod 600 権限エラー（authorized_keys）

#### 問題の概要
2025年7月3日、SSH ワークスペースの Init Container で `authorized_keys` ファイルに対する `chmod 600` 操作が失敗する問題が発生しました。この問題により、SSH接続は動作するものの、セキュリティ要件を満たさない状態となっていました。

#### エラーメッセージ
```bash
❌ chmod failed with exit code: 1
Operation not permitted
```

#### 発生環境
- **影響範囲**: 全ストレージバックエンド（emptyDir、PVC）
- **セキュリティレベル**: basic、standard 両方
- **権限戦略**: explicit（明示的権限管理）

#### 根本原因の調査

**段階1: 詳細診断の実装**
初期調査では chmod が失敗する原因が不明だったため、包括的な診断機能を実装：

```bash
# ファイルシステム情報
findmnt "/home/$SSH_USER" 

# Linux capabilities 確認
grep -i "cap" /proc/self/status

# ファイル属性チェック
lsattr "/home/$SSH_USER/.ssh/authorized_keys"
```

**段階2: 権限とケーパビリティの分析**
診断結果から以下が判明：

```bash
# 期待されるケーパビリティ
CapPrm: 00000000000000cb  # SETUID + SETGID + CHOWN + DAC_OVERRIDE + FOWNER

# 実際のケーパビリティ（問題時）
CapPrm: 00000000000000c3  # SETUID + SETGID + CHOWN + DAC_OVERRIDE（FOWNERなし）
```

**段階3: CAP_FOWNER ケーパビリティの不足特定**
- `CAP_FOWNER` (bit 3, 0x8) が不足していることが根本原因
- このケーパビリティは他のユーザーが所有するファイルの chmod 操作に必要
- Init Container で `chown testuser:testuser` した後の `chmod 600` が失敗

#### 解決方法

**1. Init Container への CAP_FOWNER 追加**
`helm/ssh-workspace/templates/_helpers.tpl` の修正：

```yaml
{{- define "ssh-workspace.initSecurityContext" -}}
runAsNonRoot: false
readOnlyRootFilesystem: false
allowPrivilegeEscalation: true
capabilities:
  drop:
    - ALL
  add:
    - SETUID   # Required for useradd
    - SETGID   # Required for groupadd  
    - CHOWN    # Required for file ownership setup
    - DAC_OVERRIDE  # Required for file permission setup
    - FOWNER   # Required for chmod on files owned by other users ← 追加
{{- end }}
```

**2. chmod 失敗検出機能の実装**
SSH接続テストが成功してもセキュリティ要件が満たされていない場合を検出：

```bash
# Init Container (init-container.sh)
chmod 600 "/home/$SSH_USER/.ssh/authorized_keys" || {
    echo "CHMOD_FAILED" > /tmp/chmod_failure_marker
    echo "authorized_keys chmod failed with exit code $?" >> /tmp/chmod_failure_marker
}

# Main Container (entrypoint.sh)  
if [ -f "/tmp/chmod_failure_marker" ]; then
    echo "INIT_CHMOD_FAILED" > /tmp/ssh_security_failure
    echo "authorized_keys permissions are incorrect (not 600)" >> /tmp/ssh_security_failure
fi

# テスト (permission-validation-test.yaml)
SECURITY_FAILURE_OUTPUT=$(kubectl exec "$POD_NAME" -- /bin/sh -c '
    if [ -f "/tmp/ssh_security_failure" ]; then
        echo "SECURITY_FAILURE_DETECTED"
        cat /tmp/ssh_security_failure
    else
        echo "NO_SECURITY_FAILURES"
    fi
')

if echo "$SECURITY_FAILURE_OUTPUT" | grep -q "SECURITY_FAILURE_DETECTED"; then
    echo "❌ CRITICAL SECURITY FAILURE DETECTED!"
    exit 1
fi
```

#### 検証結果

修正後のテスト実行で以下が確認されました：

**Init Container のケーパビリティ**
```bash
CapPrm: 00000000000000cb  # CAP_FOWNER を含む完全なケーパビリティセット
CapEff: 00000000000000cb
CapBnd: 00000000000000cb
```

**chmod 600 の成功**
```bash
✓ Set authorized_keys permissions to 600
After ownership and permission changes:
  authorized_keys: testuser:testuser (600)
```

**セキュリティ検証の成功**
```bash
✓ No security failures detected from containers
✓ Permission strategy validation completed successfully
```

#### 技術的詳細

**Linux Capabilities について**
- `CAP_FOWNER`: ファイル所有者以外による chmod/chown 操作を許可
- 必要性: Init Container が root として実行されても、`chown` でユーザー所有にした後の `chmod` には CAP_FOWNER が必要
- セキュリティ: 最小権限の原則に従い、必要最小限のケーパビリティのみを付与

**chmod(2) システムコールの EPERM 条件**
以下の場合に `chmod` は EPERM（Operation not permitted）で失敗：
1. プロセスの実効ユーザーIDがファイル所有者と異なる
2. かつ、`CAP_FOWNER` ケーパビリティを持たない

**解決策の選択理由**
1. **ConfigMap マウント方式の廃止**: 権限問題を回避するため環境変数方式に変更
2. **診断機能の充実**: 将来の類似問題に備えて包括的な診断ロジックを実装  
3. **遅延失敗検出**: SSH接続成功でもセキュリティ要件未達成の場合を検出
4. **最小権限の原則**: 必要最小限のケーパビリティのみを追加

#### 学習事項

**Kubernetes セキュリティコンテキスト設計**
- Init Container と Main Container で異なるケーパビリティ要件を持つ場合がある
- ファイル所有権の変更後は、それに応じたケーパビリティの見直しが必要
- `runAsRoot: false` でもケーパビリティ制限により予期しない動作が発生する可能性

**トラブルシューティング手法**
- **段階的診断**: システムコール失敗時は、ファイルシステム、権限、ケーパビリティを順次確認
- **根本原因追求**: 表面的な症状（SSH動作）ではなく、セキュリティ要件の確認も重要
- **防御的実装**: False positive を避けつつ、セキュリティ不備を確実に検出する仕組み

この修正により、SSH Workspace は完全なセキュリティ要件を満たしつつ、堅牢な動作を実現しています。

## 参考リンク

- [GitHub Actions permissions documentation](https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs)
- [Helm lint documentation](https://helm.sh/docs/helm/helm_lint/)
- [Helm template documentation](https://helm.sh/docs/helm/helm_template/)
- [Docker build-push-action documentation](https://github.com/docker/build-push-action)
- [Linux Capabilities(7) man page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [chmod(2) system call documentation](https://man7.org/linux/man-pages/man2/chmod.2.html)