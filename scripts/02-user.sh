#!/usr/bin/env bash
# 02-user.sh — Create deploy user with SSH key and sudo access
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_root
load_env
require_vars DEPLOY_USER DEPLOY_SSH_PUBLIC_KEY

section "Deploy User Setup"

USERNAME="${DEPLOY_USER}"
SSH_KEY="${DEPLOY_SSH_PUBLIC_KEY}"

# ---------------------------------------------------------------------------
# Create user
# ---------------------------------------------------------------------------
if id "$USERNAME" &>/dev/null; then
    log_info "User '${USERNAME}' already exists, skipping creation."
else
    log_info "Creating user '${USERNAME}'..."
    run useradd \
        --create-home \
        --shell /bin/bash \
        --groups sudo \
        "$USERNAME"
    log_ok "User '${USERNAME}' created."
fi

# Ensure user is in sudo group (idempotent)
run usermod -aG sudo "$USERNAME"

# ---------------------------------------------------------------------------
# SSH key setup
# ---------------------------------------------------------------------------
SSH_DIR="/home/${USERNAME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

log_info "Configuring SSH keys for '${USERNAME}'..."

run mkdir -p "$SSH_DIR"

# Add key if not already present
if [[ -f "$AUTH_KEYS" ]] && grep -qF "$SSH_KEY" "$AUTH_KEYS"; then
    log_info "SSH key already present in authorized_keys."
else
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would append SSH key to ${AUTH_KEYS}"
    else
        echo "$SSH_KEY" >> "$AUTH_KEYS"
    fi
    log_ok "SSH key added."
fi

# Fix permissions
run chmod 700 "$SSH_DIR"
run chmod 600 "$AUTH_KEYS"
run chown -R "${USERNAME}:${USERNAME}" "$SSH_DIR"

# ---------------------------------------------------------------------------
# Disable password for this user (force key-only auth)
# ---------------------------------------------------------------------------
log_info "Locking password for '${USERNAME}' (key-only auth)..."
run passwd -l "$USERNAME"

# ---------------------------------------------------------------------------
# Create apps directory
# ---------------------------------------------------------------------------
APPS_DIR="/home/${USERNAME}/apps"
log_info "Creating apps directory at ${APPS_DIR}..."
run mkdir -p "$APPS_DIR"
run chown "${USERNAME}:${USERNAME}" "$APPS_DIR"
log_ok "Apps directory created."

log_ok "Deploy user '${USERNAME}' setup complete."
log_info "Clone application repos into: ${APPS_DIR}"
log_info "Remember: script 04-docker.sh will add this user to the 'docker' group."
