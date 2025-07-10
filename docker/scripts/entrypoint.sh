#!/bin/bash
set -e

# SSH Workspace entrypoint script
# Design references: [Y4F1-USER], [V5Q3-HOME], [N3M9-PERSIST]

# Default values
USERNAME="${SSH_USERNAME:-developer}"
USER_UID="${SSH_UID:-1000}"
USER_GID="${SSH_GID:-1000}"
HOME_DIR="/home/${USERNAME}"

echo "Starting SSH workspace initialization..."

# Create group if it doesn't exist
if ! getent group "${USER_GID}" > /dev/null 2>&1; then
    groupadd -g "${USER_GID}" "${USERNAME}"
fi

# Create user if it doesn't exist
if ! id "${USERNAME}" > /dev/null 2>&1; then
    useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USERNAME}"
fi

# Check if home directory exists and is initialized
INIT_MARKER="${HOME_DIR}/.ssh-workspace-initialized"
if [ -d "${HOME_DIR}" ] && [ -f "${INIT_MARKER}" ]; then
    echo "Home directory already initialized, preserving existing configuration..."
    # Update ownership for mounted volumes
    chown -R "${USER_UID}:${USER_GID}" "${HOME_DIR}"
else
    echo "Initializing new home directory..."
    
    # Create home directory if it doesn't exist
    if [ ! -d "${HOME_DIR}" ]; then
        mkdir -p "${HOME_DIR}"
    fi
    
    # Create SSH directory
    mkdir -p "${HOME_DIR}/.ssh"
    chmod 700 "${HOME_DIR}/.ssh"
    
    # Create basic shell configuration if not exists
    if [ ! -f "${HOME_DIR}/.bashrc" ]; then
        cat > "${HOME_DIR}/.bashrc" << 'EOF'
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific aliases and functions
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'

# Prompt
PS1='[\u@\h \W]\$ '

# Linuxbrew setup [M4J7-BREW]
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d "$HOME/.linuxbrew" ]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi
EOF
    fi
    
    # Create profile if not exists
    if [ ! -f "${HOME_DIR}/.profile" ]; then
        cat > "${HOME_DIR}/.profile" << 'EOF'
# .profile

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF
    fi
    
    # Set ownership
    chown -R "${USER_UID}:${USER_GID}" "${HOME_DIR}"
    
    # Create initialization marker
    touch "${INIT_MARKER}"
    chown "${USER_UID}:${USER_GID}" "${INIT_MARKER}"
fi

# Start Dropbear SSH server
echo "Starting Dropbear SSH server on port 2222..."
exec dropbear -F -E -p 2222 -r /etc/dropbear/dropbear_rsa_host_key -r /etc/dropbear/dropbear_ed25519_host_key