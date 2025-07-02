# SSH Workspace

A project to build SSH-accessible workspace environments.
Provides Docker images and Kubernetes Helm Charts.

## 📁 Project Structure

```
ssh-workspace/
├── README.md              # This file (specification)
├── USAGE.md              # Usage guide
├── LICENSE               # MIT License
├── .github/              # GitHub configuration
│   ├── workflows/        # CI/CD workflows
│   ├── ISSUE_TEMPLATE/   # Issue templates
│   └── CODEOWNERS        # Code ownership
├── docker/               # Docker image
│   ├── Dockerfile        # Image definition
│   ├── config/           # SSH configuration
│   ├── scripts/          # Initialization scripts
│   └── README.md         # Docker documentation
├── helm/                 # Helm Chart
│   ├── ssh-workspace/    # Chart package
│   ├── example-values.yaml # Configuration examples
│   └── README.md         # Helm documentation
└── docs/                 # Additional documentation
    └── helm-oci-format.md # OCI format guide
```

## 🚀 Quick Start

### Run with Docker

```bash
cd docker
docker build -t ssh-workspace .

echo "ssh-ed25519 AAAAC3... user@example.com" > authorized_keys
docker run -d -p 2222:22 \
  -e SSH_USER=developer \
  -v $(pwd)/authorized_keys:/etc/ssh-keys/authorized_keys:ro \
  ssh-workspace

ssh developer@localhost -p 2222
```

### Run with Kubernetes

```bash
cd helm
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"

kubectl port-forward svc/workspace-ssh-workspace 2222:22
ssh developer@localhost -p 2222
```

## 🔄 CI/CD & Container Registry

### GitHub Container Registry (GHCR)

Pre-built images are available on GitHub Container Registry:

```bash
# Pull the latest image
docker pull ghcr.io/kaznak/ssh-workspace:latest

# Use in Helm Chart
helm install workspace ./helm/ssh-workspace \
  --set image.repository=ghcr.io/kaznak/ssh-workspace \
  --set image.tag=latest \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

### Available Tags

- `latest` - Latest stable release from main branch
- `develop` - Latest development version
- `v1.0.0` - Specific version tags
- `main` - Main branch builds

### CI/CD Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **CI/CD Pipeline** | Push/PR | Lint, test, build, and push |
| **Docker Build & Push** | Docker changes | Build multi-arch images |
| **Security Scan** | Daily/Push | Vulnerability scanning with Trivy |
| **Helm Release** | Chart changes | Package and publish charts |
| **Pages Helm Repo** | Chart changes | GitHub Pages Helm repository |

### Helm Chart Installation

#### Method 1: OCI Registry (Recommended)

```bash
# Install directly from GHCR
helm install workspace \
  oci://ghcr.io/kaznak/charts/ssh-workspace \
  --version 1.0.0 \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

#### Method 2: Traditional Helm Repository

```bash
# Add repository
helm repo add ssh-workspace https://kaznak.github.io/helm-ssh-workspace/
helm repo update

# Install chart
helm install workspace ssh-workspace/ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

#### Method 3: Local Installation

```bash
# Clone repository and install locally
git clone https://github.com/kaznak/helm-ssh-workspace.git
cd helm-ssh-workspace
helm install workspace ./helm/ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"
```

## 1. Overview & Basic Features

### Concept
- Dedicated SSH workspace environment per deployment per user
- High-security SSH server on Kubernetes
- Optional home directory persistence

### Basic Architecture
- **Base Image**: Ubuntu (minimal SSH environment packages)
- **Resource Management**: Active use of ConfigMap, Secret, PVC
- **Persistence**: PVC, ConfigMap, Secret retained after Helm Release deletion

## 2. SSH & User Configuration

### SSH Features
| Item | Setting | Notes |
|------|---------|-------|
| Authentication | Public key only | PasswordAuthentication no |
| Log output | Standard output | sshd -D -e option |
| Host key management | Secret | Auto-generated on first boot |
| Connection attempts | Up to 3 times | MaxAuthTries 3 |
| Connection timeout | 30 seconds | LoginGraceTime 30 |
| Keep-Alive | 300 second interval | ClientAliveInterval 300 |
| Port forwarding | Allowed | AllowTcpForwarding yes |
| Gateway | Disabled | GatewayPorts no |
| Root Login | Disabled | PermitRootLogin no |

### User Configuration
- **Creation**: Auto-created by Init Container with specified UID/GID (if not exists)
- **SSH Public Key**: **Required** - Provided via ConfigMap, validated and configured by Init Container
- **Username**: **Required** - Used for system user creation (`useradd`)
- **UID/GID**: Optional (auto-assigned if not specified)
- **Home Directory**: Persistence option (10GiB), uses emptyDir when disabled
- **sudo Privileges**: Optional (disabled by default), configured during Init Container setup
- **Configuration Files**: Uses distribution defaults
- **Security**: User creation isolated to Init Container, main container runs with pre-configured user

### X11 Forwarding
- Only allows connections from localhost
- Uses sshd forwarding options

## 3. Security Configuration

### Security Levels
| Level | Purpose | readOnlyRootFilesystem | Additional Features |
|-------|---------|------------------------|-------------------|
| Basic | Development/Testing | false | Minimal restrictions |
| Standard | Recommended | true | seccomp enabled |
| High | Production | true | seccomp RuntimeDefault |

### Pod Security Context
- **runAsNonRoot**: false (root execution required)
- **readOnlyRootFilesystem**: true (false for Basic level)
- **allowPrivilegeEscalation**: false (auto true when sudo enabled)

### Capabilities
- **drop**: ["ALL"]
- **add**: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE"]
- **When sudo enabled**: ["SETPCAP", "SYS_ADMIN"] added

### Init Container Architecture

SSH Workspace employs a **dual-container Init Container pattern** for enhanced security:

#### Init Container (ssh-setup)
- **Purpose**: User creation and SSH configuration setup
- **Security Context**: 
  - `readOnlyRootFilesystem: false` (required for system modifications)
  - `allowPrivilegeEscalation: true`
  - Capabilities: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`
- **Operations**:
  - Creates user and group using `groupadd`/`useradd`
  - Sets up SSH directory structure (`/home/user/.ssh`)
  - Configures SSH authorized_keys with proper permissions
  - Validates group memberships and sudo configuration
- **Execution Time**: Short-lived (completes setup and exits)
- **Network Exposure**: None (no ports exposed)

#### Main Container (ssh-workspace)
- **Purpose**: SSH daemon service only
- **Security Context**:
  - `readOnlyRootFilesystem: true` (maximum security)
  - `allowPrivilegeEscalation: false`
  - Minimal capabilities for SSH operation
- **Operations**: 
  - Runs SSH daemon (`/usr/sbin/sshd -D -e`)
  - Uses pre-configured user and SSH settings from Init Container
  - No dynamic system modifications
- **Network Exposure**: SSH port 22 only

#### Shared Resources
- **EmptyDir Volume (`/etc`)**: User/group information and SSH configuration
- **EmptyDir/PVC Volume (`/home`)**: User home directory
- **ConfigMap**: SSH public keys
- **Security Benefits**:
  - Separation of privileges: setup vs. runtime
  - Reduced attack surface: main container cannot modify system files
  - No network exposure during privileged operations

### File System
- **Read-only root**: Security enhancement (main container)
- **emptyDir mounts**:
  - /etc: Shared user configuration (from Init Container)
  - /var/run: PID files (10Mi)
  - /tmp: Temporary files & X11 sockets (100Mi)
  - /var/empty: For sshd privilege separation process

## 4. Service & Access Configuration

### Service & Network
| Item | Default | Options |
|------|---------|---------|
| Service Type | ClusterIP | NodePort/LoadBalancer |
| SSH Port | 22 | Customizable |
| External Access | SSH only | localhost access allowed |
| Ingress | Disabled | TLS termination & tunneling support |

### Network Security
- Disable unnecessary ports
- Network-level restrictions implemented via external NetworkPolicy

## 5. Monitoring & Operations

### Health Checks
- **Liveness**: SSH process survival check (/usr/sbin/sshd -t)
- **Readiness**: SSH port connection check
- **Shutdown**: terminationGracePeriod support

### Monitoring & Metrics (Optional)
- **ssh_exporter**: Sidecar container
- **Collected Data**: SSH connection count, response time, authentication failures
- **Prometheus**: ServiceMonitor configuration
- **Standard Metrics**: CPU, memory, PVC usage

### Error Handling & Operations
| Situation | Response |
|-----------|----------|
| Initialization failure | Error output via pre-install hook |
| Invalid SSH public key | Stop startup |
| UID/GID conflict | Error and stop startup |
| PVC mount failure | Pod Pending state |
| Upgrade | Recreate strategy (downtime acceptable) |
| Data protection | `helm.sh/resource-policy: keep` |
| Auto recovery | restartPolicy Always |

## 6. Helm Chart & Technical Specifications

### Chart.yaml
```yaml
apiVersion: v2
name: ssh-workspace
type: application
version: 1.0.0
appVersion: "1.0.0"
description: SSH accessible workspace environment
keywords: [ssh, workspace, development, terminal]
maintainers:
  - name: SSH Workspace Team
    email: maintainer@example.com
```

### Values.yaml Structure
```yaml
image:
  repository: # Ubuntu-based SSH server
  tag: # Semantic version
  pullPolicy: # latest=Always, fixed=IfNotPresent
  pullSecrets: [] # Private Registry support

user:
  name: "" # Username (required)
  uid: null # User ID (optional, auto-assigned if not specified)
  gid: null # Group ID (optional, auto-assigned if not specified)
  shell: /bin/bash # Login shell
  additionalGroups: [] # Additional groups
  sudo: false # sudo privileges

ssh:
  publicKeys: [] # SSH public keys (required, array format)
  port: 22 # SSH port
  config: {} # Custom configuration

persistence:
  enabled: false # Enable/disable persistence
  size: 10Gi # Storage size
  storageClass: "" # Storage class
  accessModes: [ReadWriteOnce] # Access mode

security:
  level: standard # basic/standard/high
  securityContext: {} # Pod Security Context
  podSecurityContext: {} # Container Security Context

service:
  type: ClusterIP # Service type
  port: 22 # Service port

resources: {} # CPU & memory limits
timezone: UTC # Timezone (tzdata package)
monitoring:
  enabled: false # Enable/disable ssh_exporter
ingress:
  enabled: false # Enable/disable Ingress
  # annotations, className, TLS configuration, etc.

# All parameters except deployment-time decisions have default values
```

### Helm Features
- **Schema**: Type validation via values.schema.json
- **Init Container Pattern**: Secure dual-container architecture for user setup and SSH service
- **Hooks**: 
  - pre-install: SSH public key format validation (runs before Init Container)
  - post-install: SSH connectivity verification
  - pre-upgrade: Compatibility and data migration check
  - test: End-to-end SSH connection test
- **NOTES.txt**: SSH connection procedures, Init Container status, persistence warnings, troubleshooting
- **Labels**: app.kubernetes.io/* standard labels
- **Required Parameters**: SSH public key, username
- **Values Design**: All optional except deployment-time decisions (default values provided)

## 7. Limitations

- **Single user only**: Multi-user not supported
- **Root execution required**: Restricted by security context
- **Persistence scope**: Home directory only
- **X11 forwarding**: Localhost only
- **External exposed ports**: SSH only
- **Additional packages**: Supported via custom images