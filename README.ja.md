# helm-ssh-workspace

Dropbear SSH サーバを利用したセキュアな ssh ワークスペースを提供する Helm チャートおよび Docker イメージ。

- Dropbear SSH
  - https://github.com/mkj/dropbear
  - https://matt.ucc.asn.au/dropbear/dropbear.html

## 背景

CLI 型の AI エージェントと共同開発を行うためには、シェルアクセスが必要である。
SSH サーバとして OpenSSH が広く使われているが、Kubernetes 上での運用には以下の課題がある。

- sshd は特権プロセスとしての運用を前提として開発されており、ユーザランドでの運用が困難
- 特権システムコールを利用した権限管理機能が実装されており、これを活用するには特権が必要

よりシンプルな SSH サーバである Dropbear SSH を利用することで、Kubernetes 上での運用が容易になると期待される。 Dropbear SSH はユーザランドでの運用が可能であり、特権システムコールを利用しないため、Kubernetes 上での運用に適していると思われる。
