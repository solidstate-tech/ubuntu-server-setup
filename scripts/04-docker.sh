#!/usr/bin/env bash
# 04-docker.sh — Install Docker CE and Docker Compose plugin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_root
load_env
require_vars DEPLOY_USER

section "Docker Installation"

USERNAME="${DEPLOY_USER}"

# ---------------------------------------------------------------------------
# Check if Docker is already installed
# ---------------------------------------------------------------------------
if is_installed docker; then
    log_info "Docker is already installed: $(docker --version)"
    log_info "Ensuring deploy user is in docker group..."
    run usermod -aG docker "$USERNAME"
    log_ok "Docker setup verified."
    exit 0
fi

# ---------------------------------------------------------------------------
# Add Docker's official GPG key and repository
# ---------------------------------------------------------------------------
log_info "Adding Docker's official GPG key..."
run install -m 0755 -d /etc/apt/keyrings

if [[ "$DRY_RUN" != "true" ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
else
    log_info "[DRY RUN] Would download Docker GPG key"
fi

log_info "Adding Docker apt repository..."
if [[ "$DRY_RUN" != "true" ]]; then
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
else
    log_info "[DRY RUN] Would add Docker apt repository"
fi

# ---------------------------------------------------------------------------
# Install Docker packages
# ---------------------------------------------------------------------------
log_info "Installing Docker CE, CLI, containerd, and Compose plugin..."
run apt-get update -qq
run apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ---------------------------------------------------------------------------
# Post-install configuration
# ---------------------------------------------------------------------------
log_info "Adding '${USERNAME}' to docker group..."
run usermod -aG docker "$USERNAME"

log_info "Enabling and starting Docker service..."
run systemctl enable --now docker

# ---------------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" != "true" ]]; then
    log_info "Verifying Docker installation..."
    docker run --rm hello-world > /dev/null 2>&1 && \
        log_ok "Docker verified successfully." || \
        log_warn "Docker installed but hello-world test failed."
    log_info "Docker version: $(docker --version)"
    log_info "Compose version: $(docker compose version)"
fi

log_ok "Docker installation complete."
log_info "User '${USERNAME}' must log out and back in for docker group to take effect."
