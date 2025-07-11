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
	@echo "k3d cluster targets (for local testing):"
	@echo "  create-k3d-cluster      - Create k3d cluster for testing"
	@echo "  delete-k3d-cluster      - Delete k3d cluster"
	@echo "  load-image-to-k3d       - Load Docker image to k3d cluster"
	@echo "  generate-test-ssh-key   - Generate test SSH key pair in tmp/"
	@echo "  prepare-test-env        - Prepare test environment with SSH key validation"
	@echo ""
	@echo "Kubernetes variables:"
	@echo "  KUBE_CONTEXT       - Kubernetes context (optional)"
	@echo "  KUBE_NAMESPACE     - Kubernetes namespace (default: default)"
	@echo "  HELM_RELEASE_NAME  - Helm release name (default: ssh-workspace-test)"
	@echo "  KIND_CLUSTER_NAME  - Kind cluster name (default: helm-ssh-workspace-test)"
	@echo "  TEST_SSH_PUBKEY    - SSH public key for testing (required for helm operations)"

# Build targets

# Sentinel file to track when Docker image needs rebuilding
tmp/.docker-build-sentinel: $(DOCKER_BUILD_DIR)/Dockerfile $(wildcard $(DOCKER_BUILD_DIR)/scripts/*)
	@echo "Building Docker image: $(DOCKER_IMAGE)"
	@mkdir -p tmp
	docker build -t $(DOCKER_IMAGE) -f $(DOCKER_BUILD_DIR)/Dockerfile .
	@touch tmp/.docker-build-sentinel

.PHONY: docker-build
docker-build: tmp/.docker-build-sentinel

# Test targets
.PHONY: test
test: lint helm-test docker-test

.PHONY: lint
lint: helm-lint markdown-lint

.PHONY: helm-lint
helm-lint:
	@echo "Linting Helm chart..."
	helm lint $(HELM_CHART_DIR)

.PHONY: helm-test
helm-test: helm-lint
	@echo "Testing Helm chart..."
	helm template test $(HELM_CHART_DIR) --debug --dry-run > /dev/null
	@echo "Helm template test passed"

.PHONY: markdown-lint
markdown-lint:
	@echo "Checking markdown links..."
	# lychee --offline --no-progress --verbose **/*.md *.md
	lychee --no-progress --verbose --exclude-path tmp/ **/*.md *.md

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
	@echo "Running Helm security check with Kube-score..."
	@mkdir -p tmp
	@echo "::group::Kube-score Reports"
	@helm template test $(HELM_CHART_DIR) | kube-score score --exit-one-on-warning - 2>&1 | tee tmp/kube-score_output.txt; \
	KUBESCORE_EXIT_CODE=$$?; \
	echo "::endgroup::"; \
	KUBESCORE_OUTPUT=$$(cat tmp/kube-score_output.txt); \
	if [ $$KUBESCORE_EXIT_CODE -ne 0 ]; then \
		echo "❌ kube-score scan failed with exit code: $$KUBESCORE_EXIT_CODE"; \
		echo "kube-score output: $$KUBESCORE_OUTPUT"; \
		exit 1; \
	fi; \
	echo "✅ Kube-score security check completed successfully"
	@echo "Helm security check completed"

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
docker-push: tmp/.docker-build-sentinel docker-test
	@echo "Pushing Docker image: $(DOCKER_IMAGE)"
	docker push $(DOCKER_IMAGE)

# Helm OCI registry configuration
HELM_REGISTRY ?= ghcr.io
HELM_REGISTRY_PATH ?= $(HELM_REGISTRY)/$(shell git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^.]*\).*/\1/')/charts

.PHONY: helm-publish
helm-publish: helm-package
	@echo "Publishing Helm chart to OCI registry..."
	@if [ -z "$(HELM_REGISTRY_TOKEN)" ]; then \
		echo "ERROR: HELM_REGISTRY_TOKEN environment variable is required"; \
		exit 1; \
	fi
	@echo "$$HELM_REGISTRY_TOKEN" | helm registry login $(HELM_REGISTRY) -u "$(HELM_REGISTRY_USER)" --password-stdin
	@helm push dist/ssh-workspace-*.tgz oci://$(HELM_REGISTRY_PATH)
	@echo "✅ Helm chart published to oci://$(HELM_REGISTRY_PATH)/ssh-workspace"

# Quality assurance targets
.PHONY: quality
quality: lint security

# Development targets

.PHONY: e2e-test
e2e-test: tmp/.k3d-image-loaded-sentinel helm-package
	@echo "Running end-to-end SSH connection tests..."
	@if [ -z "$(SSH_PUBKEY)" ]; then \
		if [ -f "$(TEST_SSH_KEY_FILE).pub" ]; then \
			SSH_PUBKEY="$$(cat $(TEST_SSH_KEY_FILE).pub)"; \
			echo "Using test SSH key: $$SSH_PUBKEY"; \
		else \
			echo "ERROR: SSH public key required for testing"; \
			echo "Usage: make e2e-test SSH_PUBKEY=\"\$$(cat ~/.ssh/id_rsa.pub)\""; \
			echo "Or generate test key with: make generate-test-ssh-key"; \
			exit 1; \
		fi; \
	else \
		echo "Using provided SSH key: $(SSH_PUBKEY)"; \
	fi; \
	echo "Creating test namespace..."; \
	$(KUBECTL) create namespace ssh-workspace-test --dry-run=client -o yaml | $(KUBECTL) apply -f -; \
	echo "Installing SSH workspace for testing..."; \
	helm install ssh-workspace-dev-test $(HELM_CHART_DIR) \
		--namespace ssh-workspace-test \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--set image.repository=$(DOCKER_REPO) \
		--set image.tag=$(DOCKER_TAG) \
		--set image.pullPolicy=Never \
		--set ssh.publicKeys.authorizedKeys="$$SSH_PUBKEY" \
		--wait --timeout=120s; \
	echo "Waiting for pod to be ready..."; \
	$(KUBECTL) wait --for=condition=ready pod -l app.kubernetes.io/name=ssh-workspace --timeout=60s -n ssh-workspace-test; \
	echo "Testing SSH connection..."; \
	POD_NAME=$$($(KUBECTL) get pods -n ssh-workspace-test -l app.kubernetes.io/name=ssh-workspace -o jsonpath='{.items[0].metadata.name}'); \
	echo "Starting port-forward for pod: $$POD_NAME"; \
	$(KUBECTL) port-forward -n ssh-workspace-test $$POD_NAME 12222:2222 & \
	PF_PID=$$!; \
	echo "Port-forward PID: $$PF_PID"; \
	echo "Waiting for port-forward to establish..."; \
	for i in $$(seq 1 30); do \
		if nc -z localhost 12222 2>/dev/null; then \
			echo "Port 12222 is ready after $$i seconds"; \
			break; \
		fi; \
		sleep 1; \
	done; \
	echo "Testing SSH connection on port 12222..."; \
	echo "Debug: SSH command: ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i $(TEST_SSH_KEY_FILE) -p 12222 developer@localhost 'echo SSH connection successful'"; \
	if timeout 30 ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i $(TEST_SSH_KEY_FILE) -p 12222 developer@localhost 'echo "SSH connection successful"'; then \
		echo "✅ SSH connection test passed"; \
		kill $$PF_PID 2>/dev/null || true; \
	else \
		echo "❌ SSH connection test failed"; \
		echo "Checking pod logs for debugging:"; \
		$(KUBECTL) logs -n ssh-workspace-test $$POD_NAME --tail=20; \
		kill $$PF_PID 2>/dev/null || true; \
		exit 1; \
	fi; \
	echo "Cleaning up test deployment..."; \
	helm uninstall ssh-workspace-dev-test --namespace ssh-workspace-test $(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) --wait; \
	echo "✅ End-to-end SSH connection test completed successfully"

.PHONY: test-clean
test-clean:
	@echo "Cleaning test environment..."
	# Kill any existing port-forward processes
	-@pkill -f "port-forward.*ssh-workspace-test" 2>/dev/null || true
	# Remove test namespace
	$(KUBECTL) delete namespace ssh-workspace-test --ignore-not-found=true
	@echo "Test environment cleaned"

# Clean targets
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(HELM_PACKAGE_DIR)
	rm -rf tmp
	# Remove Docker images
	docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "Clean complete"



# Integration tests
.PHONY: integration-test
integration-test: docker-build
	@echo "Running integration tests..."
	$(MAKE) e2e-test KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	$(MAKE) test-clean KUBE_CONTEXT=$(KUBE_CONTEXT) KUBE_NAMESPACE=$(KUBE_NAMESPACE)
	@echo "Integration tests passed"

# Helm lifecycle management targets

# k3d cluster configuration for testing
K3D_CLUSTER_NAME ?= helm-ssh-workspace-test
K3D_REGISTRY_PORT ?= 5000
# Set to 'external' in CI/CD environments where cluster is managed externally
K3D_CLUSTER_MANAGEMENT ?= local

# Sentinel file for k3d cluster
tmp/.k3d-cluster-created-sentinel:
	@mkdir -p tmp
	@if [ "$(K3D_CLUSTER_MANAGEMENT)" = "external" ]; then \
		echo "Using externally managed k3d cluster"; \
		touch tmp/.k3d-cluster-created-sentinel; \
	else \
		echo "Creating k3d cluster: $(K3D_CLUSTER_NAME)"; \
		if ! command -v k3d >/dev/null 2>&1; then \
			echo "ERROR: k3d is not installed. Please install k3d first."; \
			echo "Visit: https://k3d.io/v5.6.0/#installation"; \
			exit 1; \
		fi; \
		if k3d cluster list | grep -q "^$(K3D_CLUSTER_NAME)"; then \
			echo "k3d cluster $(K3D_CLUSTER_NAME) already exists"; \
		else \
			k3d cluster create $(K3D_CLUSTER_NAME) \
				--port "2222:2222@loadbalancer" \
				--wait --timeout 60s; \
			echo "k3d cluster $(K3D_CLUSTER_NAME) created successfully"; \
		fi; \
		echo "Cluster context: k3d-$(K3D_CLUSTER_NAME)"; \
		touch tmp/.k3d-cluster-created-sentinel; \
	fi

# Create k3d cluster for testing
.PHONY: create-k3d-cluster
create-k3d-cluster: tmp/.k3d-cluster-created-sentinel

# Delete k3d cluster
.PHONY: delete-k3d-cluster
delete-k3d-cluster:
	@if [ "$(K3D_CLUSTER_MANAGEMENT)" = "external" ]; then \
		echo "Skipping deletion of externally managed k3d cluster"; \
	else \
		echo "Deleting k3d cluster: $(K3D_CLUSTER_NAME)"; \
		if command -v k3d >/dev/null 2>&1 && k3d cluster list | grep -q "^$(K3D_CLUSTER_NAME)"; then \
			k3d cluster delete $(K3D_CLUSTER_NAME); \
			echo "k3d cluster $(K3D_CLUSTER_NAME) deleted"; \
		else \
			echo "k3d cluster $(K3D_CLUSTER_NAME) not found"; \
		fi; \
	fi
	@rm -f tmp/.k3d-cluster-created-sentinel tmp/.k3d-image-loaded-sentinel

# Load Docker image to k3d cluster
tmp/.k3d-image-loaded-sentinel: tmp/.docker-build-sentinel tmp/.k3d-cluster-created-sentinel
	@echo "Loading Docker image to k3d cluster..."
	@mkdir -p tmp
	k3d image import $(DOCKER_IMAGE) --cluster $(K3D_CLUSTER_NAME)
	@touch tmp/.k3d-image-loaded-sentinel
	@echo "Image loaded to k3d cluster successfully"

.PHONY: load-image-to-k3d
load-image-to-k3d: tmp/.k3d-image-loaded-sentinel

# Test environment preparation
TEST_SSH_PUBKEY ?= 
TEST_SSH_KEY_FILE ?= tmp/test_ssh_key

# Sentinel file for test SSH key generation
tmp/.test-ssh-key-generated-sentinel:
	@echo "Generating test SSH key pair..."
	@mkdir -p tmp
	@ssh-keygen -t rsa -b 2048 -f $(TEST_SSH_KEY_FILE) -N "" -C "test@ssh-workspace.local"
	@echo "Test SSH key pair generated:"
	@echo "  Private key: $(TEST_SSH_KEY_FILE)"
	@echo "  Public key:  $(TEST_SSH_KEY_FILE).pub"
	@touch tmp/.test-ssh-key-generated-sentinel

.PHONY: generate-test-ssh-key
generate-test-ssh-key: tmp/.test-ssh-key-generated-sentinel

.PHONY: prepare-test-env
prepare-test-env:
	@echo "Preparing test environment..."
	@if [ -z "$(TEST_SSH_PUBKEY)" ]; then \
		if [ ! -f "$(TEST_SSH_KEY_FILE).pub" ]; then \
			echo "No SSH public key provided and test key not found. Generating test key..."; \
			$(MAKE) generate-test-ssh-key; \
		fi; \
		TEST_SSH_PUBKEY="$$(cat $(TEST_SSH_KEY_FILE).pub)"; \
		echo "Using generated test SSH key: $$TEST_SSH_PUBKEY"; \
	else \
		echo "Using provided SSH public key: $(TEST_SSH_PUBKEY)"; \
	fi
	@echo "Test environment preparation completed"

# Variables for Helm lifecycle testing
HELM_RELEASE_NAME ?= ssh-workspace-test
HELM_NAMESPACE ?= $(KUBE_NAMESPACE)
HELM_VALUES_FILE ?= helm/values.yaml
HELM_IMAGE_REPO ?= $(DOCKER_REPO)
HELM_IMAGE_PULL_POLICY ?= Never

.PHONY: helm-install
helm-install: helm-package prepare-test-env
	@echo "Installing Helm release: $(HELM_RELEASE_NAME)"
	@echo "Ensuring namespace exists: $(HELM_NAMESPACE)"
	@$(KUBECTL) create namespace $(HELM_NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f - || \
		(echo "Note: Using existing namespace $(HELM_NAMESPACE)" && true)
	@SSH_KEY="$(TEST_SSH_PUBKEY)"; \
	if [ -z "$$SSH_KEY" ] && [ -f "$(TEST_SSH_KEY_FILE).pub" ]; then \
		SSH_KEY="$$(cat $(TEST_SSH_KEY_FILE).pub)"; \
	fi; \
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--values $(HELM_VALUES_FILE) \
		--set image.repository=$(HELM_IMAGE_REPO) \
		--set image.pullPolicy=$(HELM_IMAGE_PULL_POLICY) \
		--set ssh.publicKeys.authorizedKeys="$$SSH_KEY" \
		--wait --timeout=60s
	@echo "Helm release $(HELM_RELEASE_NAME) installed successfully"

.PHONY: helm-upgrade
helm-upgrade: helm-package prepare-test-env
	@echo "Upgrading Helm release: $(HELM_RELEASE_NAME)"
	# Increment version for upgrade test
	@SSH_KEY="$(TEST_SSH_PUBKEY)"; \
	if [ -z "$$SSH_KEY" ] && [ -f "$(TEST_SSH_KEY_FILE).pub" ]; then \
		SSH_KEY="$$(cat $(TEST_SSH_KEY_FILE).pub)"; \
	fi; \
	helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		$(if $(KUBE_CONTEXT),--kube-context=$(KUBE_CONTEXT)) \
		--values $(HELM_VALUES_FILE) \
		--set image.repository=$(HELM_IMAGE_REPO) \
		--set image.pullPolicy=$(HELM_IMAGE_PULL_POLICY) \
		--set ssh.publicKeys.authorizedKeys="$$SSH_KEY" \
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

