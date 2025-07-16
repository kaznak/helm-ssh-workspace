# Build stage for Dropbear SSH server
FROM ubuntu:22.04 AS dropbear-builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    ca-certificates \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and build latest Dropbear [see:K4R9-DROPBEAR]
WORKDIR /tmp
# hadolint ignore=DL3003
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

# Install ubuntu-standard meta-package and additional packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ubuntu-standard \
    # Additional packages not in ubuntu-standard [see:Q2N5-TOOLS]
    git \
    curl \
    vim \
    python3 \
    python3-pip \
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
    # Additional tools for Nix installation script
    tar \
    coreutils \
    openssl \
    # Network and diagnostic tools
    iputils-ping \
    net-tools \
    # Security and authentication
    gnupg \
    # System information
    lsb-release \
    # Development tools (runtime stage needs its own build-essential)
    build-essential \
    # File operations
    unzip \
    zip \
    # Text viewing and file management
    less \
    stow \
    # Recommended packages from ubuntu-standard that we need
    nano \
    openssh-client \
    # Container tools [see:H9L2-PODMAN]
    podman \
    buildah \
    skopeo \
    fuse-overlayfs \
    uidmap \
    slirp4netns \
    crun \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Copy compiled Dropbear binaries from builder stage
COPY --from=dropbear-builder /usr/local/sbin/dropbear /usr/local/bin/dropbear
COPY --from=dropbear-builder /usr/local/bin/dropbearkey /usr/local/bin/dropbearkey
COPY --from=dropbear-builder /usr/local/bin/dropbearconvert /usr/local/bin/dropbearconvert

# Make Dropbear binaries available in PATH and install kubectl and docker-compose
RUN ln -s /usr/local/bin/dropbear /usr/bin/dropbear \
    && ln -s /usr/local/bin/dropbearkey /usr/bin/dropbearkey \
    && ln -s /usr/local/bin/dropbearconvert /usr/bin/dropbearconvert \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/ \
    && curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose \
    && pip3 install --no-cache-dir podman-compose==1.5.0

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create directories for scripts and container environment [see:F5K3-SCRIPTPATH] [see:D8M4-SCRIPT] [see:H9L2-PODMAN]
RUN mkdir -p /opt/ssh-workspace/bin /etc/dropbear /etc/containers

# Copy Podman configuration files (always installed for potential use)
COPY docker/configs/containers/storage.conf /etc/containers/storage.conf
COPY docker/configs/containers/registries.conf /etc/containers/registries.conf

# Copy management scripts and templates [see:D8M4-SCRIPT]
COPY docker/scripts/* /opt/ssh-workspace/bin/
COPY docker/templates/ /opt/ssh-workspace/templates/

# Setup skeleton files for container tools [see:H9L2-PODMAN]
RUN chmod +x /opt/ssh-workspace/bin/* && \
    chmod +x /opt/ssh-workspace/templates/skel/.local/bin/docker && \
    # Setup Podman skeleton files
    mkdir -p /etc/skel/.bashrc.d /etc/skel/.local/bin && \
    cp /opt/ssh-workspace/templates/skel/.bashrc.d/podman.sh /etc/skel/.bashrc.d/podman.sh && \
    cp /opt/ssh-workspace/templates/skel/.local/bin/docker /etc/skel/.local/bin/docker && \
    chmod +x /etc/skel/.local/bin/docker && \
    cat /opt/ssh-workspace/templates/skel/bashrc.append >> /etc/skel/.bashrc

# Expose SSH port (non-privileged) [see:B3Q8-PORT]
EXPOSE 2222

# Set working directory
WORKDIR /home

# Default entrypoint (can be overridden by Kubernetes)
ENTRYPOINT ["/opt/ssh-workspace/bin/start-ssh-server.sh"]