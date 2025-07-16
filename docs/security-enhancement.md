# Security Enhancement: ConfigMap-based User Management

## Overview

This document describes the implementation of ConfigMap-based user management system that provides enhanced security by eliminating the need for root privileges in the main SSH workspace container, following the traditional UNIX NIS-style approach.

## Security Improvements

### Before: Traditional Mode
- **Main container**: root privileges required
- **Security Context**: 
  - `runAsUser: 0`
  - `allowPrivilegeEscalation: true`
  - `capabilities: ["CHOWN", "DAC_OVERRIDE"]`
- **Risk**: High security risk due to root privileges in runtime

### After: ConfigMap Mode  
- **Init container**: Root privileges only during initialization
- **Main container**: Non-root execution
- **Security Context**:
  - `runAsUser: 1000` (target user)
  - `runAsNonRoot: true`
  - `allowPrivilegeEscalation: false`
  - `capabilities: drop: ["ALL"]`
- **Risk**: Significantly reduced security risk

## Architecture

### 1. ConfigMap-based User Database [see:U4N8-USERDB]

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssh-workspace-users
data:
  passwd: |
    developer:x:1000:1000:Developer:/home/developer:/bin/bash
  group: |
    developer:x:1000:
  shadow: |
    developer:*:19000:0:99999:7:::
```

### 2. Init Container Process

1. **User Database Initialization**: 
   - Merges ConfigMap user data with system users
   - Updates `/etc/passwd`, `/etc/group`, `/etc/shadow`
   - Sets proper file permissions

2. **Validation**:
   - Verifies user lookup functionality (`getent`)
   - Ensures NSS resolution works correctly

### 3. Main Container Process

1. **User Validation**: Verifies user exists in database
2. **SSH Setup**: Configures SSH keys and directories  
3. **Service Start**: Runs Dropbear SSH server as target user

## Configuration

### Enable ConfigMap-based User Management

```yaml
# values.yaml
userManagement:
  configMapBased:
    enabled: true  # Default: false
    users:
      - name: developer
        uid: 1000
        gid: 1000
        comment: "Developer User"
        home: "/home/developer"
        shell: "/bin/bash"
    groups:
      - name: developer
        gid: 1000
        members: ""
```

## Security Benefits

### 1. **Minimal Privilege Principle**
- Root privileges only during initialization
- Runtime execution with minimal permissions
- No capability escalation in main container

### 2. **Attack Surface Reduction**
- SSH server runs as non-root user
- Limited blast radius if compromised
- Container escape risks significantly reduced

### 3. **Compliance Alignment**
- Meets Pod Security Standards "Restricted" level
- Compatible with security policies requiring non-root containers
- Follows defense-in-depth principles

## Comparison with Traditional UNIX NIS

| Aspect | Traditional NIS | ConfigMap Approach |
|--------|-----------------|-------------------|
| User Database | Centralized NIS server | Kubernetes ConfigMap |
| Distribution | Network protocols | Kubernetes API |
| Caching | Local ypbind cache | Init container setup |
| Security | Network authentication | RBAC + ConfigMap |
| Scalability | NIS master/slave | Kubernetes native |

## Implementation Details

### Files Modified

1. **`helm/templates/configmap-users.yaml`**: User database ConfigMap
2. **`docker/scripts/init-users.sh`**: Init container user setup script  
3. **`helm/templates/deployment.yaml`**: Init container and security context
4. **`docker/scripts/start-ssh-server.sh`**: Mode-aware startup logic
5. **`helm/values.yaml`**: Configuration options

### Resource Requirements

```yaml
jobResources:
  userInit:
    limits:
      cpu: 100m
      memory: 128Mi
      ephemeral-storage: 500Mi
    requests:
      cpu: 25m
      memory: 32Mi
      ephemeral-storage: 50Mi
```

## Migration Path

### Phase 1: Dual Mode Support
- Both traditional and ConfigMap modes supported
- Default remains traditional for compatibility
- Gradual adoption possible

### Phase 2: Security Default
- Change default to ConfigMap mode
- Provide migration documentation
- Deprecation notice for traditional mode

### Phase 3: Traditional Mode Removal
- Remove traditional mode support
- Enforce ConfigMap-based security model
- Full compliance with security standards

## Testing

### Security Validation
```bash
# Verify non-root execution
kubectl exec ssh-workspace-pod -- id
# Should return: uid=1000(developer) gid=1000(developer)

# Verify no privilege escalation
kubectl exec ssh-workspace-pod -- cat /proc/self/status | grep NoNewPrivs
# Should return: NoNewPrivs: 1

# Verify capabilities
kubectl exec ssh-workspace-pod -- grep Cap /proc/self/status
# Should show minimal capabilities
```

### Functional Testing
```bash
# SSH connectivity test
ssh -p 2222 developer@ssh-workspace-service

# User environment test
id && pwd && ls -la

# Container tools test (if enabled)
docker --version && podman --version
```

## Conclusion

The ConfigMap-based user management system provides a significant security enhancement while maintaining full SSH workspace functionality. By applying the traditional UNIX NIS approach to Kubernetes, we achieve both security and operational excellence.

This implementation demonstrates that security and functionality are not mutually exclusive, and that proper architectural design can provide robust security without sacrificing user experience.