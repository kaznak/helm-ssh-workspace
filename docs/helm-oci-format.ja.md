# Helm Chart OCI形式ガイド

## 🎯 OCI形式とは？

OCI (Open Container Initiative) 形式は、Helm ChartをDockerイメージと同じコンテナレジストリに保存できる仕組みです。同じインフラとプロトコルを使用します。

## 📊 従来形式 vs OCI形式

### 従来のHelmリポジトリ
```
https://charts.example.com/
├── index.yaml                 # チャートインデックスファイル
├── ssh-workspace-1.0.0.tgz   # チャートパッケージ
├── ssh-workspace-1.0.1.tgz   # チャートパッケージ
└── ssh-workspace-1.0.2.tgz   # チャートパッケージ
```

### OCIレジストリ構造
```
ghcr.io/username/charts/
└── ssh-workspace
    ├── 1.0.0     # チャートマニフェスト + レイヤー
    ├── 1.0.1     # チャートマニフェスト + レイヤー
    └── latest    # 最新バージョンを指すタグ
```

## 🔄 OCI形式の仕組み

### 1. **ChartをContainerイメージとして扱う**
```yaml
# ChartはOCIアーティファクトとしてパッケージ化
mediaType: application/vnd.oci.image.manifest.v1+json
config:
  mediaType: application/vnd.cncf.helm.config.v1+json
layers:
  - mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    digest: sha256:abc123...
    size: 12345
```

### 2. **保存構造**
- **Manifest**: チャートのメタデータを記述
- **Config**: Chart.yamlの内容
- **Layers**: 圧縮されたチャート内容（templates、valuesなど）

## 💻 使用例

### 従来の方法
```bash
# リポジトリを追加
helm repo add myrepo https://charts.example.com
helm repo update

# チャートを検索
helm search repo myrepo/

# チャートをインストール
helm install release-name myrepo/ssh-workspace --version 1.0.0

# チャートをダウンロード
helm pull myrepo/ssh-workspace --version 1.0.0
```

### OCI方式
```bash
# リポジトリ追加は不要！

# 直接チャートをインストール
helm install release-name oci://ghcr.io/username/charts/ssh-workspace --version 1.0.0

# チャートをダウンロード
helm pull oci://ghcr.io/username/charts/ssh-workspace --version 1.0.0

# チャートをプッシュ
helm push ssh-workspace-1.0.0.tgz oci://ghcr.io/username/charts
```

## 🎨 主な違い

| 機能 | 従来形式 | OCI形式 |
|------|---------|---------|
| **リポジトリ管理** | `helm repo add`が必要 | 直接URL指定 |
| **インデックスファイル** | 中央集約型index.yaml | インデックス不要 |
| **保存場所** | Webサーバー | コンテナレジストリ |
| **認証** | Basic認証/トークン | Docker login |
| **バージョン管理** | ファイルベース | タグベース |
| **キャッシュ** | ローカルリポジトリキャッシュ | レジストリキャッシュ |

## 🚀 OCI形式の利点

### 1. **統一されたインフラ**
- DockerイメージとHelm Chartで同じレジストリ
- 単一の認証メカニズム
- 一貫したアクセス制御

### 2. **パフォーマンス向上**
- コンテンツアドレス可能なストレージ
- レイヤーの重複排除
- 効率的なキャッシング

### 3. **セキュリティ強化**
- イメージ署名のサポート
- 脆弱性スキャン
- レジストリ経由のアクセス制御

### 4. **管理の簡素化**
- 別途Helmリポジトリ不要
- 自動ガベージコレクション
- 組み込みレプリケーション

## 🔧 レジストリサポート

### フルサポート
- **Docker Hub**: 完全なOCIサポート
- **GitHub Container Registry (GHCR)**: 推奠
- **Azure Container Registry (ACR)**: フルサポート
- **Amazon ECR**: フルサポート
- **Google Artifact Registry**: フルサポート
- **Harbor**: v2.0以降でOCIサポート

### 設定例

#### GitHub Container Registry
```bash
# ログイン
helm registry login ghcr.io -u USERNAME -p TOKEN

# プッシュ
helm push mychart-1.0.0.tgz oci://ghcr.io/username/charts

# インストール
helm install release oci://ghcr.io/username/charts/mychart --version 1.0.0
```

#### Docker Hub
```bash
# ログイン
helm registry login docker.io -u USERNAME -p PASSWORD

# プッシュ
helm push mychart-1.0.0.tgz oci://docker.io/username

# インストール
helm install release oci://docker.io/username/mychart --version 1.0.0
```

## 📝 移行ガイド

### 従来形式からOCIへ

1. **既存チャートをパッケージ化**
   ```bash
   helm package ./mychart
   ```

2. **レジストリにログイン**
   ```bash
   helm registry login ghcr.io -u USERNAME -p TOKEN
   ```

3. **OCIレジストリにプッシュ**
   ```bash
   helm push mychart-1.0.0.tgz oci://ghcr.io/username/charts
   ```

4. **ドキュメントを更新**
   ```bash
   # 旧
   helm install release myrepo/mychart
   
   # 新
   helm install release oci://ghcr.io/username/charts/mychart
   ```

## ⚠️ 注意事項

### 制限事項
- **Helm 3.8以降**が必要
- **ブラウジング不可**: レジストリAPIなしではチャート一覧不可
- **検索不可**: `helm search`はOCIで動作しない

### ベストプラクティス
1. **セマンティックバージョニング使用**: 適切なバージョンでタグ付け
2. **チャート署名**: cosignでチャート署名
3. **公開の自動化**: CI/CDで一貫したリリース
4. **レジストリURLの文書化**: ユーザーが見つけやすくする

## 🔍 OCIの問題解決

### よくある問題

1. **認証失敗**
   ```bash
   # Dockerログインを確認
   docker login ghcr.io
   
   # またはHelmレジストリログイン
   helm registry login ghcr.io
   ```

2. **チャートが見つからない**
   ```bash
   # 正確なURLを確認
   helm show chart oci://ghcr.io/username/charts/mychart --version 1.0.0
   ```

3. **バージョンの問題**
   ```bash
   # 利用可能なバージョンを確認（レジストリがサポートしている場合）
   crane ls ghcr.io/username/charts/mychart
   ```

## 📚 参考資料

- [OCI Distribution仕様](https://github.com/opencontainers/distribution-spec)
- [Helm OCIドキュメント](https://helm.sh/docs/topics/registries/)
- [CNCF OCIアーティファクト](https://github.com/opencontainers/artifacts)