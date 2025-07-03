# Kubernetes PVC SubPath マウント機能の分析

作成日: 2025-01-03T14:00:00+09:00

## 概要

KubernetesはPersistent Volume Claim (PVC)のサブディレクトリをマウントする機能として`subPath`プロパティを提供しています。これにより、ボリューム全体ではなく特定のサブディレクトリのみをコンテナにマウントすることが可能です。

## 1. PVCのサブディレクトリマウントは可能か？

**はい、可能です。** Kubernetesの`subPath`機能を使用することで、既存のPVCから特定のサブディレクトリをマウントできます。

### 主な用途
- 単一のPVCを複数のコンテナで共有（異なるサブディレクトリを使用）
- 既存のコンテンツを保持したままデータを追加
- ConfigMapやSecretから特定のファイルのみをマウント
- 共有ストレージボリューム内でアプリケーション固有のディレクトリを作成

## 2. 技術的な制限事項と要件

### 主な制限事項

#### 2.1 動的更新の非対応
- ConfigMapをsubPathでマウントした場合、ConfigMapの変更が自動的に反映されない
- Secretの更新も同様に自動反映されない
- Downward APIのフィールド値変更も反映されない
- 最新の内容を取得するにはPodの再起動が必要

#### 2.2 セキュリティ上の考慮事項
- **CVE-2017-1002101**（2018年3月12日公開）: subPathボリュームマウントを使用するコンテナが、ボリューム外のファイルにアクセスできる脆弱性があった（現在は修正済み）
- hostPathボリュームタイプとの併用は多くのセキュリティリスクを伴う
- PodSecurityPolicyはsubPathを使用したhostPathの制限を効果的に行えない

#### 2.3 その他の技術的制限
- subPathとsubPathExprは相互排他的（同時に使用不可）
- パスの検証とバインドマウント間のTOCTTOU（Time-of-Check-to-Time-of-Use）問題の可能性
- Podを削除してもPVC上のsubPath内のデータは削除されない

### 要件
- Kubernetes 1.3以降でsubPath機能が利用可能
- ボリュームプラグインがsubPathをサポートしている必要がある
- 適切なファイルシステム権限の設定

## 3. YAML設定例

### 基本的な使用例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-lamp-site
spec:
  containers:
    # MySQLコンテナ - mysqlサブディレクトリをマウント
    - name: mysql
      image: mysql
      env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpasswd"
      volumeMounts:
        - mountPath: /var/lib/mysql
          name: site-data
          subPath: mysql
    
    # PHPコンテナ - htmlサブディレクトリをマウント
    - name: php
      image: php:7.0-apache
      volumeMounts:
        - mountPath: /var/www/html
          name: site-data
          subPath: html
  
  volumes:
    - name: site-data
      persistentVolumeClaim:
        claimName: my-lamp-site-data
```

### 複数のマウントポイントの例

同じPVCから異なるサブディレクトリを複数の場所にマウント：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
    - name: nginx
      image: nginx
      volumeMounts:
        # HTMLコンテンツ用
        - name: config
          mountPath: /usr/share/nginx/html
          subPath: html
        
        # Nginx設定ファイル用
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
  
  volumes:
    - name: config
      persistentVolumeClaim:
        claimName: nginx-config-pvc
```

### ConfigMapとsubPathの使用例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
spec:
  containers:
    - name: app
      image: busybox
      command: [ "sh", "-c", "ls -la /etc/config/" ]
      volumeMounts:
        - name: config-volume
          mountPath: /etc/config/app.conf
          subPath: app.conf
  
  volumes:
    - name: config-volume
      configMap:
        name: app-config
        items:
          - key: application.properties
            path: app.conf
```

### 動的なsubPathの例（subPathExpr使用）

環境変数を使用して動的にsubPathを構築：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-subpath-expr
spec:
  containers:
    - name: app
      image: busybox
      env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
      volumeMounts:
        - name: workdir
          mountPath: /logs
          subPathExpr: $(POD_NAME)
  
  volumes:
    - name: workdir
      persistentVolumeClaim:
        claimName: shared-pvc
```

## 推奨事項

1. **本番環境での使用**: 特定のユースケース（LAMPスタックの例など）は本番環境での使用が推奨されない場合があるため、慎重に評価する
2. **更新が必要な場合**: ConfigMapやSecretの更新が必要な場合は、subPathの使用を避けるか、Pod再起動の運用を考慮する
3. **セキュリティ**: hostPathボリュームとの併用は避ける
4. **データ管理**: subPath内のデータはPod削除後も残るため、適切なクリーンアップ戦略を計画する

## まとめ

KubernetesのsubPath機能は、PVCのサブディレクトリをマウントする強力な機能を提供しますが、動的更新の非対応やセキュリティ上の考慮事項など、いくつかの制限があります。適切なユースケースで使用し、制限事項を理解した上で実装することが重要です。