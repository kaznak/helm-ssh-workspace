- values.yaml の構成の整理
- makefile の sentry target の整備
  - image のロードで正しく動かない現象が発生
- バージョン番号の振り方のポリシーの決定
  - chart/app 両方
  - イメージタグの振り方修正
- kube score のルールの修正
- 実際に接続してのツール類の挙動テストの追加
- makefile 中のテストのスクリプト化
- makefile のスクリプトのブラッシュアップ
- workflow の整理とブラッシュアップ
- workflow からは極力 makefile を呼ぶようにする
- workflow 内の actions の整理
  - 公式の actions 以外は使わない
- テストの整理と helm test で実行可能にする
- openssh でやれないか確認
