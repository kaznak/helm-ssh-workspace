# Build stage for Dropbear SSH server
FROM ubuntu:22.04 AS dropbear-builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    zlib1g-dev \
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
    git \
    curl \
    wget \
    vim \
    nano \
    python3 \
    python3-pip \
    # For SSH key generation and validation
    openssh-client \
    # Required for user management
    sudo \
    # Network utilities for health checks
    iproute2 \
    procps \
    # Utilities
    ca-certificates \
    locales \
    tzdata \
    # For hook operations
    jq \
    # Runtime dependencies for Dropbear
    zlib1g \
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