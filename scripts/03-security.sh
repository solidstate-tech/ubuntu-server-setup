#!/usr/bin/env bash
# 03-security.sh — SSH hardening, UFW firewall, unattended-upgrades
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_root
load_env

NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"

section "Security Hardening"

# ---------------------------------------------------------------------------
# Pre-flight: verify deploy user can SSH in before we lock down
# ---------------------------------------------------------------------------
require_vars DEPLOY_USER

USERNAME="${DEPLOY_USER}"
USER_HOME="/home/${USERNAME}"
AUTH_KEYS="${USER_HOME}/.ssh/authorized_keys"

# Check 1: deploy user exists
if ! id "$USERNAME" &>/dev/null; then
    log_error "Deploy user '${USERNAME}' does not exist."
    log_error "Run 'make user' first before applying security hardening."
    exit 1
fi

# Check 2: authorized_keys exists and has at least one key
if [[ ! -f "$AUTH_KEYS" ]] || [[ ! -s "$AUTH_KEYS" ]]; then
    log_error "No SSH keys found in ${AUTH_KEYS}"
    log_error "The deploy user has no way to log in. Run 'make user' first."
    exit 1
fi

# Check 3: user is in sudo group
if ! id -nG "$USERNAME" | grep -qw sudo; then
    log_error "Deploy user '${USERNAME}' is not in the sudo group."
    log_error "Without sudo, the deploy user cannot administer the server."
    exit 1
fi

KEY_COUNT=$(grep -c '^ssh-' "$AUTH_KEYS" 2>/dev/null || echo "0")
log_ok "Pre-flight passed: user '${USERNAME}' exists, ${KEY_COUNT} SSH key(s) found, sudo access confirmed."

log_info "Proceeding with SSH hardening (root login + password auth will be disabled)."

# ---------------------------------------------------------------------------
# SSH hardening via drop-in config
# ---------------------------------------------------------------------------
log_info "Deploying SSH hardening config..."

SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"
run mkdir -p "$SSHD_DROPIN_DIR"
run cp "${PROJECT_ROOT}/config/sshd_config.d/hardened.conf" "${SSHD_DROPIN_DIR}/hardened.conf"
run chmod 644 "${SSHD_DROPIN_DIR}/hardened.conf"

log_info "Restarting sshd..."
run systemctl restart sshd
log_ok "SSH hardened."

# ---------------------------------------------------------------------------
# UFW firewall
# ---------------------------------------------------------------------------
log_info "Configuring UFW firewall..."

if ! is_installed ufw; then
    run apt-get install -y -qq ufw
fi

run ufw default deny incoming
run ufw default allow outgoing
run ufw allow 22/tcp comment 'SSH'
run ufw allow 80/tcp comment 'HTTP'
run ufw allow 443/tcp comment 'HTTPS'

# Enable UFW non-interactively
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would enable UFW"
else
    echo "y" | ufw enable
fi

log_ok "UFW enabled with rules: SSH(22), HTTP(80), HTTPS(443)."

# ---------------------------------------------------------------------------
# Unattended upgrades
# ---------------------------------------------------------------------------
log_info "Configuring unattended-upgrades..."

run apt-get install -y -qq unattended-upgrades apt-listchanges

# Enable unattended-upgrades with security updates
if [[ "$DRY_RUN" != "true" ]]; then
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APTCONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APTCONF

    cat > /etc/apt/apt.conf.d/50unattended-upgrades <<APTCONF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
APTCONF

    # Optional email notifications
    if [[ -n "$NOTIFICATION_EMAIL" ]]; then
        cat >> /etc/apt/apt.conf.d/50unattended-upgrades <<APTCONF
Unattended-Upgrade::Mail "${NOTIFICATION_EMAIL}";
Unattended-Upgrade::MailReport "on-change";
APTCONF
    fi
else
    log_info "[DRY RUN] Would write unattended-upgrades config"
fi

run systemctl enable --now unattended-upgrades
log_ok "Unattended-upgrades configured."

log_ok "Security hardening complete."
