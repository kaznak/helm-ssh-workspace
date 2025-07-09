# Makefile for SSH Workspace
# Design reference: [B6Y3-MAKEFILE]

# Variables
DOCKER_REPO ?= ssh-workspace
DOCKER_TAG ?= latest
DOCKER_IMAGE = $(DOCKER_REPO):$(DOCKER_TAG)
HELM_CHART_DIR = helm
HELM_PACKAGE_DIR = dist
DOCKER_BUILD_DIR = docker

# Kubernetes configuration
KUBE_CONTEXT ?= 
KUBE_NAMESPACE ?= default
KUBECTL_OPTS = $(if $(KUBE_CONTEXT),--context=$(KUBE_CONTEXT)) $(if $(KUBE_NAMESPACE),--namespace=$(KUBE_NAMESPACE))
KUBECTL = kubectl $(KUBECTL_OPTS)

# Default target
.PHONY: all
all: docker-build test helm-package

# Help target
.PHONY: help
help:
	@echo "Main targets:"
	@echo "  all          - Build, test, and package"
	@echo "  docker-build - Build Docker image"
	@echo "  test         - Run tests"
	@echo "  helm-package - Package Helm chart"
	@echo "  clean        - Clean build artifacts"
	@echo ""
	@echo "Kubernetes variables:"
	@echo "  KUBE_CONTEXT   - Kubernetes context (optional)"
	@echo "  KUBE_NAMESPACE - Kubernetes namespace (default: default)"

# Build targets

.PHONY: docker-build
docker-build:
	@echo "Building Docker image: $(DOCKER_IMAGE)"
	docker build -t $(DOCKER_IMAGE) -f $(DOCKER_BUILD_DIR)/Dockerfile .

# Test targets
.PHONY: test
test: lint helm-test docker-test

.PHONY: lint
lint: helm-lint

.PHONY: helm-lint
helm-lint:
	@echo "Linting Helm chart..."
	helm lint $(HELM_CHART_DIR)

.PHONY: helm-test
helm-test: helm-lint
	@echo "Testing Helm chart..."
	helm template test $(HELM_CHART_DIR) --debug --dry-run > /dev/null
	@echo "Helm template test passed"

.PHONY: docker-test
docker-test: docker-build
	@echo "Testing Docker image..."
	docker run --rm $(DOCKER_IMAGE) /opt/ssh-workspace/bin/generate-host-keys.sh --help
	@echo "Docker image test passed"

# Security testing
.PHONY: security
security: docker-security helm-security

.PHONY: docker-security
docker-security:
	@echo "Running Docker security tests..."
	trivy image --exit-code 1 --severity HIGH,CRITICAL $(DOCKER_IMAGE)
	hadolint $(DOCKER_BUILD_DIR)/Dockerfile

.PHONY: helm-security
helm-security:
	@echo "Running Helm security tests..."
	helm template test $(HELM_CHART_DIR) | kubesec scan -

# Package targets

.PHONY: helm-package
helm-package: helm-test
	@echo "Packaging Helm chart..."
	mkdir -p $(HELM_PACKAGE_DIR)
	helm package $(HELM_CHART_DIR) --destination $(HELM_PACKAGE_DIR)
	@echo "Helm chart packaged in $(HELM_PACKAGE_DIR)"

# Publish targets
.PHONY: publish
publish: docker-push helm-publish

.PHONY: docker-push
docker-push: docker-build docker-test
	@echo "Pushing Docker image: $(DOCKER_IMAGE)"
	docker push $(DOCKER_IMAGE)

.PHONY: helm-publish
helm-publish: helm-package
	@echo "Publishing Helm chart..."
	@echo "ERROR: Helm publishing not implemented"
	@exit 1

# Quality assurance targets
.PHONY: quality
quality: lint security

# Development targets

.PHONY: dev-test
dev-test: docker-build
	@echo "Running development tests..."
	$(KUBECTL) create namespace ssh-workspace-test --dry-run=client -o yaml | $(KUBECTL) apply -f -
	@echo "ERROR: SSH public key required for testing"
	@echo "Usage: make dev-test SSH_PUBKEY=\"\$$(cat ~/.ssh/id_rsa.pub)\""
	@exit 1

.PHONY: dev-clean
dev-clean:
	@echo "Cleaning development environment..."
	# Remove test namespace
	$(KUBECTL) delete namespace ssh-workspace-test --ignore-not-found=true
	@echo "Development environment cleaned"

# Clean targets
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(HELM_PACKAGE_DIR)
	# Remove Docker images
	docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "Clean complete"



# Integration tests
.PHONY: integration-test
integration-test: docker-build
	@echo "Running integration tests..."
	$(MAKE) dev-test KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) dev-clean KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "Integration tests passed"