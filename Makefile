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
	@echo "Helm lifecycle targets:"
	@echo "  helm-install        - Install Helm release"
	@echo "  helm-upgrade        - Upgrade Helm release"
	@echo "  helm-rollback       - Rollback Helm release"
	@echo "  helm-uninstall      - Uninstall Helm release"
	@echo "  helm-status         - Show Helm release status"
	@echo "  helm-history        - Show Helm release history"
	@echo "  helm-list           - List Helm releases"
	@echo "  helm-lifecycle-test - Run complete lifecycle test"
	@echo ""
	@echo "No-hooks versions (for restricted environments):"
	@echo "  helm-install-no-hooks        - Install without hooks"
	@echo "  helm-upgrade-no-hooks        - Upgrade without hooks"
	@echo "  helm-rollback-no-hooks       - Rollback without hooks"
	@echo "  helm-lifecycle-test-no-hooks - Complete test without hooks"
	@echo ""
	@echo "Kind cluster targets (for local testing):"
	@echo "  create-kind-cluster - Create kind cluster for testing"
	@echo "  delete-kind-cluster - Delete kind cluster"
	@echo "  load-image-to-kind  - Load Docker image to kind cluster"
	@echo ""
	@echo "Kubernetes variables:"
	@echo "  KUBE_CONTEXT       - Kubernetes context (optional)"
	@echo "  KUBE_NAMESPACE     - Kubernetes namespace (default: default)"
	@echo "  HELM_RELEASE_NAME  - Helm release name (default: ssh-workspace-test)"
	@echo "  KIND_CLUSTER_NAME  - Kind cluster name (default: helm-ssh-workspace-test)"

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
	docker run --rm --entrypoint="" $(DOCKER_IMAGE) /opt/ssh-workspace/bin/generate-host-keys.sh --help
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

# Helm lifecycle management targets

# Kind cluster configuration for testing
KIND_CLUSTER_NAME ?= helm-ssh-workspace-test
KIND_CONFIG_FILE ?= kind-config.yaml

# Create kind cluster for testing
.PHONY: create-kind-cluster
create-kind-cluster:
	@echo "Creating kind cluster: $(KIND_CLUSTER_NAME)"
	@if ! command -v kind >/dev/null 2>&1; then \
		echo "ERROR: kind is not installed. Please install kind first."; \
		echo "Visit: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"; \
		exit 1; \
	fi
	@if kind get clusters | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Kind cluster $(KIND_CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(KIND_CLUSTER_NAME); \
		echo "Kind cluster $(KIND_CLUSTER_NAME) created successfully"; \
	fi
	@echo "Set KUBE_CONTEXT=$(KIND_CLUSTER_NAME) to use this cluster"

# Delete kind cluster
.PHONY: delete-kind-cluster
delete-kind-cluster:
	@echo "Deleting kind cluster: $(KIND_CLUSTER_NAME)"
	@if command -v kind >/dev/null 2>&1 && kind get clusters | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		kind delete cluster --name $(KIND_CLUSTER_NAME); \
		echo "Kind cluster $(KIND_CLUSTER_NAME) deleted"; \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) not found"; \
	fi

# Load Docker image to kind cluster
.PHONY: load-image-to-kind
load-image-to-kind: docker-build
	@echo "Loading Docker image to kind cluster..."
	@if ! command -v kind >/dev/null 2>&1; then \
		echo "ERROR: kind is not installed"; \
		exit 1; \
	fi
	@if ! kind get clusters | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Kind cluster $(KIND_CLUSTER_NAME) not found. Creating..."; \
		$(MAKE) create-kind-cluster; \
	fi
	kind load docker-image $(DOCKER_IMAGE) --name $(KIND_CLUSTER_NAME)
	@echo "Image loaded to kind cluster successfully"

# Variables for Helm lifecycle testing
HELM_RELEASE_NAME ?= ssh-workspace-test
HELM_NAMESPACE ?= $(KUBE_NAMESPACE)
HELM_VALUES_FILE ?= helm/values.yaml
HELM_IMAGE_REPO ?= $(DOCKER_REPO)
HELM_IMAGE_PULL_POLICY ?= Never

.PHONY: helm-install
helm-install: helm-package
	@echo "Installing Helm release: $(HELM_RELEASE_NAME)"
	@echo "Ensuring namespace exists: $(HELM_NAMESPACE)"
	@$(KUBECTL) create namespace $(HELM_NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f - || \
		(echo "Note: Using existing namespace $(HELM_NAMESPACE)" && true)
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--values $(HELM_VALUES_FILE) \
		--set image.repository=$(HELM_IMAGE_REPO) \
		--set image.pullPolicy=$(HELM_IMAGE_PULL_POLICY) \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) installed successfully"

.PHONY: helm-upgrade
helm-upgrade: helm-package
	@echo "Upgrading Helm release: $(HELM_RELEASE_NAME)"
	# Increment version for upgrade test
	helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--values $(HELM_VALUES_FILE) \
		--set image.repository=$(HELM_IMAGE_REPO) \
		--set image.pullPolicy=$(HELM_IMAGE_PULL_POLICY) \
		--set image.tag=latest \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) upgraded successfully"

.PHONY: helm-rollback
helm-rollback:
	@echo "Rolling back Helm release: $(HELM_RELEASE_NAME)"
	helm rollback $(HELM_RELEASE_NAME) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) rolled back successfully"

.PHONY: helm-uninstall
helm-uninstall:
	@echo "Uninstalling Helm release: $(HELM_RELEASE_NAME)"
	helm uninstall $(HELM_RELEASE_NAME) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) uninstalled successfully"

# Helm status and info targets
.PHONY: helm-status
helm-status:
	@echo "Checking status of Helm release: $(HELM_RELEASE_NAME)"
	helm status $(HELM_RELEASE_NAME) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT))

.PHONY: helm-history
helm-history:
	@echo "Showing history of Helm release: $(HELM_RELEASE_NAME)"
	helm history $(HELM_RELEASE_NAME) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT))

.PHONY: helm-list
helm-list:
	@echo "Listing Helm releases in namespace: $(HELM_NAMESPACE)"
	helm list \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT))

# No-hooks versions for testing in restricted environments
.PHONY: helm-install-no-hooks
helm-install-no-hooks: helm-package
	@echo "Installing Helm release (no hooks): $(HELM_RELEASE_NAME)"
	@echo "Ensuring namespace exists: $(HELM_NAMESPACE)"
	@$(KUBECTL) create namespace $(HELM_NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f - || \
		(echo "Note: Using existing namespace $(HELM_NAMESPACE)" && true)
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--values $(HELM_VALUES_FILE) \
		--set image.repository=$(HELM_IMAGE_REPO) \
		--set image.pullPolicy=$(HELM_IMAGE_PULL_POLICY) \
		--no-hooks \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) installed successfully (no hooks)"

.PHONY: helm-upgrade-no-hooks
helm-upgrade-no-hooks: helm-package
	@echo "Upgrading Helm release (no hooks): $(HELM_RELEASE_NAME)"
	helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--values $(HELM_VALUES_FILE) \
		--set image.repository=$(HELM_IMAGE_REPO) \
		--set image.pullPolicy=$(HELM_IMAGE_PULL_POLICY) \
		--set image.tag=latest \
		--no-hooks \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) upgraded successfully (no hooks)"

.PHONY: helm-rollback-no-hooks
helm-rollback-no-hooks:
	@echo "Rolling back Helm release (no hooks): $(HELM_RELEASE_NAME)"
	helm rollback $(HELM_RELEASE_NAME) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--no-hooks \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) rolled back successfully (no hooks)"

# Complete Helm lifecycle test
.PHONY: helm-lifecycle-test
helm-lifecycle-test: docker-build helm-package
	@echo "Starting complete Helm lifecycle test..."
	@echo "=== Phase 1: Install ==="
	$(MAKE) helm-install KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) helm-status KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Phase 2: Upgrade ==="
	$(MAKE) helm-upgrade KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) helm-history KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Phase 3: Rollback ==="
	$(MAKE) helm-rollback KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) helm-status KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Phase 4: Uninstall ==="
	$(MAKE) helm-uninstall KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Helm lifecycle test completed successfully ==="

# Helm lifecycle test without hooks (for restricted environments)
.PHONY: helm-lifecycle-test-no-hooks
helm-lifecycle-test-no-hooks: docker-build helm-package
	@echo "Starting Helm lifecycle test (no hooks)..."
	@echo "=== Phase 1: Install (no hooks) ==="
	$(MAKE) helm-install-no-hooks KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) helm-status KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Phase 2: Upgrade (no hooks) ==="
	$(MAKE) helm-upgrade-no-hooks KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) helm-history KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Phase 3: Rollback (no hooks) ==="
	$(MAKE) helm-rollback-no-hooks KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) helm-status KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Phase 4: Uninstall ==="
	$(MAKE) helm-uninstall KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "=== Helm lifecycle test (no hooks) completed successfully ==="