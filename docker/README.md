# SSH Workspace Docker Image

Docker image for SSH-accessible workspace environment.

## 📁 Directory Structure

```
docker/
├── Dockerfile              # Main image definition
├── .dockerignore          # Docker build exclusion settings
├── README.md              # This file
├── README.ja.md           # Japanese documentation
├── config/                # Configuration files
│   └── sshd_config        # SSH configuration
└── scripts/               # Executable scripts
    ├── entrypoint.sh      # Main container initialization
    └── init-container.sh  # Init container setup (Kubernetes)
```

## 🚀 Image Build

```bash
# From project root
cd docker
docker build -t ssh-workspace:latest .

# Or, from project root
docker build -f docker/Dockerfile -t ssh-workspace:latest .
```

## ⚙️ Environment Variables

| Variable Name | Required | Default | Description |
|---------------|----------|---------|-------------|
| `SSH_USER` | ✅ | - | SSH username |
| `SSH_PUBLIC_KEYS` | ✅ | - | SSH public keys (newline-separated) |
| `SSH_USER_UID` | ❌ | 1000 | User UID |
| `SSH_USER_GID` | ❌ | 1000 | User GID |
| `SSH_USER_SHELL` | ❌ | /bin/bash | Login shell |
| `SSH_USER_SUDO` | ❌ | false | sudo privileges |
| `SSH_USER_ADDITIONAL_GROUPS` | ❌ | - | Additional groups (comma-separated) |
| `TZ` | ❌ | UTC | Timezone (e.g., Asia/Tokyo) |

**Note**: `ETC_TARGET_DIR` is used internally by Kubernetes Init Container (fixed to `/etc-new`).

## 📂 Optional Mounts

| Path | Purpose | Required | Alternative |
|------|---------|----------|-------------|
| `/etc/ssh-keys/authorized_keys` | SSH public keys | ❌ | Use `SSH_PUBLIC_KEYS` env var |
| `/home/{username}` | Home directory | ❌ | Uses ephemeral storage |

## 🔧 Usage Examples

### Basic Execution (Recommended)

Using environment variables (aligned with root README):

```bash
docker run -d \
  --name ssh-workspace \
  -p 2222:22 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  ssh-workspace:latest

# SSH connection
ssh developer@localhost -p 2222
```

### Basic Execution (File Mount)

Using file mount approach:

```bash
# Prepare SSH public key
echo "ssh-ed25519 AAAAC3... user@example.com" > authorized_keys

# Run container
docker run -d \
  --name ssh-workspace \
  -p 2222:22 \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace:latest

# SSH connection
ssh developer@localhost -p 2222
```

### Execution with Persistence

```bash
# Create persistent home directory
docker volume create ssh-workspace-home

docker run -d \
  --name ssh-workspace \
  -p 2222:22 \
  -e SSH_USER=developer \
  -e SSH_USER_SUDO=true \
  -e TZ=Asia/Tokyo \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  -v ssh-workspace-home:/home/developer \
  ssh-workspace:latest
```

### Timezone Configuration

```bash
# Check available timezones
docker run --rm ssh-workspace:latest timedatectl list-timezones | head -20

# Run with Japan time
docker run -d \
  -p 2222:22 \
  -e TZ=Asia/Tokyo \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  ssh-workspace:latest

# Run with US Eastern time
docker run -d \
  -p 2222:22 \
  -e TZ=America/New_York \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  ssh-workspace:latest
```

### Multiple SSH Keys

```bash
# Multiple SSH keys (newline-separated)
docker run -d \
  -p 2222:22 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user1@example.com
ssh-rsa AAAAB3... user2@example.com
ssh-ed25519 AAAAC3... user3@example.com" \
  ssh-workspace:latest
```

## 🔒 Security Features

- SSH public key authentication only (password authentication disabled)
- SSH port 2222 (non-privileged port)
- Privilege separation process usage
- Runs with minimal privileges
- SSH host keys must be provided via Kubernetes Secret (not embedded in image)
- Explicit permission management with required capabilities (CHOWN, DAC_OVERRIDE, FOWNER)

## 🧪 Testing & Development

**Note**: For testing purposes, this image supports automated SSH connectivity tests when used with Kubernetes. Test SSH keys are automatically cleaned up after test completion and are safe to use. See the [root README](../README.md#advanced-configuration) for details on advanced configuration options.

### Debug Mode

For troubleshooting chmod permission issues, a debug environment variable is available:

```bash
# Enable debug mode for chmod failure analysis (development/troubleshooting only)
docker run -d \
  -p 2222:22 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  -e SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true \
  ssh-workspace:latest
```

**Critical Security Warning:**
- `SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true` allows containers to start even when authorized_keys chmod fails
- **Default**: `false` (secure) - container terminates if chmod fails, preventing insecure deployments
- **When enabled**: Provides detailed diagnostics but may result in insecure file permissions (644 instead of 600)
- **Usage**: Only for development troubleshooting, **NEVER in production environments**
- **Impact**: When enabled, SSH access may work with incorrect file permissions, potentially creating security vulnerabilities

This debug mode is designed to help diagnose permission issues in development environments where chmod operations might fail due to filesystem limitations or missing capabilities.

## 🛠️ Developer Guide

### Script Modification

1. Edit scripts in `scripts/` directory
2. Rebuild image
3. Test execution

### Configuration Changes

1. Edit `config/sshd_config`
2. Rebuild image
3. Verify configuration: `docker exec container-name /usr/sbin/sshd -T`

## 🐞 Troubleshooting

### Common Issues

1. **Permission Errors**
   ```bash
   # Check authorized_keys permissions
   docker exec container-name ls -la /etc/ssh-keys/
   ```

2. **SSH Connection Failed**
   ```bash
   # Check logs
   docker logs container-name
   
   # Check SSH configuration
   docker exec container-name /usr/sbin/sshd -T
   ```

3. **User Creation Failed**
   ```bash
   # Check environment variables
   docker exec container-name env | grep SSH_USER
   ```