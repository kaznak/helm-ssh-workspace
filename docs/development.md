# 開発ワークフロー

このドキュメントは、AI エージェントが本プロジェクトの開発を効率的に行うための手順書です。

## 開発環境の準備

### 前提条件

- Docker
- Helm 3.x
- kubectl
- k3d (ローカルテスト用)

### 基本的な開発フロー

1. **コードを修正**
2. **品質チェック実行**: `make lint`
3. **ビルドとテスト**: `make test`
4. **統合テスト**: `make integration-test`
5. **パッケージング**: `make helm-package`

## Makefile ターゲット一覧

### 基本ターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `all` | ビルド、テスト、パッケージの完全実行 | `docker-build`, `test`, `helm-package` |
| `help` | 利用可能なターゲットの表示 | なし |
| `clean` | ビルド成果物の削除 | なし |

### ビルドターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `docker-build` | Docker イメージをビルド | `tmp/.docker-build-sentinel` |

### テストターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `test` | 全てのテストを実行 | `lint`, `helm-test`, `docker-test` |
| `lint` | Linting を実行 | `helm-lint`, `markdown-lint` |
| `helm-lint` | Helm チャートの Lint | なし |
| `helm-test` | Helm テンプレートテスト | `helm-lint` |
| `markdown-lint` | マークダウンリンクチェック | なし |
| `docker-test` | Docker イメージテスト | `docker-build` |
| `e2e-test` | エンドツーエンドテスト | `tmp/.k3d-image-loaded-sentinel`, `helm-package` |
| `integration-test` | 統合テスト | `docker-build` |

### セキュリティターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `security` | セキュリティテスト実行 | `docker-security`, `helm-security` |
| `docker-security` | Docker セキュリティテスト | なし |
| `helm-security` | Helm セキュリティテスト | なし |

### パッケージングターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `helm-package` | Helm チャートパッケージ作成 | `helm-test` |
| `publish` | Docker イメージと Helm チャートを公開 | `docker-push`, `helm-publish` |
| `docker-push` | Docker イメージを公開 | `tmp/.docker-build-sentinel`, `docker-test` |
| `helm-publish` | Helm チャートを OCI レジストリに公開 | `helm-package` |

### k3d クラスタ管理ターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `create-k3d-cluster` | k3d クラスタ作成 | `tmp/.k3d-cluster-created-sentinel` |
| `delete-k3d-cluster` | k3d クラスタ削除 | なし |
| `load-image-to-k3d` | Docker イメージを k3d に読み込み | `tmp/.k3d-image-loaded-sentinel` |
| `generate-test-ssh-key` | テスト用 SSH キーペア生成 | `tmp/.test-ssh-key-generated-sentinel` |
| `prepare-test-env` | テスト環境準備 | なし |

### Helm ライフサイクル管理ターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `helm-install` | Helm リリースインストール | `helm-package`, `prepare-test-env` |
| `helm-upgrade` | Helm リリースアップグレード | `helm-package`, `prepare-test-env` |
| `helm-rollback` | Helm リリースロールバック | なし |
| `helm-uninstall` | Helm リリースアンインストール | なし |
| `helm-status` | Helm リリース状態確認 | なし |
| `helm-history` | Helm リリース履歴確認 | なし |
| `helm-list` | Helm リリース一覧表示 | なし |
| `helm-lifecycle-test` | Helm ライフサイクル完全テスト | `docker-build`, `helm-package` |

### クリーンアップターゲット

| ターゲット | 説明 | 依存関係 |
|-----------|------|----------|
| `test-clean` | テスト環境クリーンアップ | なし |

## 開発時の推奨コマンド順序

### 基本的な開発サイクル

```bash
# 1. 品質チェック
make lint

# 2. ビルドとテスト
make test

# 3. 統合テスト（必要に応じて）
make integration-test

# 4. パッケージング
make helm-package
```

### 完全なローカルテスト

```bash
# 1. k3d クラスタ作成
make create-k3d-cluster

# 2. Docker イメージをビルドしてk3dに読み込み
make load-image-to-k3d

# 3. エンドツーエンドテスト（ローカル開発環境設定）
LOCAL_DEV=true make e2e-test

# 4. Helm ライフサイクルテスト（ローカル開発環境設定）
LOCAL_DEV=true make helm-lifecycle-test

# 5. クリーンアップ
make delete-k3d-cluster
```

### リリース前チェック

```bash
# 1. セキュリティテスト
make security

# 2. 品質チェック
make quality

# 3. 統合テスト
make integration-test

# 4. パッケージング
make helm-package
```

## 環境変数

### Docker 関連

- `DOCKER_REPO`: Docker リポジトリ名（デフォルト: `ssh-workspace`）
- `DOCKER_TAG`: Docker タグ（デフォルト: `latest`）

### Kubernetes 関連

- `KUBE_CONTEXT`: Kubernetes コンテキスト（オプション）
- `KUBE_NAMESPACE`: Kubernetes 名前空間（デフォルト: `default`）
- `HELM_RELEASE_NAME`: Helm リリース名（デフォルト: `ssh-workspace-test`）

### k3d 関連

- `K3D_CLUSTER_NAME`: k3d クラスタ名（デフォルト: `helm-ssh-workspace-test`）
- `K3D_CLUSTER_MANAGEMENT`: クラスタ管理方式（`local` または `external`）

### テスト関連

- `TEST_SSH_PUBKEY`: テスト用 SSH 公開鍵
- `TEST_SSH_KEY_FILE`: テスト用 SSH キーファイルパス（デフォルト: `tmp/test_ssh_key`）
- `LOCAL_DEV`: ローカル開発環境フラグ（`true` で IfNotPresent、`false` で Always）

### 公開関連

- `HELM_REGISTRY`: Helm レジストリ（デフォルト: `ghcr.io`）
- `HELM_REGISTRY_TOKEN`: Helm レジストリ認証トークン
- `HELM_REGISTRY_USER`: Helm レジストリユーザ名

## Sentry File パターン

本プロジェクトでは、Makefile の `.PHONY` ターゲットに sentry file パターンを使用しています。

### Sentry File 一覧

- `tmp/.docker-build-sentinel`: Docker イメージビルド完了マーカー
- `tmp/.k3d-cluster-created-sentinel`: k3d クラスタ作成完了マーカー
- `tmp/.k3d-image-loaded-sentinel`: k3d へのイメージ読み込み完了マーカー
- `tmp/.test-ssh-key-generated-sentinel`: テスト用 SSH キー生成完了マーカー

### Sentry File の利点

1. **依存関係の明確化**: ファイルの存在により依存関係が明確
2. **重複実行の防止**: 既に実行済みの処理をスキップ
3. **段階的ビルド**: 必要な部分のみ再実行
4. **デバッグ容易性**: 実行状態をファイルで確認可能

## エラー対応

### よくあるエラーと対処方法

1. **Docker イメージビルドエラー**
   ```bash
   # キャッシュクリア後再実行
   make clean
   make docker-build
   ```

2. **k3d クラスタ作成エラー**
   ```bash
   # 既存クラスタ削除後再作成
   make delete-k3d-cluster
   make create-k3d-cluster
   ```

3. **SSH 接続テストエラー**
   ```bash
   # テスト用 SSH キー再生成
   rm -f tmp/test_ssh_key*
   make generate-test-ssh-key
   make e2e-test
   ```

4. **Helm テストエラー**
   ```bash
   # テスト環境クリーンアップ後再実行
   make test-clean
   make helm-lifecycle-test
   ```

## CI/CD 統合

GitHub Actions では以下のターゲットが使用されます：

### PR 時
- `make lint`
- `make test`
- `make security`
- `make integration-test`

### リリース時
- `make all`
- `make publish`

## 開発時のベストプラクティス

1. **段階的実行**: 小さな変更後は `make lint` から開始
2. **完全テスト**: 重要な変更後は `make integration-test` を実行
3. **クリーンアップ**: 作業完了後は `make clean` でクリーンアップ
4. **sentry file 確認**: 問題発生時は `tmp/` ディレクトリで実行状態を確認

## 参考情報

- [Makefile](../Makefile): 完全なターゲット定義
- [GitHub Actions CI](../.github/workflows/ci.yml): CI/CD パイプライン
- [GitHub Actions PR](../.github/workflows/pr.yml): PR 検証パイプライン