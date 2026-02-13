#!/usr/bin/env bash
# 06-logging.sh — Configure journald, Docker log driver, and logrotate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_root
load_env

section "Log Management Setup"

# ---------------------------------------------------------------------------
# journald configuration
# ---------------------------------------------------------------------------
log_info "Configuring journald..."

JOURNALD_DROPIN_DIR="/etc/systemd/journald.conf.d"
run mkdir -p "$JOURNALD_DROPIN_DIR"
run cp "${PROJECT_ROOT}/config/journald.conf.d/override.conf" "${JOURNALD_DROPIN_DIR}/override.conf"
run chmod 644 "${JOURNALD_DROPIN_DIR}/override.conf"

log_info "Restarting systemd-journald..."
run systemctl restart systemd-journald
log_ok "journald configured (500M max, 30-day retention, compression on)."

# ---------------------------------------------------------------------------
# Docker logging driver — use journald
# ---------------------------------------------------------------------------
log_info "Configuring Docker to use journald logging driver..."

DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

if [[ "$DRY_RUN" != "true" ]]; then
    # Merge with existing config if present, or create new
    if [[ -f "$DOCKER_DAEMON_JSON" ]]; then
        # Use jq to merge if available, otherwise warn and overwrite
        if is_installed jq; then
            EXISTING=$(cat "$DOCKER_DAEMON_JSON")
            echo "$EXISTING" | jq '. + {"log-driver": "journald"}' > "$DOCKER_DAEMON_JSON"
        else
            log_warn "jq not available, overwriting ${DOCKER_DAEMON_JSON}"
            cat > "$DOCKER_DAEMON_JSON" <<'JSON'
{
  "log-driver": "journald"
}
JSON
        fi
    else
        cat > "$DOCKER_DAEMON_JSON" <<'JSON'
{
  "log-driver": "journald"
}
JSON
    fi
else
    log_info "[DRY RUN] Would set Docker log-driver to journald in ${DOCKER_DAEMON_JSON}"
fi

log_info "Restarting Docker to apply logging config..."
run systemctl restart docker
log_ok "Docker logging driver set to journald."

# ---------------------------------------------------------------------------
# App log directory + logrotate
# ---------------------------------------------------------------------------
log_info "Setting up app log directory and logrotate..."

run mkdir -p /var/log/apps

if [[ "$DRY_RUN" != "true" ]]; then
    cat > /etc/logrotate.d/apps <<'LOGROTATE'
/var/log/apps/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root adm
    sharedscripts
}
LOGROTATE
else
    log_info "[DRY RUN] Would write logrotate config to /etc/logrotate.d/apps"
fi

log_ok "Log management setup complete."
log_info "View container logs with: journalctl CONTAINER_NAME=<name>"
log_info "View all Docker logs with: journalctl -u docker"
