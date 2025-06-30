# SSH Workspace - Usage Guide

SSH Workspace is an SSH-accessible development environment that runs on Kubernetes.

## 🚀 Quick Start

### 1. Basic Deployment

```bash
# Prepare SSH public key (required)
export SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@example.com"

# Basic deployment
helm install my-workspace ./ssh-workspace \
  --set user.name="developer" \
  --set ssh.publicKeys[0]="$SSH_PUBLIC_KEY"
```

### 2. Connection Method

```bash
# Access via port forwarding (when using ClusterIP)
kubectl port-forward svc/my-workspace-ssh-workspace 2222:22

# SSH connection
ssh developer@localhost -p 2222
```

## 📋 Detailed Configuration

### User Configuration

```yaml
user:
  name: "myuser"          # Required: Username
  uid: 1001               # Optional: UID
  gid: 1001               # Optional: GID
  shell: /bin/bash        # Login shell
  sudo: true              # sudo privileges
  additionalGroups:       # Additional groups
    - docker
    - wheel
```

### Timezone Configuration

```yaml
timezone: "Asia/Tokyo"    # Timezone setting
```

#### Available Timezone List
```bash
# Check within container
kubectl exec deployment/workspace-ssh-workspace -- timedatectl list-timezones

# Major timezone examples
# UTC, GMT                    # Coordinated Universal Time
# Asia/Tokyo                  # Japan Standard Time (JST)
# America/New_York            # US Eastern Standard Time
# America/Los_Angeles         # US Pacific Standard Time
# Europe/London               # United Kingdom
# Europe/Paris                # France/Germany/Central Europe
# Asia/Shanghai               # China Standard Time
# Asia/Seoul                  # Korea Standard Time
```

### SSH Configuration

```yaml
ssh:
  publicKeys:             # Required: SSH public key list
    - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user1@example.com"
    - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... user2@example.com"
  port: 22               # SSH port
  config:                # Additional SSH configuration
    MaxAuthTries: "3"
    LoginGraceTime: "30"
```

### Persistence Configuration

```yaml
persistence:
  enabled: true           # Enable persistence
  size: 50Gi             # Storage size
  storageClass: "ssd"    # Storage class
  accessModes:
    - ReadWriteOnce
```

### Security Levels

```yaml
security:
  level: standard         # basic | standard | high
  # basic:    For development/testing (minimal restrictions)
  # standard: Recommended settings (readOnlyRootFilesystem enabled)
  # high:     For production (AppArmor + strict settings)
```

## 🌐 External Access Configuration

### Using NodePort

```yaml
service:
  type: NodePort
  port: 22
  nodePort: 30022        # Optional: Fixed NodePort
```

### Using LoadBalancer

```yaml
service:
  type: LoadBalancer
  port: 22
```

### Using Ingress (TCP)

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/tcp-services-configmap: "default/tcp-services"
  hosts:
    - host: ssh.example.com
      paths:
        - path: /
          pathType: Prefix
```

## 📊 Monitoring Configuration

```yaml
monitoring:
  enabled: true           # Enable ssh_exporter
  port: 9312             # Metrics port
  serviceMonitor:
    enabled: true         # Prometheus ServiceMonitor
    interval: 30s         # Scrape interval
```

## 🛠️ Management Commands

### Deployment Management

```bash
# Install
helm install workspace ./ssh-workspace -f values.yaml

# Upgrade
helm upgrade workspace ./ssh-workspace -f values.yaml

# Uninstall (data retained)
helm uninstall workspace

# Complete removal (delete data too)
helm uninstall workspace
kubectl delete pvc workspace-ssh-workspace-home
kubectl delete configmap workspace-ssh-workspace-ssh-keys
kubectl delete secret workspace-ssh-workspace-host-keys
```

### Status Check

```bash
# Check all resources
kubectl get all -l app.kubernetes.io/instance=workspace

# Check logs
kubectl logs -l app.kubernetes.io/instance=workspace -f

# Run tests
helm test workspace
```

### Debugging

```bash
# Enter pod (for troubleshooting)
kubectl exec -it deployment/workspace-ssh-workspace -- /bin/bash

# Check SSH configuration
kubectl exec -it deployment/workspace-ssh-workspace -- /usr/sbin/sshd -T

# Check public keys
kubectl get configmap workspace-ssh-workspace-ssh-keys -o yaml
```

## 🔧 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check pod status
   kubectl get pods -l app.kubernetes.io/instance=workspace
   
   # Check logs
   kubectl logs -l app.kubernetes.io/instance=workspace --tail=50
   ```

2. **Authentication Failed**
   ```bash
   # Check public key configuration
   kubectl get configmap workspace-ssh-workspace-ssh-keys -o yaml
   
   # SSH connection test (verbose logging)
   ssh -vvv user@host -p port
   ```

3. **Pod Startup Failed**
   ```bash
   # Check events
   kubectl describe pod -l app.kubernetes.io/instance=workspace
   
   # Validate configuration values
   helm template workspace ./ssh-workspace -f values.yaml --debug
   ```

## 📝 Configuration Examples

### Development Environment

```yaml
user:
  name: "developer"
  sudo: true
ssh:
  publicKeys:
    - "ssh-ed25519 AAAAC3... dev@localhost"
security:
  level: basic
monitoring:
  enabled: true
```

### Production Environment

```yaml
user:
  name: "prod-user"
  uid: 2000
  gid: 2000
  sudo: false
ssh:
  publicKeys:
    - "ssh-ed25519 AAAAC3... user@company.com"
persistence:
  enabled: true
  size: 100Gi
  storageClass: "premium-ssd"
security:
  level: high
service:
  type: LoadBalancer
resources:
  limits:
    cpu: 2
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## 🔒 Security Best Practices

1. **Always use the latest security level**
   ```yaml
   security:
     level: high  # Required for production
   ```

2. **Use strong SSH keys**
   ```bash
   # Generate ED25519 key (recommended)
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

3. **Enable persistence and regular backups**
   ```yaml
   persistence:
     enabled: true
   ```

4. **Set resource limits**
   ```yaml
   resources:
     limits:
       cpu: 1
       memory: 2Gi
   ```

5. **Enable monitoring**
   ```yaml
   monitoring:
     enabled: true
   ```

## 📞 Support

- Issue Reports: [GitHub Issues](https://github.com/example/ssh-workspace/issues)
- Documentation: [Wiki](https://github.com/example/ssh-workspace/wiki)
- FAQ: [Troubleshooting Guide](https://github.com/example/ssh-workspace/docs/faq.md)