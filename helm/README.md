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

### Security Levels

| Level | Purpose | Features |
|-------|---------|----------|
| basic | Development/Testing | Minimal restrictions |
| standard | Recommended | readOnlyRootFilesystem enabled |
| high | Production | AppArmor + strict SSH settings |

### Security Features

- Public key authentication only (password authentication disabled)
- Pod Security Context applied
- Capabilities restrictions
- Network policy support (external configuration)
- Resource isolation (emptyDir, PVC)

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