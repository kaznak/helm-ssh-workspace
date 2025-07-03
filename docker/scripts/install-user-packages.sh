#!/bin/bash
#
# SSH Workspace Development Tools Installation Script
# 
# This script installs commonly used development tools for SSH workspaces.
# It assumes that package managers (Homebrew, NVM, Rust) are already installed.
#
# Usage: ./install-user-packages.sh
#
# Prerequisites:
# - Run user-package-managers.sh first to install Homebrew, NVM, and Rust
# - Ensure ~/.bashrc is sourced or run: source ~/.bashrc
#

set -euo pipefail

NODE_VERSION="${NODE_VERSION:-20}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if package managers are available
    if ! command -v brew >/dev/null 2>&1; then
        log_error "Homebrew not found. Please run user-package-managers.sh first."
        exit 1
    fi
    
    if ! command -v nvm >/dev/null 2>&1; then
        log_error "NVM not found. Please run user-package-managers.sh first and source ~/.bashrc."
        exit 1
    fi
    
    if ! command -v rustup >/dev/null 2>&1; then
        log_error "Rust not found. Please run user-package-managers.sh first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Install Homebrew packages
install_homebrew_packages() {
    log_info "Installing Homebrew packages..."
    
    # Load Homebrew environment
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
    
    # Command line tools
    log_info "Installing command line tools..."
    brew install \
        ripgrep \
        jq \
        stow \
        htop \
        tree \
        tmux \
        screen
    
    # Kubernetes tools
    log_info "Installing Kubernetes tools..."
    brew install \
        kubectl \
        helm \
        kustomize \
        helmfile \
        sops \
        age \
        talosctl
    
    # Python tools
    log_info "Installing Python tools..."
    brew install uv
    
    # Ontology tools
    log_info "Installing ontology tools..."
    brew install \
        raptor \
        jena
    
    log_success "Homebrew packages installed"
}

# Install Helm plugins
install_helm_plugins() {
    log_info "Installing Helm plugins..."
    
    helm plugin install https://github.com/databus23/helm-diff || log_warning "helm-diff plugin already installed or failed"
    helm plugin install https://github.com/aslafy-z/helm-git || log_warning "helm-git plugin already installed or failed"
    helm plugin install https://github.com/hypnoglow/helm-s3.git || log_warning "helm-s3 plugin already installed or failed"
    helm plugin install https://github.com/jkroepke/helm-secrets || log_warning "helm-secrets plugin already installed or failed"
    
    log_success "Helm plugins installed"
}

# Install Node.js packages
install_node_packages() {
    log_info "Installing Node.js packages..."
    
    # Load NVM environment
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install and use Node.js
    nvm install $NODE_VERSION
    nvm use $NODE_VERSION
    
    # Install global npm packages
    npm install -g @anthropic-ai/claude-code || log_warning "Claude Code installation failed"
    
    log_success "Node.js packages installed"
}

# Install Rust packages
install_rust_packages() {
    log_info "Installing Rust packages..."
    
    # Load Rust environment
    source "$HOME/.cargo/env"
    
    # Configure Rust
    rustup default stable
    rustup component add rustfmt clippy
    
    # Install Rust packages
    cargo install cargo-edit cargo-watch
    
    log_success "Rust packages installed"
}

# Main execution
main() {
    log_info "Starting SSH Workspace development tools installation..."
    
    check_prerequisites
    install_homebrew_packages
    install_helm_plugins
    install_node_packages
    install_rust_packages
    
    log_success "All development tools installed successfully!"
    log_info "Restart your shell or run: source ~/.bashrc"
    log_info "Available tools: kubectl, helm, ripgrep, jq, stow, htop, tree, tmux, screen, uv, claude-code, and more"
}

# Run main function
main "$@"
