# 設計書

## 概要

[README.ja.md](../README.ja.md)の[要求・要件](../README.ja.md#要求要件)を満たすDropbear SSH ワークスペースHelmチャートおよびDockerイメージの実装設計。

この設計書の構成は以下の通り:

- 重要な設計事項
- コンポーネントの詳細
- ライフサイクルの詳細
- テストの詳細

### 重要な設計事項

#### Dropbear SSH の採用

- <span id="K4R9-DROPBEAR">[K4R9-DROPBEAR]</span> 本プロジェクトでは SSH サーバとして Dropbear SSH を採用する。

この決定は非特権環境での運用要件 [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT) を満たすためである。

Dropbear SSH の採用により以下の要件が容易に実現できる：
- SSH 鍵認証のみの設定 [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH)
- ポートフォワーディングのローカルホスト制限 [[L9K6-LOCAL]](../README.ja.md#L9K6-LOCAL)
  - Dropbear SSH はデフォルトでローカルホスト (127.0.0.1) にのみバインドする
  - 外部アクセスを許可する `-a` オプションを使用しないことが重要
- Pod Security Standards の restricted ポリシー完全対応 [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
  - 非特権ポート（2222）使用により root 権限不要
  - ケーパビリティ不要でユーザランド完全実行
  - runAsNonRoot、allowPrivilegeEscalation=false 等の制約に対応

OpenSSH の場合、これらの要件を満たそうとすると複雑な設定が必要となる。

#### ユーザ設定と関連する処理

ssh workspace は、デプロイ時にユーザ情報を受け付けてそれに合わせた設定を行う - [[Y4F1-USER]](../README.ja.md#Y4F1-USER), [[G8W5-USERNAME]](../README.ja.md#G8W5-USERNAME), [[Z2S7-UID]](../README.ja.md#Z2S7-UID), [[A9T3-GID]](../README.ja.md#A9T3-GID)。
そのため CI フェーズではユーザの設定を行うことは出来ず、 Install フェーズで以下の処理を行う必要がある：

- ユーザの追加とホームディレクトリのセットアップ - [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME)

また Install フェーズでの関連する処理として以下がある：

- ホームディレクトリ再利用時の既存設定確認 - [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST)
  - ホームディレクトリのデータが既に存在する場合、ユーザ設定を上書きしないようにする。
- linuxbrew の非特権環境での導入とパッケージ管理 - [[M4J7-BREW]](../README.ja.md#M4J7-BREW)

#### SSH ホストキーについて

- <span id="W5X2-SECRET">[W5X2-SECRET]</span> SSH ホストキーは Secret に保存して永続化する
- <span id="T8Q4-PREINSTALL">[T8Q4-PREINSTALL]</span> SSH ホストキーは、もしもユーザが指定しない場合、Pre-install Hook で生成する
- <span id="R6N7-CRYPTO">[R6N7-CRYPTO]</span> SSH ホストキーは Ed25519 を優先し、RSA (4096bit) を併用する

SSH ホストキーの管理は本プロジェクトの重要な設計要素である - [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY), [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)。

**保存方式の選択**:
- **Secret 保存を採用** - PVC 保存と比較してセキュリティ上の利点がある
  - readOnly マウントによる意図しない変更の防止
  - defaultMode による確実なファイル権限設定 (0600)
  - items による選択的マウントとファイル名変更
  - tmpfs による実行時メモリ上での保護

**生成タイミング**:
- **Pre-install Hook で実行** - 条件付きでのホストキー生成
- values.yaml での事前指定がない場合のみ生成
- 一時的な権限 (Secret 作成) の時間的制限
- hook-delete-policy による権限リソースの自動削除
- Helmfile Preapply Hook での namespace アノテーション設定を実施していたら、Pod Security Standards のテストも同時に実行可能 

**アルゴリズムの選択**:
- Ed25519: セキュリティと性能の観点から優先
- RSA (4096bit): 古いクライアントとの互換性のため併用
- dropbearkey コマンドによる生成

#### 各種スクリプトについて

ssh workspace はライフサイクルの各段階でのテストを充実させ、後段でのトラブルの発生を極力抑える - [[U9A4-TEST]](../README.ja.md#U9A4-TEST)。
また、節、[Install フェーズでのユーザ設定](#install-フェーズでのユーザ設定)、で述べた理由のため、複雑な処理を実行する必要がある - [[Y4F1-USER]](../README.ja.md#Y4F1-USER), [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME), [[N3M9-PERSIST]](../README.ja.md#N3M9-PERSIST)。

確実にこれらの処理を実行できるようにするため、成果物の Docker イメージにこれらの処理のためのスクリプトを含めて、このイメージにより起動されるコンテナにより全ての処理を行えるようにする。

#### replicas固定とスケーリング無効

要件により replicas は 1 に固定し、自動スケーリングは無効とする - [[J8R2-DEPLOY]](../README.ja.md#J8R2-DEPLOY), [[G9W8-FIXED]](../README.ja.md#G9W8-FIXED)。

HPA等の自動スケーリング機能は明示的に無効化し、単一replica前提での設計とする。
これはSSH接続の特性上、複数インスタンスによる負荷分散が適さないためである。

## コンポーネントの詳細

### 概要

ssh workspace のコンポーネントは以下から構成される。

- Dockerイメージ
- Helmチャート(kubernetes リソース、 main/test)
- github actions workflow マニフェスト

### Docker イメージ

SSH workspace の実行環境を提供するコンテナイメージ。

#### ベースイメージ
- Ubuntu/Debian ベース - linuxbrew 対応のため [[M4J7-BREW]](../README.ja.md#M4J7-BREW)

#### 含まれるコンポーネント
- **Dropbear SSH サーバ** - 非特権実行可能な SSH サーバ [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- **基本開発ツール** - git, curl, vim 等の基本ツール [[Q2N5-TOOLS]](../README.ja.md#Q2N5-TOOLS)
- **linuxbrew 環境** - ユーザランドでのパッケージ管理 [[M4J7-BREW]](../README.ja.md#M4J7-BREW)
- **管理スクリプト群**
  - 初期化スクリプト (init-container 用)
  - エントリポイントスクリプト (SSH サーバ起動用)
  - テストスクリプト (helm test 用)

#### 設計上の考慮事項
- 非特権ユーザでの実行を前提とした構成
- values.yaml で指定されるユーザ設定は含まない (CI フェーズの制約)

### Helm チャート

Kubernetes リソースのデプロイとライフサイクル管理を提供。

#### メインリソース
- **Deployment** - SSH workspace Pod の管理 [[J8R2-DEPLOY]](../README.ja.md#J8R2-DEPLOY)
  - replicas: 1 固定 [[G9W8-FIXED]](../README.ja.md#G9W8-FIXED)
  - securityContext: restricted policy 準拠 [[X2K7-RESTRICT]](../README.ja.md#X2K7-RESTRICT)
- **Service** - SSH 接続用エンドポイント [[N4V9-SVC]](../README.ja.md#N4V9-SVC)
  - type: ClusterIP (デフォルト) [[E4L7-CLUSTER]](../README.ja.md#E4L7-CLUSTER)
  - port: 2222 [[B3Q8-PORT]](../README.ja.md#B3Q8-PORT)

#### 設定リソース
- **ConfigMap** - SSH サーバ設定、スクリプト等
- **Secret** - SSH 認証鍵、ホストキー [[L6H3-KEYAUTH]](../README.ja.md#L6H3-KEYAUTH), [[V4J1-HOSTKEY]](../README.ja.md#V4J1-HOSTKEY)

#### ストレージリソース (オプション)
- **PersistentVolumeClaim** - ホームディレクトリ永続化用 [[V5Q3-HOME]](../README.ja.md#V5Q3-HOME)
  - emptyDir がデフォルト [[T1H8-EMPTY]](../README.ja.md#T1H8-EMPTY)

#### 初期化リソース
- **Pre-install Hook** - ホストキー永続化 [[R8N9-REUSE]](../README.ja.md#R8N9-REUSE)
- **Init Container** - ユーザ設定、環境初期化等

#### テストリソース
- **Test Pod** - helm test 用検証スクリプト [[U9A4-TEST]](../README.ja.md#U9A4-TEST)

### GitHub Actions ワークフロー

CI/CD パイプラインとリリース管理を提供。

#### ビルドワークフロー
- Docker イメージのビルドとプッシュ
- Helm チャートのパッケージング
- 静的解析とセキュリティスキャン

#### テストワークフロー
- 全 Helm ライフサイクルのテスト実行
- 複数 Kubernetes バージョンでの検証
- values.yaml パターンテスト

#### リリースワークフロー
- セマンティックバージョニング
- GitHub Releases での成果物公開
- Helm リポジトリへの登録

## ライフサイクルの詳細

### 概要

ssh workspace のライフサイクルは以下の通り。

- CI: Github Actions のフェーズ
  - ビルド関連の処理のほか、 helm の全てのライフサイクルのテストも行う。
- Install: helm install フェーズ
- Test: helm test フェーズ
- Upgrade: helm upgrade フェーズ
- Rollback: helm rollback フェーズ
- Uninstall: helm uninstall フェーズ

### CI フェーズ (GitHub Actions)

#### ビルド処理
#### テスト実行
#### 成果物公開

### Install フェーズ (helm install)

#### Helmfile Prepare Hook
#### Helmfile Presync Hook
#### Namespace 作成・設定 (Helmfile)
#### Helmfile Preapply Hook
#### Pre-install Hook
#### Init Container
#### メインコンテナ起動
#### Post-install Hook
#### Helmfile Postsync Hook
#### Helmfile Cleanup Hook

### Test フェーズ (helm test)

#### 接続テスト
#### 機能テスト
#### セキュリティテスト

### Upgrade フェーズ (helm upgrade)

#### Helmfile Prepare Hook
#### Helmfile Presync Hook
#### Helmfile Preapply Hook
#### Pre-upgrade Hook
#### 更新処理
#### Post-upgrade Hook
#### Helmfile Postsync Hook
#### Helmfile Cleanup Hook

### Rollback フェーズ (helm rollback)

#### Helmfile Prepare Hook
#### Helmfile Presync Hook
#### Helmfile Preapply Hook
#### Pre-rollback Hook
#### ロールバック処理
#### Post-rollback Hook
#### Helmfile Postsync Hook
#### Helmfile Cleanup Hook

### Uninstall フェーズ (helm uninstall)

#### Helmfile Prepare Hook
#### Helmfile Presync Hook
#### Pre-delete Hook
#### 削除処理
#### リソース保持
#### Helmfile Postsync Hook
#### Helmfile Cleanup Hook

## テストの詳細

以下のテスト項目は、各ライフサイクル段階（Pre-install Hook、Post-install Hook、Pre-upgrade Hook、Post-upgrade Hook、helm test）で実行され、段階的な品質確保を行う。

### k8s リソーステスト

#### k8s リソース存在確認
想定通りの k8s リソースが存在することを確認

#### configMap, Secret の内容確認
内容の SSH サーバ設定や SSH 鍵が正しいことを確認

#### Pod Security Standards 準拠確認
- namespace に "pod-security.kubernetes.io/enforce=restricted" が設定されていることを確認
- Pod の securityContext が restricted ポリシーに準拠していることを確認
  - runAsNonRoot: true
  - allowPrivilegeEscalation: false
  - capabilities.drop: ["ALL"]
  - seccompProfile.type: RuntimeDefault

### ネットワークテスト

#### ネットワーク到達テスト
SSH ポートへの接続と SSH サーバ応答確認。実際の SSH 接続は行わない。

#### SSH 認証テスト
SSH 鍵認証が正しく機能することを確認

### SSH サーバテスト

#### SSH ポートフォワーディング確認
ローカルホストへのポートフォワーディングが正しく機能することを確認

### ユーザ環境テスト

#### ユーザ設定確認
values.yaml で指定したユーザ名、UID、GID が正しく設定されていることを確認

#### ユーザ権限確認
ユーザが開発に必要な権限を持っていることを確認
