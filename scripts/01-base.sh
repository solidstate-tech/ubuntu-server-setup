#!/usr/bin/env bash
# 01-base.sh — Base system setup: updates, essential packages, timezone, locale
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_root
load_env

TIMEZONE="${TIMEZONE:-UTC}"
DISABLE_SNAPD="${DISABLE_SNAPD:-false}"

section "Base System Setup"

# ---------------------------------------------------------------------------
# System updates
# ---------------------------------------------------------------------------
log_info "Updating package lists and upgrading installed packages..."
export DEBIAN_FRONTEND=noninteractive
run apt-get update -qq
run apt-get -o Dpkg::Options::="--force-confold" upgrade -y -qq

# ---------------------------------------------------------------------------
# Essential packages
# ---------------------------------------------------------------------------
PACKAGES=(
    make
    curl
    wget
    git
    jq
    htop
    vim
    tmux
    unzip
    locales
    ca-certificates
    gnupg
    software-properties-common
    apt-transport-https
    lsb-release
)

log_info "Installing essential packages..."
run apt-get install -y -qq "${PACKAGES[@]}"
log_ok "Essential packages installed."

# ---------------------------------------------------------------------------
# Timezone
# ---------------------------------------------------------------------------
log_info "Setting timezone to ${TIMEZONE}..."
run timedatectl set-timezone "$TIMEZONE"
log_ok "Timezone set to ${TIMEZONE}."

# ---------------------------------------------------------------------------
# Locale
# ---------------------------------------------------------------------------
log_info "Configuring locale to en_US.UTF-8..."
run locale-gen en_US.UTF-8
run update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
log_ok "Locale configured."

# ---------------------------------------------------------------------------
# Optional: disable snapd
# ---------------------------------------------------------------------------
if [[ "$DISABLE_SNAPD" == "true" ]]; then
    if is_pkg_installed snapd; then
        log_info "Disabling and removing snapd..."
        run systemctl disable --now snapd.socket snapd.service 2>/dev/null || true
        run apt-get purge -y -qq snapd
        run rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
        log_ok "snapd removed."
    else
        log_info "snapd is not installed, skipping."
    fi
fi

log_ok "Base system setup complete."
