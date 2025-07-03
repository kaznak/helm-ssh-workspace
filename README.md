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

# SSH public keys are provided via environment variables
docker run -d -p 2222:22 \
  -e SSH_USER=developer \
  -e SSH_PUBLIC_KEYS="ssh-ed25519 AAAAC3... user@example.com" \
  ssh-workspace

ssh developer@localhost -p 2222
```

### Run with Kubernetes

```bash
cd helm
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com"

kubectl port-forward svc/workspace-ssh-workspace 2222:2222
ssh developer@localhost -p 2222
```

**Note**: For testing purposes, you can enable `ssh.testKeys` for automated SSH connectivity tests. Test SSH keys are automatically cleaned up after test completion and are safe to use. See [Advanced Configuration](#advanced-configuration) for details on additional features.

```bash
# Enable test keys for automated testing
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com" \
  --set ssh.testKeys.enabled=true
```

## 🔄 CI/CD & Container Registry

### GitHub Container Registry (GHCR)

Pre-built images are available on GitHub Container Registry:

**Platform Support:**
- ✅ **linux/amd64**: Fully tested and supported
- ⚠️ **linux/arm64**: Built but not tested in CI (should work on ARM64 systems)

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
| **Security Scan** | Daily/Push | Vulnerability scanning with Trivy + SARIF reports |
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

#### Main Container
- **drop**: ["ALL"]
- **add**: 
  - Base capabilities: ["SETUID", "SETGID", "SYS_CHROOT"]
  - Permission management: ["CHOWN", "DAC_OVERRIDE", "FOWNER"]
  - When sudo enabled: ["SETPCAP", "SYS_ADMIN"]

#### Init Container
- **drop**: ["ALL"]
- **add**: ["SETUID", "SETGID", "CHOWN", "DAC_OVERRIDE", "FOWNER"]

### Init Container Architecture

SSH Workspace employs a **dual-container Init Container pattern** for enhanced security:

#### Init Container (ssh-setup)
- **Purpose**: User creation and SSH configuration setup
- **Security Context**: 
  - `readOnlyRootFilesystem: false` (required for system modifications)
  - `allowPrivilegeEscalation: true`
  - Capabilities: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`, `FOWNER`
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
- **Network Exposure**: SSH port 2222 only

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
| SSH Port | 2222 | Customizable |
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

## 6. Advanced Configuration

### Testing Configuration

#### SSH Test Keys
For automated testing and CI/CD pipelines, you can configure dedicated test SSH keys:

```yaml
ssh:
  testKeys:
    enabled: true
    keyPairs:
      - publicKey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrShAQgt+9ZuPDQ1L2KrSwKxL8BEcqhytt7X3ZLZxai test-key@helm-test"
        privateKey: |
          -----BEGIN OPENSSH PRIVATE KEY-----
          b3BlbnNzaC1QlkeXktZZlnBUKmhp4AAAAC1lZQI5NTE5AAAAIGrShAQgt+9ZuPDQ1L2K
          rSwKxL8BEcqhytt7X3ZLZxaiAAAAFHRlc3Qta2V5QGhlbG0tdGVzdA==
          -----END OPENSSH PRIVATE KEY-----
```

**Security Notes:**
- Test keys are stored in Kubernetes Secrets with `helm.sh/hook-delete-policy: hook-succeeded`
- Secrets are **automatically deleted** after test completion
- Test keys are **only present during test execution** (typically 2-3 minutes)
- Private keys are never exposed in logs or persistent storage

#### Test RBAC Configuration
```yaml
tests:
  rbac:
    create: true  # Creates ServiceAccount, Role, and RoleBinding for tests
```

Enables comprehensive testing including SSH connectivity validation and permission checks.

#### Debug Configuration
For troubleshooting deployment issues, a debug mode is available:

```bash
# Enable debug mode for chmod failure analysis (development/troubleshooting only)
helm install workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com" \
  --set-string 'extraEnvVars[0].name=SSH_WORKSPACE_DEBUG_CHMOD_FAILURES' \
  --set-string 'extraEnvVars[0].value=true'
```

**Critical Security Warning:**
- `SSH_WORKSPACE_DEBUG_CHMOD_FAILURES=true` allows containers to start even when authorized_keys chmod fails
- **Default**: `false` (secure) - container terminates if chmod fails, preventing insecure deployments
- **When enabled**: Provides detailed diagnostics but may result in insecure file permissions (644 instead of 600)
- **Usage**: Only for development troubleshooting, **NEVER in production environments**
- **Impact**: When enabled, SSH access may work with incorrect file permissions, potentially creating security vulnerabilities

This debug mode is designed to help diagnose permission issues in development environments where chmod operations might fail due to filesystem limitations or missing capabilities.

### Operational Configuration

#### Node Placement and Scheduling
```yaml
# Target specific nodes
nodeSelector:
  kubernetes.io/arch: amd64
  node.kubernetes.io/instance-type: m5.large

# Tolerate node taints
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "ssh-workspaces"
    effect: "NoSchedule"

# Pod affinity rules
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: ssh-workspace
          topologyKey: kubernetes.io/hostname
```

#### Metadata and Labeling
```yaml
# Additional labels for all resources
labels:
  environment: production
  team: platform
  cost-center: "12345"

# Additional annotations
annotations:
  monitoring.coreos.com/scrape: "true"
  backup.velero.io/backup-volumes: "home"
```

#### High Availability Operations
```yaml
# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1  # Ensure at least 1 pod during cluster maintenance
```

### Advanced Monitoring

#### Prometheus Integration
```yaml
monitoring:
  enabled: true
  port: 9312
  serviceMonitor:
    enabled: true      # Creates ServiceMonitor for Prometheus Operator
    interval: 30s      # Metrics collection frequency
```

**Available Metrics:**
- SSH connection count and duration
- Authentication success/failure rates
- Resource utilization (CPU, memory, disk)

## 7. Helm Chart & Technical Specifications

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
  - name: Nakamura Kazutaka
    email: kaznak.at.work@ipebble.org
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
  port: 2222 # SSH port
  config: {} # Custom configuration
  testKeys: # Test SSH keys for automated testing (optional)
    enabled: false # Enable test key functionality
    keyPairs: [] # Test key pairs (public + private keys)

persistence:
  enabled: false # Enable/disable persistence
  size: 10Gi # Storage size
  storageClass: "" # Storage class
  accessModes: [ReadWriteOnce] # Access mode

security:
  level: standard # basic/standard/high
  securityContext: {} # Additional Container Security Context
  podSecurityContext: {} # Additional Pod Security Context

service:
  type: ClusterIP # Service type
  port: 2222 # Service port

resources: {} # CPU & memory limits
timezone: UTC # Timezone (tzdata package)

# Additional environment variables (optional)
extraEnvVars: [] # Additional environment variables for containers
# Example:
# extraEnvVars:
#   - name: SSH_WORKSPACE_DEBUG_CHMOD_FAILURES
#     value: "true"

# Node placement and scheduling
nodeSelector: {} # Node selection constraints
tolerations: [] # Tolerate node taints
affinity: {} # Pod affinity/anti-affinity rules

# Additional metadata
labels: {} # Additional Pod and resource labels
annotations: {} # Additional Pod and resource annotations

# High availability and operations
podDisruptionBudget:
  enabled: false # Enable Pod Disruption Budget
  minAvailable: 1 # Minimum available replicas during disruptions

monitoring:
  enabled: false # Enable/disable ssh_exporter
  port: 9312 # Metrics port
  serviceMonitor:
    enabled: false # Create ServiceMonitor for Prometheus
    interval: 30s # Metrics collection interval

ingress:
  enabled: false # Enable/disable Ingress
  className: "" # Ingress class name
  annotations: {} # Ingress annotations
  hosts: [] # Ingress hosts configuration
  tls: [] # TLS configuration

# Testing configuration
tests:
  rbac:
    create: true # Create ServiceAccount and RBAC for tests

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

## 7. Security Monitoring

### Automated Security Scanning

This project implements comprehensive security monitoring:

- **Daily Vulnerability Scans**: Automated Trivy scanning for container security
- **SARIF Integration**: Security results are uploaded in SARIF (Static Analysis Results Interchange Format) for GitHub Security integration
- **GitHub Security Tab**: View detailed vulnerability reports at `/security/code-scanning`
- **Real-time Alerts**: Automatic notifications for new security issues
- **Compliance Reporting**: Standardized security reports for audit and compliance

### SARIF Security Reports

View automated security scan results:
- **SARIF Reports**: [Code Scanning Results](https://github.com/kaznak/helm-ssh-workspace/security/code-scanning) - Trivy vulnerability scans in SARIF format

**Navigation**: Repository → Security tab → Code scanning

### Additional Security Features

- **Dependabot**: [Dependency Alerts](https://github.com/kaznak/helm-ssh-workspace/security/dependabot) - Dependency vulnerability management (separate from SARIF)
- **Security Overview**: [Security Dashboard](https://github.com/kaznak/helm-ssh-workspace/security) - Complete security overview
- **Security Policy**: `SECURITY.md` - Responsible disclosure guidelines

## 8. Limitations

- **Single user only**: Multi-user not supported
- **Root execution required**: Restricted by security context
- **Persistence scope**: Home directory only
- **X11 forwarding**: Localhost only
- **External exposed ports**: SSH only
- **Additional packages**: Supported via custom images