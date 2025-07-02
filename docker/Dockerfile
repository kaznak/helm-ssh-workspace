FROM ubuntu:22.04

# メタデータ
LABEL maintainer="SSH Workspace" \
      description="SSH accessible workspace environment" \
      version="1.0.0"

# 非対話的インストールのため
ENV DEBIAN_FRONTEND=noninteractive

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    tzdata \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    ca-certificates \
    rsync \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && rm -f /etc/ssh/ssh_host_*_key* \
    && rm -f /etc/ssh/ssh_host_*_key.pub \
    && find / -name "ssh_host_*_key*" -delete 2>/dev/null || true

# SSH設定
RUN mkdir -p /etc/ssh/sshd_config.d
COPY config/sshd_config /etc/ssh/sshd_config

# アプリケーションディレクトリ作成
RUN mkdir -p /opt/ssh-workspace/bin

# スクリプト類をアプリケーション専用ディレクトリにコピー
COPY scripts/ /opt/ssh-workspace/bin/
RUN chmod +x /opt/ssh-workspace/bin/*.sh

# 権限分離用ディレクトリ
RUN mkdir -p /var/empty && \
    chown root:root /var/empty && \
    chmod 755 /var/empty

# デフォルトタイムゾーン設定
ENV TZ=UTC

# SSH ポート
EXPOSE 22

# エントリーポイント
ENTRYPOINT ["/opt/ssh-workspace/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]