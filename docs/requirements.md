
# 要求・要件

[背景](../README.md#背景)を踏まえ、以下の要求・要件を満たすことを目指す。
なお分類は FURPS+ モデルに基づいて行った。

## F - Functionality（機能性）

### コア機能
- <span id="P3R8-SHELL">[P3R8-SHELL]</span> シングルユーザ SSH シェルアクセス可能な開発ワークスペースを提供
- <span id="P7M2-FORWARD">[P7M2-FORWARD]</span> SSH 標準のポートフォワーディング機能を提供
  - <span id="N4C7-NETPOL">[N4C7-NETPOL]</span> ポートフォワーディングのアクセス制御は運用者がネットワークポリシーで設定

### 開発環境
- <span id="Q2N5-TOOLS">[Q2N5-TOOLS]</span> 開発ワークスペースでは様々な開発ツールを提供
  - <span id="M4J7-BREW">[M4J7-BREW]</span> 開発ワークスペースでは linuxbrew などユーザランドで動作するパッケージマネージャでインストール可能なツールはユーザランドでインストール（非特権環境での利用）

### データ管理
- <span id="V5Q3-HOME">[V5Q3-HOME]</span> ホームディレクトリは emptyDir と PersistentVolume のいずれかを values.yaml の設定値で指定してマウント
  - <span id="T1H8-EMPTY">[T1H8-EMPTY]</span> ホームディレクトリはデフォルトで emptyDir をマウント
  - <span id="R7P4-STORAGE">[R7P4-STORAGE]</span> ホームディレクトリに PersistentVolume をマウントする場合、 StorageClass は values.yaml の設定値で指定可能
  - <span id="N3M9-PERSIST">[N3M9-PERSIST]</span> ホームディレクトリに PersistentVolume をマウントする場合、 Helm release 削除後も残り、再利用可能
  - <span id="C6B2-SUBDIR">[C6B2-SUBDIR]</span> ホームディレクトリに PersistentVolume をマウントする場合、サブディレクトリのマウントも可能

### ユーザ管理
- <span id="Y4F1-USER">[Y4F1-USER]</span> ユーザ設定を values.yaml の設定値で指定可能
  - <span id="G8W5-USERNAME">[G8W5-USERNAME]</span> ユーザ設定でユーザ名を values.yaml の設定値で指定可能、デフォルトは developer
  - <span id="Z2S7-UID">[Z2S7-UID]</span> ユーザ設定で UID を values.yaml の設定値で指定可能、デフォルトは 1000
  - <span id="A9T3-GID">[A9T3-GID]</span> ユーザ設定で GID を values.yaml の設定値で指定可能、デフォルトは 1000

### セキュリティ機能
- <span id="L6H3-KEYAUTH">[L6H3-KEYAUTH]</span> 認証は SSH 公開鍵認証のみ
- <span id="F2X8-KEYTYPE">[F2X8-KEYTYPE]</span> ユーザの SSH 鍵（公開鍵・秘密鍵）は RSA (2048bit以上) と Ed25519 形式に対応
- <span id="K9T4-PUBKEY">[K9T4-PUBKEY]</span> ユーザの SSH 公開鍵を values.yaml の設定値で指定可能
- <span id="M6L5-MULTIKEY">[M6L5-MULTIKEY]</span> ユーザの 複数の SSH 公開鍵を同時に設定可能
- <span id="W7N2-PRIVKEY">[W7N2-PRIVKEY]</span> ユーザの SSH 秘密鍵を values.yaml の設定値で指定可能
- <span id="D5K8-PRIVTYPE">[D5K8-PRIVTYPE]</span> ユーザの SSH 秘密鍵は RSA (2048bit以上) と Ed25519 形式に対応
- <span id="Q9M4-MULTIPRIVKEY">[Q9M4-MULTIPRIVKEY]</span> ユーザの 複数の SSH 秘密鍵を同時に設定可能
- <span id="C3J6-PRIVMOUNT">[C3J6-PRIVMOUNT]</span> SSH 秘密鍵はホームディレクトリの .ssh/ に配置される
- <span id="V4J1-HOSTKEY">[V4J1-HOSTKEY]</span> SSH ホストキーは values.yaml の設定値でユーザが指定しない場合 helm release 作成時に生成
- <span id="R8N9-REUSE">[R8N9-REUSE]</span> SSH サーバホストキーは helm release 削除後も残り、再利用可能

## U - Usability（使いやすさ）

### 設定の容易さ
- <span id="B3Q8-PORT">[B3Q8-PORT]</span> SSH接続用のポートを values.yaml の設定値で指定可能。デフォルト2222（ユーザランド運用のため）。
- <span id="E4L7-CLUSTER">[E4L7-CLUSTER]</span> Service のアドレス種別は values.yaml の設定値で指定可能。デフォルトでは ClusterIP 。
- <span id="J1X6-LIMIT">[J1X6-LIMIT]</span> values.yaml の設定値で CPU、メモリ、ストレージの resource request/limit を指定可能

### 運用の簡単さ
- <span id="C5Q4-TEMP">[C5Q4-TEMP]</span> 必要に応じて作成し、作業が終わったら削除する運用を想定

## R - Reliability（信頼性）

### 監視・ヘルスチェック
- <span id="Q1P4-HEALTH">[Q1P4-HEALTH]</span> 基本的なヘルスチェック機能（liveness/readiness probe）を提供
- <span id="F7C8-METRICS">[F7C8-METRICS]</span> 基本的な監視メトリクスを提供（Kubernetes 標準のリソースメトリクス）
- <span id="K5G2-LOGS">[K5G2-LOGS]</span> Kubernetes のログ収集に対応

### テスト
- <span id="U9A4-TEST">[U9A4-TEST]</span> デプロイ結果が要件を全て満たしているかを確認するためのテストを提供

### バックアップ
- <span id="Z4T5-NOPROV">[Z4T5-NOPROV]</span> バックアップ・復旧機能は本プロジェクトではPVレイヤの機能として提供しない

## P - Performance（性能）

### スケーリング
- <span id="J8R2-DEPLOY">[J8R2-DEPLOY]</span> Deployment リソースで replicas 1 固定で運用（自動スケーリング無効）
  - HPA等の自動スケーリング機能は明示的に無効化し、単一replica前提での設計とする
  - SSH接続の特性上、複数インスタンスによる負荷分散が適さないため
- <span id="Y3S2-DOWN">[Y3S2-DOWN]</span> アップデートやメンテナンス時のダウンタイムを許容し、高可用性は要求しない

## S - Supportability（保守性）

### テスト容易性
- [see:U9A4-TEST](#U9A4-TEST) デプロイ結果が要件を全て満たしているかを確認するためのテストを提供

### 診断可能性
- [see:K5G2-LOGS](#K5G2-LOGS) Kubernetes のログ収集に対応

### 設定可能性
- [see:Y4F1-USER](#Y4F1-USER) ユーザ設定をvalues.yamlで柔軟に指定可能

## + 追加要素 : 実装要件（Implementation）

### CI/CD実装
- <span id="G4H7-CICD">[G4H7-CICD]</span> GitHub Actions で CI/CD を実行し、包括的な品質保証を行う

### テスト実装
- <span id="T9K5-SECTEST">[T9K5-SECTEST]</span> CI/CD パイプラインでセキュリティテストを実行
- <span id="Q3L8-QUALTEST">[Q3L8-QUALTEST]</span> CI/CD パイプラインで品質保証のためのテストを実行

### ビルド・パブリッシュ実装
- <span id="B2M7-BUILD">[B2M7-BUILD]</span> CI/CD パイプラインで Docker イメージのビルドを実行
- <span id="H6N4-PACKAGE">[H6N4-PACKAGE]</span> CI/CD パイプラインで Helm チャートのパッケージングを実行
- <span id="P1W9-PUBLISH">[P1W9-PUBLISH]</span> CI/CD パイプラインで成果物のパブリッシュを実行

## + 追加要素 : インターフェース要件（Interface）

### ネットワーク
- <span id="W9F5-SERVICE">[W9F5-SERVICE]</span> Service リソースから利用される想定。
- <span id="N4V9-SVC">[N4V9-SVC]</span> Service を提供、デフォルトで ClusterIP アドレスを提供

### 外部連携（提供しない）
- <span id="S6R1-EXTERNAL">[S6R1-EXTERNAL]</span> 外部アクセス機能は外付けで運用する想定であり、Helm チャートでは提供しない。
  - <span id="U8N4-INGRESS">[U8N4-INGRESS]</span> 外部アクセス機能として Ingress リソースは外付けで運用
  - <span id="I2M6-NETPOL">[I2M6-NETPOL]</span> 外部アクセス機能として NetworkPolicy リソースは外付けで運用

## + 追加要素 : 運用要件（Operational）

### デプロイ構成
- <span id="H1C6-NOING">[H1C6-NOING]</span> Ingress リソースは提供しない
- <span id="B7X5-NONP">[B7X5-NONP]</span> NetworkPolicy リソースは提供しない

## + 追加要素 : パッケージング要件（Packaging）

### リリース形態
- <span id="W5I2-HELM">[W5I2-HELM]</span> 本製品は Docker イメージと Helm チャートを提供
