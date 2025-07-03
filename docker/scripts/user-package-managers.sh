#!/bin/bash
#
# SSH Workspace User Package Managers Setup Script
# 
# This script installs Linuxbrew (Homebrew), Node.js via NVM, and Rust
# for development environments in SSH Workspace containers.
#
# Usage: ./user-package-managers.sh [--homebrew-only] [--node-only] [--rust-only]
#
# Security considerations:
# - Downloads from official repositories with HTTPS
# - Verifies installations before proceeding
# - Uses official installation methods
# - No sudo/root privileges required
#

set -euo pipefail

# Default versions - can be overridden by environment variables
NVM_VERSION="${NVM_VERSION:-v0.39.0}"
NODE_VERSION="${NODE_VERSION:-20}"
BASH_ENV="${BASH_ENV:-.bash_env}"

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

# Error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
        log_info "Check the error messages above for details"
    fi
}
trap cleanup EXIT

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    # Check required commands
    for cmd in git curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Check network connectivity
    if ! curl -s --connect-timeout 5 https://github.com >/dev/null; then
        log_error "Network connectivity check failed"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Setup bash environment
setup_bash_env() {
    log_info "Setting up bash environment..."
    
    touch "$HOME/$BASH_ENV"
    
    # Remove existing entry and add fresh one
    if grep -q "\. \"\$HOME/$BASH_ENV\"" ~/.bashrc 2>/dev/null; then
        sed -i "/\. \"\$HOME\/$BASH_ENV\"/d" ~/.bashrc
    fi
    echo ". \$HOME/$BASH_ENV" >> ~/.bashrc
    
    log_success "Bash environment configured"
}

# Install Homebrew
install_homebrew() {
    log_info "Installing Homebrew..."
    
    if [ -d "$HOME/.linuxbrew" ] || command -v brew >/dev/null 2>&1; then
        log_warning "Homebrew is already installed. Skipping Homebrew setup."
        return 0
    fi
    
    # Use official installation script for better security
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Set up environment
    if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        echo "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> "$HOME/$BASH_ENV"
    else
        log_error "Homebrew installation failed"
        return 1
    fi
    
    # Update and configure
    brew update --force --quiet
    
    # Fix permissions if zsh directory exists
    if [ -d "$(brew --prefix)/share/zsh" ]; then
        chmod -R go-w "$(brew --prefix)/share/zsh" 2>/dev/null || true
    fi
    
    log_success "Homebrew installed successfully"
}

# Install NVM and Node.js
install_node() {
    log_info "Installing NVM and Node.js..."
    
    if [ -d "$HOME/.nvm" ]; then
        log_warning "NVM is already installed. Skipping NVM setup."
        return 0
    fi
    
    # Validate NVM version format
    if [[ ! "$NVM_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid NVM_VERSION format: $NVM_VERSION (expected: v0.39.0)"
        return 1
    fi
    
    # Download and install NVM
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | \
        PROFILE="$HOME/$BASH_ENV" bash
    
    # Verify installation
    if [ ! -f "$HOME/.nvm/nvm.sh" ]; then
        log_error "NVM installation failed"
        return 1
    fi
    
    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Create .nvmrc with Node version
    echo "$NODE_VERSION" > "$HOME/.nvmrc"
    
    # Install Node.js
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    
    # Install useful global packages
    log_info "Installing global npm packages..."
    npm install -g npm@latest
    
    # Optional: Install Claude Code if available
    if npm view @anthropic-ai/claude-code version >/dev/null 2>&1; then
        npm install -g @anthropic-ai/claude-code
        log_success "Claude Code installed"
    else
        log_warning "Claude Code package not available, skipping"
    fi
    
    log_success "Node.js $(node --version) installed successfully"
}

# Install Rust
install_rust() {
    log_info "Installing Rust..."
    
    if [ -d "$HOME/.cargo" ]; then
        log_warning "Rust is already installed. Skipping Rust setup."
        return 0
    fi
    
    # Install Rust using official installer
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- --default-toolchain stable --profile default -y
    
    # Verify installation
    if [ ! -f "$HOME/.cargo/env" ]; then
        log_error "Rust installation failed"
        return 1
    fi
    
    # Set up environment
    if grep -q "source \$HOME/.cargo/env" "$HOME/$BASH_ENV" 2>/dev/null; then
        sed -i "/source \$HOME\/.cargo\/env/d" "$HOME/$BASH_ENV"
    fi
    echo "source \$HOME/.cargo/env" >> "$HOME/$BASH_ENV"
    
    # Load Rust environment
    source "$HOME/.cargo/env"
    
    log_success "Rust $(rustc --version | cut -d' ' -f2) installed successfully"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install development package managers for SSH Workspace.

OPTIONS:
    --homebrew-only    Install only Homebrew
    --node-only        Install only NVM and Node.js  
    --rust-only        Install only Rust
    --help            Show this help message

ENVIRONMENT VARIABLES:
    NVM_VERSION       NVM version to install (default: v0.39.0)
    NODE_VERSION      Node.js version to install (default: 20)
    BASH_ENV          Bash environment file (default: .bash_env)

EXAMPLES:
    $0                     # Install all package managers
    $0 --homebrew-only     # Install only Homebrew
    NODE_VERSION=18 $0     # Install with Node.js 18

EOF
}

# Main execution
main() {
    local homebrew_only=false
    local node_only=false
    local rust_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --homebrew-only)
                homebrew_only=true
                shift
                ;;
            --node-only)
                node_only=true
                shift
                ;;
            --rust-only)
                rust_only=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting SSH Workspace package manager setup..."
    log_info "NVM Version: $NVM_VERSION"
    log_info "Node Version: $NODE_VERSION"
    log_info "Bash Environment: $BASH_ENV"
    
    validate_environment
    setup_bash_env
    
    if $homebrew_only; then
        install_homebrew
    elif $node_only; then
        install_node
    elif $rust_only; then
        install_rust
    else
        # Install all
        install_homebrew
        install_node
        install_rust
        
        log_success "All package managers installed successfully!"
        log_info "Restart your shell or run: source ~/.bashrc"
        log_info "Then try: brew install jq stow htop tree tmux screen"
    fi
}

# Run main function with all arguments
main "$@"
