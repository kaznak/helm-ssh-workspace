# Ubuntu base image for helm-ssh-workspace
# Design reference: [R8M5-UBUNTU]
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages
RUN apt-get update && apt-get install -y \
    # Dropbear SSH server [K4R9-DROPBEAR]
    dropbear \
    dropbear-bin \
    # Basic development tools [Q2N5-TOOLS]
    git \
    curl \
    wget \
    vim \
    nano \
    build-essential \
    python3 \
    python3-pip \
    # For SSH key generation and validation
    openssh-client \
    # Required for user management
    sudo \
    # Utilities
    ca-certificates \
    locales \
    tzdata \
    # For hook operations
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Install kubectl for hook operations
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create directory for management scripts [F5K3-SCRIPTPATH]
RUN mkdir -p /opt/ssh-workspace/bin

# Copy management scripts [D8M4-SCRIPT]
COPY docker/scripts/* /opt/ssh-workspace/bin/
RUN chmod +x /opt/ssh-workspace/bin/*

# Create dropbear directory
RUN mkdir -p /etc/dropbear

# Expose SSH port (non-privileged) [B3Q8-PORT]
EXPOSE 2222

# Set working directory
WORKDIR /home

# Default entrypoint
ENTRYPOINT ["/opt/ssh-workspace/bin/entrypoint.sh"]