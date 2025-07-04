# Test Files

## Helm Test Templates

### [ssh-internal-validation-test.yaml](helm/ssh-workspace/templates/tests/ssh-internal-validation-test.yaml)
SSH内部構成の検証テスト。デプロイされたワークスペースのセキュリティ設定、権限、ファイルシステム権限を検証する。

### [resource-validation-test.yaml](helm/ssh-workspace/templates/tests/resource-validation-test.yaml)
Kubernetesリソースの存在確認テスト。ConfigMap、Secret、Deployment、Service、PVCなどの必要なリソースが正しく作成されているかを検証する。

### [user-workspace-functionality-test.yaml](helm/ssh-workspace/templates/tests/user-workspace-functionality-test.yaml)
ユーザーワークスペースの機能テスト。ファイル操作、ディレクトリ操作、開発ツールの利用可能性、データ永続化などの実際の作業環境としての機能を検証する。

### [test-ssh-keys-secret.yaml](helm/ssh-workspace/templates/tests/test-ssh-keys-secret.yaml)
テスト用SSHキーのSecretリソース。テスト実行時に使用するSSHキーペアを格納する。

### [ssh-authentication-test.yaml](helm/ssh-workspace/templates/tests/ssh-authentication-test.yaml)
SSH認証機能のテスト。SSHサービスへの接続性、キーベース認証の動作確認を行う。

### [rbac.yaml](helm/ssh-workspace/templates/tests/rbac.yaml)
テスト実行用のRBAC設定。ServiceAccount、Role、RoleBindingを定義し、テストポッドがKubernetesリソースにアクセスできるように権限を設定する。

## GitHub Actions Test Workflows

### [helm-test.yml](.github/workflows/helm-test.yml)
GitHubアクションによるHelmチャートの自動テストワークフロー。Docker イメージのビルド、Kubernetesクラスターでのデプロイ、全テストの実行を自動化する。