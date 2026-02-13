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
