# Helm Chart OCI Format Guide

## 🎯 What is OCI Format?

OCI (Open Container Initiative) format allows Helm charts to be stored in container registries alongside Docker images, using the same infrastructure and protocols.

## 📊 Traditional vs OCI Format

### Traditional Helm Repository
```
https://charts.example.com/
├── index.yaml                 # Chart index file
├── ssh-workspace-1.0.0.tgz   # Chart package
├── ssh-workspace-1.0.1.tgz   # Chart package
└── ssh-workspace-1.0.2.tgz   # Chart package
```

### OCI Registry Structure
```
ghcr.io/username/charts/
└── ssh-workspace
    ├── 1.0.0     # Chart manifest + layers
    ├── 1.0.1     # Chart manifest + layers
    └── latest    # Tag pointing to latest version
```

## 🔄 How OCI Format Works

### 1. **Chart as Container Image**
```yaml
# Chart is packaged as OCI artifact
mediaType: application/vnd.oci.image.manifest.v1+json
config:
  mediaType: application/vnd.cncf.helm.config.v1+json
layers:
  - mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    digest: sha256:abc123...
    size: 12345
```

### 2. **Storage Structure**
- **Manifest**: Describes the chart metadata
- **Config**: Chart.yaml content
- **Layers**: Compressed chart content (templates, values, etc.)

## 💻 Usage Examples

### Traditional Method
```bash
# Add repository
helm repo add myrepo https://charts.example.com
helm repo update

# Search charts
helm search repo myrepo/

# Install chart
helm install release-name myrepo/ssh-workspace --version 1.0.0

# Pull chart
helm pull myrepo/ssh-workspace --version 1.0.0
```

### OCI Method
```bash
# No need to add repository!

# Install chart directly
helm install release-name oci://ghcr.io/username/charts/ssh-workspace --version 1.0.0

# Pull chart
helm pull oci://ghcr.io/username/charts/ssh-workspace --version 1.0.0

# Push chart
helm push ssh-workspace-1.0.0.tgz oci://ghcr.io/username/charts
```

## 🎨 Key Differences

| Feature | Traditional | OCI |
|---------|-------------|-----|
| **Repository Management** | `helm repo add` required | Direct URL access |
| **Index File** | Centralized index.yaml | No index file needed |
| **Storage** | Web server | Container registry |
| **Authentication** | Basic auth/tokens | Docker login |
| **Versioning** | File-based | Tag-based |
| **Caching** | Local repo cache | Registry cache |

## 🚀 Advantages of OCI Format

### 1. **Unified Infrastructure**
- Same registry for Docker images and Helm charts
- Single authentication mechanism
- Consistent access control

### 2. **Better Performance**
- Content-addressable storage
- Layer deduplication
- Efficient caching

### 3. **Enhanced Security**
- Image signing support
- Vulnerability scanning
- Access control via registry

### 4. **Simplified Management**
- No separate Helm repository needed
- Automatic garbage collection
- Built-in replication

## 🔧 Registry Support

### Fully Supported
- **Docker Hub**: Full OCI support
- **GitHub Container Registry (GHCR)**: Recommended
- **Azure Container Registry (ACR)**: Full support
- **Amazon ECR**: Full support
- **Google Artifact Registry**: Full support
- **Harbor**: v2.0+ with OCI support

### Configuration Examples

#### GitHub Container Registry
```bash
# Login
helm registry login ghcr.io -u USERNAME -p TOKEN

# Push
helm push mychart-1.0.0.tgz oci://ghcr.io/username/charts

# Install
helm install release oci://ghcr.io/username/charts/mychart --version 1.0.0
```

#### Docker Hub
```bash
# Login
helm registry login docker.io -u USERNAME -p PASSWORD

# Push
helm push mychart-1.0.0.tgz oci://docker.io/username

# Install
helm install release oci://docker.io/username/mychart --version 1.0.0
```

## 📝 Migration Guide

### From Traditional to OCI

1. **Package existing chart**
   ```bash
   helm package ./mychart
   ```

2. **Login to registry**
   ```bash
   helm registry login ghcr.io -u USERNAME -p TOKEN
   ```

3. **Push to OCI registry**
   ```bash
   helm push mychart-1.0.0.tgz oci://ghcr.io/username/charts
   ```

4. **Update documentation**
   ```bash
   # Old
   helm install release myrepo/mychart
   
   # New
   helm install release oci://ghcr.io/username/charts/mychart
   ```

## ⚠️ Considerations

### Limitations
- **Helm 3.8+** required for full OCI support
- **No browsing**: Can't list charts without registry API
- **No search**: `helm search` doesn't work with OCI

### Best Practices
1. **Use semantic versioning**: Tag charts with proper versions
2. **Sign charts**: Use cosign for chart signing
3. **Automate publishing**: Use CI/CD for consistent releases
4. **Document registry URL**: Make it easy for users to find

## 🔍 Debugging OCI Issues

### Common Problems

1. **Authentication Failed**
   ```bash
   # Ensure Docker login
   docker login ghcr.io
   
   # Or Helm registry login
   helm registry login ghcr.io
   ```

2. **Chart Not Found**
   ```bash
   # Check exact URL
   helm show chart oci://ghcr.io/username/charts/mychart --version 1.0.0
   ```

3. **Version Issues**
   ```bash
   # List available versions (if registry supports)
   crane ls ghcr.io/username/charts/mychart
   ```

## 📚 Further Reading

- [OCI Distribution Spec](https://github.com/opencontainers/distribution-spec)
- [Helm OCI Documentation](https://helm.sh/docs/topics/registries/)
- [CNCF OCI Artifacts](https://github.com/opencontainers/artifacts)