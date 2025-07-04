# SSH Workspace

A project to build SSH-accessible workspace environments.
Provides Docker images and Kubernetes Helm Charts.

→ **Ready to get started?** See [🚀 Quick Start](#-quick-start)

## Overview & Basic Features

### Concept
SSH Workspace provides a **dedicated, secure SSH-accessible development environment** running on Kubernetes. Each deployment creates an isolated workspace for a single user with persistent data storage and comprehensive security controls.

### Core Features

#### 🔐 **Security & Authentication**
- **SSH Key-based Authentication**: Public key authentication only, no password authentication → [SSH Features](#ssh-features)
- **Multi-layered Security**: Three security levels (Basic/Standard/High) with configurable restrictions → [Security Levels](#security-levels)
- **Init Container Pattern**: Secure dual-container architecture separating setup and runtime → [Init Container Architecture](#init-container-architecture)
- **Permission Management**: Explicit UID/GID control with required Linux capabilities → [Permission Management Strategy](#permission-management-strategy)

#### 👤 **User Management**
- **Auto User Creation**: Automatic user account setup with specified UID/GID → [User Configuration](#user-configuration)
- **SSH Public Key Management**: ConfigMap-based key distribution with validation → [SSH & User Configuration](#ssh--user-configuration)
- **Sudo Support**: Optional sudo privileges with security considerations → [User Configuration](#user-configuration)
- **Shell Customization**: Configurable login shell (bash, zsh, fish, etc.) → [User Configuration](#user-configuration)

#### 💾 **Data Persistence**
- **Home Directory Persistence**: Flexible PVC-based home directory storage → [Home Directory Persistence](#home-directory-persistence)
- **Existing PVC Support**: Integration with pre-existing storage volumes → [Home Directory Persistence](#home-directory-persistence)
- **Subdirectory Mounting**: Multi-user shared storage with path isolation → [Home Directory Persistence](#home-directory-persistence)
- **Data Protection**: Persistent resources retained after Helm release deletion → [Home Directory Persistence](#home-directory-persistence)

#### 🛠️ **Development Environment**
- **Package Manager Setup**: Automated installation of Homebrew, Node.js (NVM), and Rust → [Development Environment Setup](#development-environment-setup)
- **Development Tools**: Comprehensive toolchain including Kubernetes, Python, and semantic web tools → [Development Environment Setup](#development-environment-setup)
- **Custom Packages**: Support for additional software via custom Docker images → [Limitations](#limitations)

#### 🔍 **Monitoring & Operations**
- **Health Checks**: SSH daemon monitoring with liveness and readiness probes → [Health Checks](#health-checks)
- **Prometheus Integration**: Optional SSH metrics collection and monitoring → [Advanced Monitoring](#advanced-monitoring)
- **Resource Management**: CPU and memory limits with node placement controls → [Operational Configuration](#operational-configuration)

#### 🧪 **Testing & Debugging**
- **Automated Testing**: SSH connectivity validation with temporary test keys → [Testing Configuration](#testing-configuration)
- **Debug Mode**: Development troubleshooting with security safeguards → [Debug Configuration](#debug-configuration)
- **CI/CD Integration**: Comprehensive test suite with security scanning → [Security Monitoring](#security-monitoring)

#### ☁️ **Cloud Native Integration**
- **Helm Chart**: Production-ready Kubernetes deployment with extensive configuration options → [Helm Chart & Technical Specifications](#helm-chart--technical-specifications)
- **OCI Registry**: Container and chart distribution via GitHub Container Registry → [CI/CD & Container Registry](#-cicd--container-registry)
- **Multi-Architecture**: Support for AMD64 and ARM64 platforms → [CI/CD & Container Registry](#-cicd--container-registry)

### Basic Architecture
- **Base Image**: Ubuntu 22.04 with minimal SSH environment packages
- **Resource Management**: Extensive use of ConfigMap, Secret, and PVC for configuration
- **Persistence**: Storage resources retained after Helm Release deletion for data protection
- **Security**: Read-only root filesystem with capability-based permission model

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


## SSH & User Configuration

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
- **Home Directory**: Advanced persistence options - see [Home Directory Persistence](#home-directory-persistence)
- **sudo Privileges**: Optional (disabled by default), configured during Init Container setup
- **Configuration Files**: Uses distribution defaults
- **Security**: User creation isolated to Init Container, main container runs with pre-configured user

### X11 Forwarding
- Only allows connections from localhost
- Uses sshd forwarding options

## Security Configuration

### Security Levels
| Level | Purpose | readOnlyRootFilesystem | Additional Features |
|-------|---------|------------------------|-------------------|
| Basic | Development/Testing | false | Minimal restrictions |
| Standard | Recommended | true | seccomp enabled |
| High | Production | true | seccomp RuntimeDefault |

### Permission Management Strategy

The chart uses explicit permission management for volume ownership:

- **explicit**: Direct UID/GID management without fsGroup (no SetGID bit)
- Manual file ownership control through required capabilities (CHOWN, DAC_OVERRIDE, FOWNER)
- Provides consistent behavior across different Kubernetes environments

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

## Service & Access Configuration

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

## Monitoring & Operations

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

### Pod Disruption Budget (PDB) Considerations

**⚠️ IMPORTANT: Pod Disruption Budget is NOT supported**

This Helm chart intentionally does not include PDB support due to the following architectural constraints:

1. **Single Replica Design**: SSH Workspace runs as a single pod (`replicas: 1`) because:
   - Each workspace is dedicated to a single user with persistent session state
   - Home directory persistence uses `ReadWriteOnce` PVC (single node access only)
   - Multiple replicas would break SSH session continuity and file consistency

2. **Recreate Strategy**: The deployment uses `strategy: type: Recreate` which:
   - Ensures clean shutdown before starting a new pod
   - Prevents data corruption in persistent volumes
   - Is incompatible with PDB's rolling update assumptions

3. **Operational Impact**: Adding PDB with `minAvailable: 1` would:
   - Block all cluster maintenance operations permanently
   - Prevent pod eviction during node drains
   - Create a deadlock situation requiring manual intervention

**Recommended Approach**: For cluster maintenance, plan scheduled downtime and communicate with workspace users. The persistent home directory ensures no data loss during pod restarts.

## Advanced Configuration

### Home Directory Persistence

SSH Workspace provides flexible home directory persistence options to meet various use cases:

#### Requirements
1. **Persist and reuse work data** - Support both new and existing PVCs
2. **Segment work data appropriately** - Enable subdirectory mounting for proper data organization

#### Configuration Options

##### Basic Persistence (New PVC)
```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: "fast-ssd"  # Optional, uses default if empty
```

##### Using Existing PVC
```yaml
persistence:
  enabled: true
  existingClaim: "my-existing-data"  # Use pre-existing PVC
  # size and storageClass are ignored when existingClaim is specified
```

##### Subdirectory Mounting
Mount a specific subdirectory from a PVC, useful for:
- Sharing a large PVC among multiple workspaces
- Organizing data by user, project, or environment
- Utilizing existing data structures

```yaml
persistence:
  enabled: true
  existingClaim: "shared-team-storage"
  subPath: "users/developer"  # Mount only this subdirectory
```

##### Advanced Examples

**Multi-user Shared Storage:**
```yaml
persistence:
  enabled: true
  existingClaim: "department-storage"
  subPath: "workspaces/{{ .Values.user.name }}"
```

**Project-based Organization:**
```yaml
persistence:
  enabled: true
  existingClaim: "project-data"
  subPath: "environments/dev/users/{{ .Values.user.name }}"
```

**Complete Configuration Reference:**
```yaml
persistence:
  enabled: true              # Enable/disable persistence
  existingClaim: ""          # Name of existing PVC (optional)
  subPath: ""                # Subdirectory within PVC (optional)
  size: 10Gi                 # Size for new PVC (ignored if existingClaim is set)
  storageClass: ""           # StorageClass for new PVC (optional)
  accessModes:
    - ReadWriteOnce          # Access mode (RWO required for single-user workspace)
```

#### Implementation Notes
- When `existingClaim` is empty, a new PVC named `{release-name}-ssh-workspace-home` is created
- The `subPath` can be empty (mount entire PVC) or specify a subdirectory path
- Subdirectories are created automatically if they don't exist
- All file operations within mounted directories work normally without limitations

### Development Environment Setup

SSH Workspace includes a comprehensive setup script for installing development package managers and tools.

#### Step 1: Package Manager Installation

First, install the foundational package managers (Linuxbrew, Node.js via NVM, and Rust):

```bash
# Install all package managers
/opt/ssh-workspace/bin/user-package-managers.sh

# Or install specific package managers only
/opt/ssh-workspace/bin/user-package-managers.sh --homebrew-only
/opt/ssh-workspace/bin/user-package-managers.sh --node-only  
/opt/ssh-workspace/bin/user-package-managers.sh --rust-only
```

**Features:**
- **Linuxbrew**: Modern package manager for Linux
- **Node.js**: Modern JavaScript runtime via NVM with auto-version detection
- **Rust**: Systems programming language and toolchain
- **Safe & Secure**: Official installation methods, HTTPS downloads, verification checks

#### Step 2: Development Tools Installation

After installing package managers, install comprehensive development tools:

```bash
# Install all development tools (requires package managers from step 1)
/opt/ssh-workspace/bin/install-user-packages.sh
```

**Installed Tools:**
- **Command Line Tools**: `ripgrep`, `jq`, `stow`, `htop`, `tree`, `tmux`, `screen`
- **Kubernetes Tools**: `kubectl`, `helm`, `kustomize`, `helmfile`, `sops`, `age`, `talosctl`
- **Helm Plugins**: `helm-diff`, `helm-git`, `helm-s3`, `helm-secrets`
- **Python Tools**: `uv` (modern Python package manager)
- **Ontology Tools**: `raptor`, `jena` (semantic web development)
- **Node.js Tools**: `@anthropic-ai/claude-code` (Claude Code CLI)
- **Rust Tools**: `cargo-edit`, `cargo-watch` with `rustfmt` and `clippy`

**Environment Variables:**
```bash
# Auto-detect latest versions (default behavior)
/opt/ssh-workspace/bin/user-package-managers.sh

# Or customize specific versions for step 1
NVM_VERSION=v0.39.0 NODE_VERSION=18 /opt/ssh-workspace/bin/user-package-managers.sh

# Customize Node.js version for step 2
NODE_VERSION=18 /opt/ssh-workspace/bin/install-user-packages.sh
```

**After Installation:**
```bash
# Reload shell environment
source ~/.bashrc

# Verify installations
brew --version
node --version
cargo --version

# Use installed tools
kubectl version --client
helm version
jq --version
tmux -V
```

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
- **File Permission Risk**: authorized_keys may have world-readable permissions (644) instead of secure permissions (600)
- **Security Vulnerability**: Incorrect permissions expose SSH keys to unauthorized access on multi-user systems

This debug mode is designed to help diagnose permission issues in development environments where chmod operations might fail due to filesystem limitations or missing capabilities.

### Helm Test Execution

SSH Workspace includes comprehensive automated tests that validate deployment integrity and SSH functionality using `helm test`.

#### Test Overview

The test suite consists of 6 test components that validate different aspects of the SSH workspace:

| Test Component | Purpose | Hook Weight | Description |
|----------------|---------|-------------|-------------|
| **RBAC Resources** | Test permissions setup | -2 | Creates ServiceAccount, Role, and RoleBinding for test execution |
| **SSH Keys Secret** | Test key storage | -15 | Stores test SSH key pairs for authentication testing |
| **Resource Validation** | Infrastructure check | -1 | Validates all required Kubernetes resources are deployed correctly |
| **SSH Internal Validation** | Security verification | 5 | Validates SSH configuration, file permissions, and security settings |
| **SSH Authentication** | Connection testing | 10 | Tests SSH connectivity and key-based authentication |
| **Workspace Functionality** | Feature validation | 15 | Tests user workspace features, file operations, and development tools |

#### Test Execution Methods

##### Basic Test Execution
```bash
# Deploy and run tests
helm install workspace ./helm/ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="ssh-ed25519 AAAAC3... user@example.com" \
  --set ssh.testKeys.enabled=true \
  --set tests.sshConnectivity.enabled=true

# Execute tests
helm test workspace --timeout=300s
```

##### Test with Specific Configuration
```bash
# Test with different security levels
helm test workspace \
  --set security.level=high \
  --set persistence.enabled=true \
  --timeout=600s
```

##### Viewing Test Results
```bash
# Check test status
helm test workspace --logs

# View specific test pod logs
kubectl logs workspace-ssh-workspace-ssh-auth-test
kubectl logs workspace-ssh-workspace-resource-test
kubectl logs workspace-ssh-workspace-workspace-test
```

#### Test Components Details

##### 1. Resource Validation Test (`resource-validation-test.yaml`)
- **Purpose**: Validates all Kubernetes resources are properly deployed
- **Checks**: ConfigMap, Secret, Deployment, Service, PVC (if enabled), Monitoring Service (if enabled)
- **Requirements**: Basic kubectl access permissions

##### 2. SSH Internal Validation Test (`ssh-internal-validation-test.yaml`)
- **Purpose**: Validates SSH security configuration and file permissions
- **Checks**: Permission strategy, file ownership, SSH directory permissions, security failures
- **Security Focus**: SetGID bit validation, authorized_keys permissions (600), SSH directory permissions (700)

##### 3. SSH Authentication Test (`ssh-authentication-test.yaml`)
- **Purpose**: Tests SSH connectivity and authentication
- **Checks**: TCP connection, SSH protocol response, key-based authentication
- **Requirements**: Test SSH keys must be enabled (`ssh.testKeys.enabled=true`)

##### 4. User Workspace Functionality Test (`user-workspace-functionality-test.yaml`)
- **Purpose**: Validates user workspace features and development environment
- **Checks**: Shell environment, file operations, directory operations, development tools, persistence, network connectivity (optional)
- **Features Tested**: Basic commands, file creation/deletion, development tool availability

##### 5. SSH Keys Secret (`test-ssh-keys-secret.yaml`)
- **Purpose**: Provides test SSH key pairs for authentication testing
- **Security**: Keys are automatically generated during test execution and cleaned up afterward
- **Data**: Contains both public and private keys for test authentication

##### 6. RBAC Resources (`rbac.yaml`)
- **Purpose**: Test execution permissions
- **Components**: ServiceAccount, Role, RoleBinding
- **Permissions**: Pod access, Secret/ConfigMap reading, Service discovery

#### Test Resource Management

##### Test Pod Lifecycle
```yaml
# Test pods use hook-delete-policy: before-hook-creation
# - Pods persist after test completion (success or failure)
# - Allows debugging of test failures
# - Manual cleanup required
```

##### Manual Test Cleanup
```bash
# Clean up test pods only (preserves main workspace)
kubectl delete pods -l "helm.sh/hook=test"

# Verify cleanup
kubectl get pods -l "helm.sh/hook=test"
```

##### Automatic Cleanup in CI/CD
Test cleanup is automatically handled in CI/CD pipelines:
```yaml
# Cleanup step in GitHub Actions
- name: Cleanup Test Pods
  if: always()
  run: |
    kubectl delete pods -l "helm.sh/hook=test" --ignore-not-found=true
```

#### Troubleshooting Test Failures

##### Common Test Failure Scenarios

**SSH Authentication Test Failures:**
```bash
# Check SSH service status
kubectl describe pod workspace-ssh-workspace

# Verify SSH keys configuration
kubectl get secret workspace-ssh-workspace-ssh-keys -o yaml

# Check test key configuration
kubectl get secret workspace-ssh-workspace-test-ssh-keys -o yaml
```

**Resource Validation Failures:**
```bash
# Check missing resources
kubectl get all -l app.kubernetes.io/instance=workspace

# Verify ConfigMap and Secret creation
kubectl get configmap,secret -l app.kubernetes.io/instance=workspace
```

**Permission Issues:**
```bash
# Check Init Container logs
kubectl logs workspace-ssh-workspace -c ssh-setup

# Verify security context
kubectl get pod workspace-ssh-workspace -o yaml | grep -A 10 securityContext
```

##### Test Configuration Requirements

For successful test execution, ensure:

1. **Test Keys Enabled**: `ssh.testKeys.enabled=true`
2. **SSH Connectivity Tests**: `tests.sshConnectivity.enabled=true`
3. **RBAC Permissions**: `tests.rbac.create=true` (default)
4. **Resource Limits**: Sufficient cluster resources for test pods
5. **Network Policies**: Allow pod-to-pod communication if NetworkPolicies are in use

#### Security Considerations

- **Test SSH Keys**: Generated automatically, stored temporarily, cleaned up after tests
- **Test Isolation**: Each test matrix configuration uses separate namespaces/releases
- **Permission Validation**: Tests verify security settings without compromising workspace security
- **Cleanup**: Test resources are cleaned up to prevent resource accumulation

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

## Helm Chart & Technical Specifications

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
  existingClaim: "" # Use existing PVC instead of creating new one (optional)
  subPath: "" # Mount subdirectory from PVC (optional)
  size: 10Gi # Storage size for new PVC
  storageClass: "" # Storage class for new PVC
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
# 
# Helm command line usage:
# --set-string 'extraEnvVars[0].name=SSH_WORKSPACE_DEBUG_CHMOD_FAILURES' \
# --set-string 'extraEnvVars[0].value=true'

# Node placement and scheduling
nodeSelector: {} # Node selection constraints
tolerations: [] # Tolerate node taints
affinity: {} # Pod affinity/anti-affinity rules

# Additional metadata
labels: {} # Additional Pod and resource labels
annotations: {} # Additional Pod and resource annotations

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

### Known Issues

#### SSH Private Key Format with `--set` Parameter

**⚠️ CRITICAL: SSH private keys cannot be passed via `--set` parameter**

When using SSH private keys with the `--set` parameter, the `$(cat private_key_file)` command substitution removes trailing newlines, which breaks the SSH private key format and causes authentication failures.

**Problem:**
```bash
# This WILL FAIL - newlines are removed
helm install workspace ./ssh-workspace \
  --set "ssh.testKeys.keyPairs[0].privateKey=$(cat private_key_file)"

# Error: Invalid SSH private key format
```

**Solution: Use values.yaml file instead**
```bash
# Create values.yaml with proper formatting
cat > values.yaml << EOF
ssh:
  testKeys:
    keyPairs:
      - privateKey: |
$(sed 's/^/          /' private_key_file)
EOF

# Install using values file
helm install workspace ./ssh-workspace -f values.yaml
```

**Root Cause:**
- SSH private keys require trailing newlines after `-----END OPENSSH PRIVATE KEY-----`
- Command substitution `$(cat file)` removes these essential newlines
- The `sed` command with proper indentation preserves the original formatting
- YAML literal block scalars (`|`) maintain all whitespace and newlines

**Recommendation:** Always use values.yaml files for SSH private keys in production deployments.

## Security Monitoring

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

## Limitations

- **Single user only**: Multi-user not supported
- **Root execution required**: Restricted by security context
- **Persistence scope**: Home directory only
- **X11 forwarding**: Localhost only
- **External exposed ports**: SSH only
- **Additional packages**: Supported via custom images