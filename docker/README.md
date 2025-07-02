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
| `SSH_USER_UID` | ❌ | 1000 | User UID |
| `SSH_USER_GID` | ❌ | 1000 | User GID |
| `SSH_USER_SHELL` | ❌ | /bin/bash | Login shell |
| `SSH_USER_SUDO` | ❌ | false | sudo privileges |
| `SSH_USER_ADDITIONAL_GROUPS` | ❌ | - | Additional groups (comma-separated) |
| `TZ` | ❌ | UTC | Timezone (e.g., Asia/Tokyo) |

**Note**: `ETC_TARGET_DIR` is used internally by Kubernetes Init Container (fixed to `/etc-new`).

## 📂 Required Mounts

| Path | Purpose | Required |
|------|---------|----------|
| `/etc/ssh-keys/authorized_keys` | SSH public keys | ✅ |
| `/home/{username}` | Home directory | ❌ |

## 🔧 Usage Examples

### Basic Execution

```bash
# Prepare SSH public key
echo "ssh-ed25519 AAAAC3... user@example.com" > authorized_keys

# Run container
docker run -d \
  --name ssh-workspace \
  -p 2222:2222 \
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
  -p 2222:2222 \
  -e SSH_USER=developer \
  -e SSH_USER_SUDO=true \
  -e TZ=Asia/Tokyo \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  -v ssh-workspace-home:/home/developer \
  ssh-workspace:latest
```

### Timezone Configuration

```bash
# Check available timezones
docker run --rm ssh-workspace:latest timedatectl list-timezones | head -20

# Run with Japan time
docker run -d \
  -e TZ=Asia/Tokyo \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace:latest

# Run with US Eastern time
docker run -d \
  -e TZ=America/New_York \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace:latest
```

## 🔒 Security Features

- SSH public key authentication only (password authentication disabled)
- SSH port 2222 (non-privileged port)
- Privilege separation process usage
- Runs with minimal privileges
- SSH host keys must be provided via Kubernetes Secret (not embedded in image)

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