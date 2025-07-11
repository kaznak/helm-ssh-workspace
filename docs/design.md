# 設計書

## 概要

[README.md](../README.md)の[要求・要件](requirements.md#要求要件)を満たすDropbear SSH ワークスペースHelmチャートおよびDockerイメージの実装設計。

### 重要な設計事項

#### Ubuntu ベースのイメージ採用

<span id="R8M5-UBUNTU">[R8M5-UBUNTU]</span> 本プロジェクトでは Docker イメージのベースとして Ubuntu を採用する。

この決定は以下の要件を満たすためである：

**採用理由：**
- linuxbrew 対応要件 [see:M4J7-BREW](requirements.md#M4J7-BREW) を満たすため
  - linuxbrew は Ubuntu/Debian 系での動作が最も安定している
  - 豊富な開発ツール群のサポート
- 基本開発ツール要件 [see:Q2N5-TOOLS](requirements.md#Q2N5-TOOLS) への対応
  - git, curl, vim 等の標準ツールが充実
  - 開発者にとって馴染みやすい環境
- 非特権実行環境での安定性
  - ユーザランドでのパッケージ管理が容易
  - 権限制約下でのソフトウェアインストールに適している

**技術的利点：**
- 充実したパッケージ管理システム（apt）
- 定期的なセキュリティアップデートの提供
- 豊富なドキュメントとコミュニティサポート
- 企業環境での実績と信頼性

**他の選択肢との比較：**
- **Alpine Linux との比較**
  - Alpine: 軽量（数MB）だが、musl libc による互換性問題
  - Ubuntu: 大きめ（数百MB）だが、glibc による高い互換性
  - linuxbrew との相性: Ubuntu が優位
- **他のディストリビューションとの比較**
  - CentOS/RHEL: 企業向けだが、開発ツールの導入が複雑
  - Debian: Ubuntu のベースで類似だが、Ubuntu の方が新しいパッケージ

**実装上の考慮事項：**
- イメージサイズの最適化
  - 不要なパッケージの除去
  - .dockerignore による不要ファイル除外
  - レイヤー最適化（RUN命令の統合）
- セキュリティ強化設定
  - 最小権限の原則に基づく設定
  - 定期的なベースイメージの更新

#### Dropbear SSH の採用

<span id="K4R9-DROPBEAR">[K4R9-DROPBEAR]</span> 本プロジェクトでは SSH サーバとして Dropbear SSH を採用する。

この決定は非特権ポートでの運用を可能にし、セキュリティを向上させるためである。

Dropbear SSH の採用により以下の要件が容易に実現できる：
- SSH 鍵認証のみの設定 [see:L6H3-KEYAUTH](requirements.md#L6H3-KEYAUTH)
- ポートフォワーディングのネットワークポリシー制御 [see:N4C7-NETPOL](requirements.md#N4C7-NETPOL)
  - Dropbear SSH はデフォルトでローカルホスト (127.0.0.1) にのみバインドする
  - 外部アクセスを許可する `-a` オプションを使用しないことが重要
- セキュアな運用環境の実現
  - 非特権ポート（2222）使用により通常ユーザでの SSH サーバ起動が可能
  - 最小権限の原則に基づく設計
  - コンテナ起動後は非特権ユーザで動作

OpenSSH の場合、これらの要件を満たそうとすると複雑な設定が必要となる。

#### ユーザ設定と関連する処理

ssh workspace は、デプロイ時にユーザ情報を受け付けてそれに合わせた設定を行う - [see:Y4F1-USER](requirements.md#Y4F1-USER), [see:G8W5-USERNAME](requirements.md#G8W5-USERNAME), [see:Z2S7-UID](requirements.md#Z2S7-UID), [see:A9T3-GID](requirements.md#A9T3-GID)。

CI フェーズではユーザ固有の設定を行うことができない理由：
- Docker イメージのビルド時点では、実際のデプロイ時に指定されるユーザ情報が未定
- 汎用的なイメージとして複数のユーザ環境で利用可能にするため
- セキュリティ上、ビルド時にユーザの認証情報を埋め込むことは不適切

そのため、Install フェーズで動的にユーザ環境を構築する必要がある：

- **ユーザの追加とホームディレクトリのセットアップ** - [see:V5Q3-HOME](requirements.md#V5Q3-HOME), [see:N3M9-PERSIST](requirements.md#N3M9-PERSIST)
  - `values.yaml` で指定されたユーザ名、UID、GID に基づいてシステムユーザを作成
  - **ホームディレクトリ再利用の判定方法**：
    - ホームディレクトリの存在確認（`/home/${username}` の存在）
    - 初期化完了マーカーファイル（`~/.ssh-workspace-initialized`）の存在確認
    - PersistentVolume使用時は、マウントポイントに既存データが存在するかを確認
  - **新規ホームディレクトリの場合**（上記判定で再利用でないと判定）：
    - ホームディレクトリの作成と適切な権限設定
    - SSH 設定ディレクトリ (`~/.ssh/`) の初期化
    - 必要な設定ファイルの配置とオーナーシップの設定
    - 初期化完了マーカーファイル（`~/.ssh-workspace-initialized`）の作成
  - **ホームディレクトリ再利用時の場合**（上記判定で再利用と判定）：
    - 既存のユーザ設定ファイル（`.bashrc`, `.profile` 等）の存在確認
    - 既存設定がある場合は上書きを避け、必要に応じてバックアップを作成
    - 新規設定と既存設定の競合回避メカニズム
    - 不足している設定ファイルやディレクトリのみ追加作成
    - 初期化完了マーカーファイルの更新（タイムスタンプ等）

Install フェーズでの関連する処理：

- **SSH環境の動的セットアップ** - [see:M7X3-MOUNTSTRATEGY](#M7X3-MOUNTSTRATEGY)
  - コンテナ起動時に `start-ssh-server.sh` スクリプトが実行される
  - Phase 1: ユーザ・環境セットアップ（root権限で実行）
    - ユーザとグループの作成
    - SSH ディレクトリの作成（`~/.ssh/`, `~/.ssh/dropbear/`）
    - Secret から SSH 鍵のコピーと権限設定
    - ファイルの所有者設定（chown）
  - Phase 2: SSH サーバ起動（ターゲットユーザ権限で実行）
    - `su` コマンドによるユーザ切り替え
    - Dropbear SSH サーバの起動

- **linuxbrew の非特権環境での導入とパッケージ管理** - [see:M4J7-BREW](requirements.md#M4J7-BREW)
  - 非特権ユーザでのパッケージ管理システムとして linuxbrew を活用
  - Install フェーズでのセットアップにより、ユーザが任意のソフトウェアを安全にインストール可能
  - システム全体への影響を与えることなく、個別のユーザ環境を構築

#### SSH ホストキーについて
 
- <span id="W5X2-SECRET">[W5X2-SECRET]</span> SSH ホストキーは K8s Secret コンポーネントに保存して永続化する
  - K8s Secret に保存すると K8s PVC に保存する場合と比較してセキュリティ上の利点がある
    - readOnly マウントによる意図しない変更の防止
    - defaultMode による確実なファイル権限設定 (0600)
    - items による選択的マウントとファイル名変更
    - tmpfs による実行時メモリ上での保護
  - ホストキーは永続化され、helm release 削除後も再利用可能 - [see:R8N9-REUSE](requirements.md#R8N9-REUSE)
    - "helm.sh/resource-policy": "keep" アノテーションを利用

- <span id="T8Q4-AUTOGEN">[T8Q4-AUTOGEN]</span> SSH ホストキーは `values.yaml` で Secret 名を指定し、存在しない場合のみ自動生成される - [see:V4J1-HOSTKEY](requirements.md#V4J1-HOSTKEY)
  - `values.yaml` で Secret 名を明示的に指定可能、未指定時はデフォルト名（`{{ .Release.Name }}-ssh-hostkeys`）を使用
  - Pre-install/Pre-upgrade Hook で指定された Secret の存在確認を実施
  - Secret が存在しない場合のみ `dropbearkey` コマンドで自動生成
  - 生成された Secret には "helm.sh/resource-policy": "keep" アノテーションを付与

- <span id="J5N4-HOSTPERM">[J5N4-HOSTPERM]</span> SSH ホストキー生成のための K8s Secret 作成権限は最小権限とし、生存期間を最低限に抑える
  - SSH ホストキーを K8s Secret コンポーネントに保存するため、Secret 作成権限が必要
  - Secret 作成権限は必要最小限に制限
  - 作成完了後は不要な権限リソースを自動削除（hook-deletion-policy の活用）
  - Helmfile Preapply Hook での namespace アノテーション設定を実施していたら、Pod Security Standards のテストも同時に実行可能 

- <span id="R6N7-CRYPTO">[R6N7-CRYPTO]</span> SSH ホストキーは Ed25519 を優先し、RSA (4096bit) を併用する - [see:F2X8-KEYTYPE](requirements.md#F2X8-KEYTYPE)
  - Ed25519: セキュリティと性能の観点から優先
  - RSA (4096bit): 古いクライアントとの互換性のため併用
  - dropbearkey コマンドによる生成

- <span id="K2L8-HOSTVALID">[K2L8-HOSTVALID]</span> SSH ホストキーの検証処理 - [see:F2X8-KEYTYPE](requirements.md#F2X8-KEYTYPE)
  - Post-install/Post-upgrade Hook で Secret からホストキー内容を読み取り検証を実施
  - Hook 実行のため専用 ServiceAccount に Secret の読み出し権限（get）を付与
  - 権限関連リソース（ServiceAccount、Role、RoleBinding）は hook-delete-policy により Hook 実行完了後に自動削除
  - `ssh-keygen -lf` コマンドで各鍵の暗号学的検証を実施
  - RSA: 4096bit未満の鍵は警告、2048bit未満は拒否
  - Ed25519: セキュリティと性能の観点から優先される形式
  - 無効な鍵が含まれる場合は適切なエラーメッセージを出力して Hook を失敗させ、リリースステータスを failed にする

- <span id="V9H6-HOSTMOUNT">[V9H6-HOSTMOUNT]</span> SSH ホストキーは K8s Secret から readOnly でマウントされ、起動時に適切な場所にコピーされる
  - Secret は `/mnt/ssh-host-keys/` に readOnly でマウントされる
  - 起動時にスクリプトが `${DROPBEAR_DIR}` （`/home/${USERNAME}/.ssh/dropbear/`）にコピーし、適切な権限（0600）を設定
  - ファイル名: `dropbear_rsa_host_key`, `dropbear_ed25519_host_key`
  - readOnly マウントにより Secret の意図しない変更を防止
  - コピー時の権限設定により、ユーザ固有の所有者設定とDropbearの要求する権限を満たす

#### ユーザの SSH 鍵について

- <span id="P5Q8-PUBKEY">[P5Q8-PUBKEY]</span> ユーザの SSH 公開鍵は `values.yaml` で直接指定または既存 Secret 参照により K8s Secret に保存する - [see:K9T4-PUBKEY](requirements.md#K9T4-PUBKEY), [see:L6H3-KEYAUTH](requirements.md#L6H3-KEYAUTH), [see:M6L5-MULTIKEY](requirements.md#M6L5-MULTIKEY)
  - SSH 鍵認証のためのクライアント公開鍵として利用
  - `values.yaml` で `authorized_keys` ファイルの内容を直接記述可能
  - `values.yaml` で既存 Secret 名を指定して参照可能、未指定時はデフォルト名（`{{ .Release.Name }}-ssh-pubkeys`）を使用
  - 公開鍵と秘密鍵で共通の Secret を指定することも可能
  - Helm テンプレートで K8s Secret に保存

- <span id="H9F7-KEYFORMAT">[H9F7-KEYFORMAT]</span> SSH 公開鍵の検証処理 - [see:F2X8-KEYTYPE](requirements.md#F2X8-KEYTYPE)
  - Post-install/Post-upgrade Hook で Secret から `authorized_keys` 内容を読み取り検証を実施
  - Hook 実行のため専用 ServiceAccount に Secret の読み出し権限（get）を付与
  - 権限関連リソース（ServiceAccount、Role、RoleBinding）は hook-delete-policy により Hook 実行完了後に自動削除
  - `ssh-keygen -lf` コマンドで各鍵の暗号学的検証を実施
  - RSA: 2048bit未満の鍵は拒否、4096bit推奨
  - Ed25519: セキュリティと性能の観点から優先される形式
  - 無効な鍵が含まれる場合は適切なエラーメッセージを出力して Hook を失敗させ、リリースステータスを failed にする

- <span id="M8Q5-NOTES">[M8Q5-NOTES]</span> 検証失敗時のトラブルシューティング案内を `NOTES.txt` に記載する
  - SSH 公開鍵の検証を Post-install/Post-upgrade Hook で実施するため、検証失敗時の詳細情報は Hook のログでのみ確認可能
  - Helm のエラーメッセージはカスタマイズできないため、詳細なエラー情報は Hook のログで確認する必要がある
  - `NOTES.txt` に Hook のログ確認方法を記載し、ユーザーがトラブルシューティングを実施できるようにする
  - install/upgrade 失敗時の具体的な対処手順を提供

- <span id="D4K3-KEYMOUNT">[D4K3-KEYMOUNT]</span> SSH 公開鍵は K8s Secret から readOnly でマウントされ、起動時に適切な場所にコピーされる
  - Secret は `/mnt/ssh-public-keys/` に readOnly でマウントされる
  - 起動時にスクリプトが `~/.ssh/authorized_keys` にコピーし、適切な権限（0600）を設定
  - readOnly マウントにより Secret の意図しない変更を防止
  - コピー時の権限設定により、ユーザ固有の所有者設定とSSHクライアントの要求する権限を満たす

- <span id="R2L7-PRIVKEY">[R2L7-PRIVKEY]</span> ユーザの SSH 秘密鍵は `values.yaml` で直接指定または既存 Secret 参照により K8s Secret に保存する - [see:W7N2-PRIVKEY](requirements.md#W7N2-PRIVKEY), [see:Q9M4-MULTIPRIVKEY](requirements.md#Q9M4-MULTIPRIVKEY), [see:C3J6-PRIVMOUNT](requirements.md#C3J6-PRIVMOUNT)
  - SSH クライアント接続用の秘密鍵として利用
  - `values.yaml` でファイル名と内容を直接指定可能
  - `values.yaml` で既存 Secret 名を指定して参照可能、未指定時はデフォルト名（`{{ .Release.Name }}-ssh-privkeys`）を使用
  - 複数の秘密鍵を異なるファイル名（`id_rsa`, `id_ed25519`, カスタム名等）で設定可能
  - 公開鍵と秘密鍵で共通の Secret を指定することも可能
  - Helm テンプレートで K8s Secret に保存

- <span id="T6K9-PRIVFORMAT">[T6K9-PRIVFORMAT]</span> SSH 秘密鍵の検証処理 - [see:F2X8-KEYTYPE](requirements.md#F2X8-KEYTYPE), [see:D5K8-PRIVTYPE](requirements.md#D5K8-PRIVTYPE)
  - Post-install/Post-upgrade Hook で Secret から秘密鍵内容を読み取り検証を実施
  - `ssh-keygen -lf` コマンドで各鍵の暗号学的検証を実施
  - RSA: 2048bit未満の鍵は拒否、4096bit推奨
  - Ed25519: セキュリティと性能の観点から優先される形式
  - 無効な鍵が含まれる場合は適切なエラーメッセージを出力して Hook を失敗させ、リリースステータスを failed にする

- <span id="L9K4-KEYDUP">[L9K4-KEYDUP]</span> 公開鍵と秘密鍵で異なる Secret が指定された場合のキー重複チェック
  - Post-install/Post-upgrade Hook で公開鍵と秘密鍵のシークレットキーの重複確認を実施
  - 異なる Secret を指定した場合のみ、それぞれのシークレットキーに重複がないことを確認
  - マウント時の鍵の意図しない上書きを防止するための検証
  - 重複するキーが検出された場合は適切なエラーメッセージを出力して Hook を失敗させ、リリースステータスを failed にする

- <span id="B8W3-PRIVMOUNT">[B8W3-PRIVMOUNT]</span> SSH 秘密鍵は K8s Secret から readOnly でマウントされ、起動時に適切な場所にコピーされる - [see:C3J6-PRIVMOUNT](requirements.md#C3J6-PRIVMOUNT)
  - Secret は `/mnt/ssh-private-keys/` に readOnly でマウントされる
  - 起動時にスクリプトが指定されたファイル名で `~/.ssh/` にコピーし、適切な権限（0600）を設定
  - readOnly マウントにより Secret の意図しない変更を防止
  - コピー時の権限設定により、ユーザ固有の所有者設定とSSHクライアントの要求する権限を満たす

#### ヘルスチェックプローブについて

- <span id="L3F8-LIVENESS">[L3F8-LIVENESS]</span> Liveness Probe（再起動判定） - [see:Q1P4-HEALTH](requirements.md#Q1P4-HEALTH)
  - TCP Socket Probe を使用してポート 2222 への接続性を確認
  - kubelet が SSH サービスの基本的な動作を外部から監視

- <span id="R6Q9-READINESS">[R6Q9-READINESS]</span> Readiness Probe（トラフィック受付判定） - [see:Q1P4-HEALTH](requirements.md#Q1P4-HEALTH)
  - Exec Probe を使用してコンテナ内部の詳細な状態を確認
  - ヘルスチェックスクリプトによる包括的な健全性チェック
  - ヘルスチェックスクリプトの実装：
    - Dropbear プロセスの存在確認（`pgrep dropbear`）
    - SSH ポートのリスニング状態確認（`ss -ln` コマンドを使用）
    - SSH ホストキーの存在確認（`${DROPBEAR_DIR}/dropbear_rsa_host_key`, `${DROPBEAR_DIR}/dropbear_ed25519_host_key`）
    - `DROPBEAR_DIR="/home/${USERNAME}/.ssh/dropbear"` で定義される場所をチェック
    - デフォルトでは `/home/developer/.ssh/dropbear/` 配下のホストキーファイルを確認
    - 実行はコンテナ内部で行われ、kubelet が Container Runtime Interface 経由でコマンドを実行

#### Secret マウント戦略について

- <span id="M7X3-MOUNTSTRATEGY">[M7X3-MOUNTSTRATEGY]</span> SSH 鍵の Secret マウント戦略
  - **中間ディレクトリマウント + 起動時コピー方式**を採用
  - Secret は中間ディレクトリ（`/mnt/ssh-*`）に readOnly でマウント
  - 起動時スクリプトが最終的な配置場所にコピーし、適切な権限とオーナーシップを設定
  
**この方式の利点：**
- **セキュリティ強化**: Secret の直接変更を完全に防止（readOnly マウント）
- **権限制御の柔軟性**: ユーザ固有のUID/GIDに合わせた所有者設定が可能
- **ファイル権限の正確性**: SSH やDropbear の要求する正確な権限（0600）を保証
- **設定の独立性**: Secret の内容とファイルシステム上の配置を分離
- **トラブルシューティング**: 中間ディレクトリで Secret の内容を確認可能

**直接マウントとの比較：**
- 直接マウント: Secret の defaultMode で権限は設定できるが、所有者はコンテナの実行ユーザに固定
- コピー方式: 動的なユーザ作成後に適切な所有者を設定可能、より柔軟な権限管理

#### Secret/ConfigMap 変更時のPod再起動について

- <span id="Z8Y4-RESTART">[Z8Y4-RESTART]</span> Secret や ConfigMap が変更された際に Pod を自動的に再起動する仕組み
  - Pod のアノテーションにチェックサムを追加することで実現
  - Helm で管理される Secret が更新されると、チェックサムが変更され、Deployment のテンプレートが更新される
  - これにより Kubernetes が Pod を再作成し、新しい Secret/ConfigMap が反映される
  - 対象となる Secret：
    - SSH 公開鍵 (ssh-pubkeys)
    - SSH 秘密鍵 (ssh-privkeys) ※設定されている場合
    - 設定全体のチェックサム（外部管理のSecretにも対応）

#### 各種スクリプトについて

- <span id="D8M4-SCRIPT">[D8M4-SCRIPT]</span> 初期化処理、検証処理、テスト処理は Docker イメージに同梱されたスクリプトとして実装する。
- <span id="F5K3-SCRIPTPATH">[F5K3-SCRIPTPATH]</span> 管理用スクリプトは `/opt/ssh-workspace/bin/` に配置し、ユーザの一般的なコマンドパスとは分離する

ssh workspace はライフサイクルの各段階でのテストを充実させ、後段でのトラブルの発生を極力抑える - [see:U9A4-TEST](requirements.md#U9A4-TEST)。
また、ユーザ設定の動的な処理や複雑な検証処理が必要となる - [see:Y4F1-USER](requirements.md#Y4F1-USER), [see:V5Q3-HOME](requirements.md#V5Q3-HOME), [see:N3M9-PERSIST](requirements.md#N3M9-PERSIST)。

Helm テンプレートでは表現が困難な複雑な処理や、テンプレートを肥大化させる長大な処理は、スクリプトとして実装する。

これにより Helm テンプレートの肥大化を回避し、複雑なロジックを適切に管理できる。

#### Makefile・GitHub Actions による開発統合

<span id="B6Y3-MAKEFILE">[B6Y3-MAKEFILE]</span> 本プロジェクトは Makefile でビルドとテストを統合し、GitHub Actions で Makefile を通じてビルドとテストを実行する。

**設計判断の主な理由：**
- **デバッグ容易性の確保**
  - CI/CDで失敗した処理を開発者のローカル環境で同じように実行可能
  - 段階的デバッグ（`make build`, `make test`, `make package`）による問題箇所の特定
  - GitHub Actions固有の環境変数や設定に依存しない処理の実現
- **GitHub Actions マニフェスト簡素化**
  - 複雑なビルド・テストロジックをワークフローファイルから分離
  - ビルド手順変更時はMakefileのみ修正、ワークフローは変更不要
  - YAML肥大化回避により可読性と保守性を向上

**実装方針：**

*Makefile設計*
- CI/CDとローカル開発の実行環境差異を吸収

*GitHub Actions設計*
- Docker layer cache、依存関係キャッシュを活用する
- 各処理を異なるワークフローに適切に分離して並列実行を可能にする
- マトリクスパラメータを活用して異なる環境でのテストを効率化する

**対応要件：**
- GitHub ActionsでのCI/CD実行 [see:G4H7-CICD](requirements.md#G4H7-CICD)
- ビルド・パッケージング・公開の自動化 [see:B2M7-BUILD]](requirements.md#B2M7-BUILD), [see:H6N4-PACKAGE](requirements.md#H6N4-PACKAGE), [[see:P1W9-PUBLISH](requirements.md#P1W9-PUBLISH)
- 品質保証・セキュリティテストの統合 [see:Q3L8-QUALTEST]](requirements.md#Q3L8-QUALTEST), [[see:T9K5-SECTEST](requirements.md#T9K5-SECTEST)

この実装により、複雑な処理を段階的に実行し、開発者とCI環境で一貫した品質保証を提供する。
