# Build stage for Dropbear SSH server
FROM ubuntu:22.04 AS dropbear-builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential=12.9ubuntu3 \
    wget=1.21.2-2ubuntu1.1 \
    zlib1g-dev=1:1.2.11.dfsg-2ubuntu9.2 \
    && rm -rf /var/lib/apt/lists/*

# Download and build latest Dropbear [see:K4R9-DROPBEAR]
WORKDIR /tmp
RUN wget --progress=dot:giga https://matt.ucc.asn.au/dropbear/releases/dropbear-2025.88.tar.bz2 \
    && tar -xjf dropbear-2025.88.tar.bz2 \
    && cd dropbear-2025.88 \
    && ./configure --prefix=/usr/local --enable-static \
    && make \
    && make install \
    && strip /usr/local/sbin/dropbear /usr/local/bin/dropbearkey /usr/local/bin/dropbearconvert

# Runtime stage
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages (without dropbear)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic development tools [see:Q2N5-TOOLS]
    git=1:2.34.1-1ubuntu1.12 \
    curl=7.81.0-1ubuntu1.18 \
    wget=1.21.2-2ubuntu1.1 \
    vim=2:8.2.3458-2ubuntu2.3 \
    nano=6.2-1 \
    python3=3.10.6-1~22.04.1 \
    python3-pip=22.0.2+dfsg-1ubuntu0.5 \
    # For SSH key generation and validation
    openssh-client=1:8.9p1-3ubuntu0.10 \
    # Required for user management
    sudo=1.9.9-1ubuntu2.4 \
    # Network utilities for health checks
    iproute2=5.15.0-1ubuntu2 \
    procps=2:3.3.17-6ubuntu2.1 \
    # Utilities
    ca-certificates=20240203~22.04.1 \
    locales=2.35-0ubuntu3.8 \
    tzdata=2024a-0ubuntu0.22.04.1 \
    # For hook operations
    jq=1.6-2.1ubuntu3 \
    # Runtime dependencies for Dropbear
    zlib1g=1:1.2.11.dfsg-2ubuntu9.2 \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Copy compiled Dropbear binaries from builder stage
COPY --from=dropbear-builder /usr/local/sbin/dropbear /usr/local/bin/dropbear
COPY --from=dropbear-builder /usr/local/bin/dropbearkey /usr/local/bin/dropbearkey
COPY --from=dropbear-builder /usr/local/bin/dropbearconvert /usr/local/bin/dropbearconvert

# Make Dropbear binaries available in PATH and install kubectl
RUN ln -s /usr/local/bin/dropbear /usr/bin/dropbear \
    && ln -s /usr/local/bin/dropbearkey /usr/bin/dropbearkey \
    && ln -s /usr/local/bin/dropbearconvert /usr/bin/dropbearconvert \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create directories and copy scripts [see:F5K3-SCRIPTPATH] [see:D8M4-SCRIPT]
RUN mkdir -p /opt/ssh-workspace/bin /etc/dropbear

# Copy management scripts [see:D8M4-SCRIPT]
COPY docker/scripts/* /opt/ssh-workspace/bin/
RUN chmod +x /opt/ssh-workspace/bin/*

# Expose SSH port (non-privileged) [see:B3Q8-PORT]
EXPOSE 2222

# Set working directory
WORKDIR /home

# Default entrypoint (can be overridden by Kubernetes)
ENTRYPOINT ["/opt/ssh-workspace/bin/start-ssh-server.sh"]