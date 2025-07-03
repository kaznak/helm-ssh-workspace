# SSH Workspace Helm Chart

Helm Chart for deploying SSH-accessible workspace environments on Kubernetes.

## 📁 Directory Structure

```
helm/
├── ssh-workspace/          # Helm Chart
│   ├── Chart.yaml         # Chart basic information
│   ├── values.yaml        # Default configuration values
│   ├── values.schema.json # Configuration value validation schema
│   ├── .helmignore        # Package exclusion settings
│   └── templates/         # Kubernetes templates
│       ├── _helpers.tpl   # Common helper functions
│       ├── configmap.yaml # SSH public key configuration
│       ├── secret.yaml    # SSH host keys
│       ├── deployment.yaml # Main workload
│       ├── service.yaml   # Network access
│       ├── pvc.yaml       # Persistent storage
│       ├── ingress.yaml   # External access
│       ├── servicemonitor.yaml # Monitoring configuration
│       ├── poddisruptionbudget.yaml # Availability guarantee
│       ├── pre-install-hook.yaml   # Pre-install validation
│       ├── post-install-hook.yaml  # Post-install verification
│       ├── NOTES.txt      # Post-deployment guide
│       └── tests/         # Helm tests
│           ├── ssh-connection-test.yaml
│           └── resource-validation-test.yaml
├── example-values.yaml    # Configuration examples
└── README.md             # This file
```

## 🚀 Quick Start

### Required Parameter Configuration

```bash
# Prepare SSH public key
export SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@example.com"

# Basic deployment
helm install my-workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="$SSH_PUBLIC_KEY"
```

**Note**: For testing purposes, you can enable `ssh.testKeys` for automated SSH connectivity tests. Test SSH keys are automatically cleaned up after test completion and are safe to use. See [Testing Configuration](#testing-configuration) for details.

### Access Method

```bash
# Port forward (when using ClusterIP)
kubectl port-forward svc/my-workspace-ssh-workspace 2222:22

# SSH connection
ssh developer@localhost -p 2222
```

## ⚙️ Main Configuration

### Required Configuration

```yaml
user:
  name: "username"          # Required: Username
ssh:
  publicKeys:               # Required: SSH public keys (array)
    - "ssh-ed25519 AAAAC3..."
```

### Commonly Used Configuration

```yaml
# Persistence
persistence:
  enabled: true
  size: 20Gi

# sudo privileges
user:
  sudo: true

# External access
service:
  type: LoadBalancer

# Monitoring
monitoring:
  enabled: true

# Security level
security:
  level: high  # basic/standard/high
```

## 📊 Management Commands

### Install & Update

```bash
# Install
helm install workspace ./ssh-workspace -f values.yaml

# Configuration check
helm template workspace ./ssh-workspace -f values.yaml

# Upgrade
helm upgrade workspace ./ssh-workspace -f values.yaml

# Uninstall
helm uninstall workspace
```

### Monitor & Debug

```bash
# Status check
kubectl get all -l app.kubernetes.io/instance=workspace

# Log check
kubectl logs -l app.kubernetes.io/instance=workspace -f

# Run Helm tests
helm test workspace

# Pod access (for debugging)
kubectl exec -it deployment/workspace-ssh-workspace -- /bin/bash
```

## 🔧 Customization

### Creating values.yaml

```yaml
# myvalues.yaml
user:
  name: "myuser"
  sudo: true
  additionalGroups:
    - docker

ssh:
  publicKeys:
    - "ssh-ed25519 AAAAC3... user@company.com"

persistence:
  enabled: true
  size: 50Gi
  storageClass: "fast-ssd"

security:
  level: high

service:
  type: LoadBalancer

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true

resources:
  limits:
    cpu: 2
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

### Helm Hooks

| Hook | Timing | Purpose |
|------|--------|---------|
| pre-install | Before installation | SSH public key & configuration validation |
| post-install | After installation | Initialization completion check |
| test | During test execution | SSH connection & resource validation |

## 🔒 Security Features

### Dual-Container Init Architecture

SSH Workspace employs a **dual-container Init Container pattern** for enhanced security:

#### Init Container (ssh-setup)
- **Purpose**: User creation and SSH configuration setup
- **Security Context**: 
  - `readOnlyRootFilesystem: false` (required for system modifications)
  - `allowPrivilegeEscalation: true`
  - Capabilities: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`, `FOWNER`
- **Operations**: Creates user, sets up SSH directory, configures authorized_keys
- **Execution Time**: Short-lived (completes setup and exits)
- **Network Exposure**: None

#### Main Container (ssh-workspace)
- **Purpose**: SSH daemon service only
- **Security Context**: `readOnlyRootFilesystem: true` (maximum security)
- **Operations**: Runs SSH daemon using pre-configured settings
- **Network Exposure**: SSH port 2222 only

### Security Levels

| Level | Purpose | Features |
|-------|---------|----------|
| basic | Development/Testing | Minimal restrictions |
| standard | Recommended | readOnlyRootFilesystem enabled |
| high | Production | seccomp RuntimeDefault + strict SSH settings |

### Permission Management Strategy

The chart uses explicit permission management for volume ownership:

- **explicit**: Direct UID/GID management without fsGroup (no SetGID bit)
- Manual file ownership control with required capabilities (CHOWN, DAC_OVERRIDE, FOWNER)
- Provides consistent behavior across different Kubernetes environments

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

### Security Features

- Public key authentication only (password authentication disabled)
- Pod Security Context applied
- Capabilities restrictions
- Network policy support (external configuration)
- Resource isolation (emptyDir, PVC)

## 🧪 Testing Configuration

### SSH Test Keys
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

### Test RBAC Configuration
```yaml
tests:
  rbac:
    create: true  # Creates ServiceAccount, Role, and RoleBinding for tests
```

Enables comprehensive testing including SSH connectivity validation and permission checks.

### Debug Configuration

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

## 🌐 Network Access

### Access Methods by Service Type

| Type | Access Method | Use Case |
|------|---------------|----------|
| ClusterIP | port-forward | Development/Testing |
| NodePort | NodeIP:NodePort | Internal network |
| LoadBalancer | External IP:Port | Production |

### Ingress Support

Requires TCP Ingress Controller:
- NGINX Ingress Controller
- HAProxy Ingress Controller
- Traefik

## 📈 Monitoring & Metrics

### Supported Metrics

- SSH connection count
- Response time
- Authentication failure count
- Resource usage (CPU, memory, storage)

### Prometheus Integration

```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

## 🔄 Upgrade & Migration

### Upgrade Strategy

- **Recreate**: With downtime (default)
- Data protection: `helm.sh/resource-policy: keep`

### Data Protection Targets

- PersistentVolumeClaim
- ConfigMap (SSH public keys)
- Secret (SSH host keys)

## 🆘 Troubleshooting

See [../USAGE.md](../USAGE.md) for detailed troubleshooting.

### Common Issues

1. **Invalid SSH public key**
   ```bash
   helm template workspace ./ssh-workspace --debug
   ```

2. **Pod startup failed**
   ```bash
   kubectl describe pod -l app.kubernetes.io/instance=workspace
   ```

3. **Connection failed**
   ```bash
   kubectl logs -l app.kubernetes.io/instance=workspace
   ```

## 🧪 Testing

```bash
# Run all tests
helm test workspace

# Run individual test
kubectl apply -f templates/tests/ssh-connection-test.yaml
```

## 📝 Custom Chart Creation

Customize based on this Chart:

1. Change name & version in `Chart.yaml`
2. Adjust default values in `values.yaml`
3. Add/modify resources in `templates/`
4. Update validation rules in `values.schema.json`