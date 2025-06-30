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
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# SSH設定
RUN mkdir -p /etc/ssh/sshd_config.d
COPY sshd_config /etc/ssh/sshd_config

# SSH ホストキー生成用スクリプト
COPY generate-host-keys.sh /usr/local/bin/generate-host-keys.sh
RUN chmod +x /usr/local/bin/generate-host-keys.sh

# エントリーポイントスクリプト
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 権限分離用ディレクトリ
RUN mkdir -p /var/empty && \
    chown root:root /var/empty && \
    chmod 755 /var/empty

# デフォルトタイムゾーン設定
ENV TZ=UTC

# SSH ポート
EXPOSE 22

# エントリーポイント
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]