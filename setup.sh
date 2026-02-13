#!/usr/bin/env bash
# setup.sh — One-shot server setup for fresh Ubuntu 24.04
#
# Usage:
#   sudo ./setup.sh              # Full setup
#   sudo ./setup.sh --dry-run    # Preview only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------------------------------
# Root check
# ---------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Run this script as root: sudo ./setup.sh"
    exit 1
fi

# ---------------------------------------------------------------------------
# .env check
# ---------------------------------------------------------------------------
if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
    if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
        cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
        log_ok "Created .env from .env.example"
    else
        log_error "No .env or .env.example found."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Install make if missing
# ---------------------------------------------------------------------------
if ! command -v make &>/dev/null; then
    log_info "Installing make..."
    apt-get update -qq && apt-get install -y -qq make
fi

MAKE="make -C ${SCRIPT_DIR}"
ARGS="${1:-}"

# ---------------------------------------------------------------------------
# Phase 1: Base system + deploy user
# ---------------------------------------------------------------------------
log_info "Phase 1: Base system setup..."
$MAKE base ARGS="$ARGS"

log_info "Phase 2: Creating deploy user..."
$MAKE user ARGS="$ARGS"

# ---------------------------------------------------------------------------
# SSH safety gate
# ---------------------------------------------------------------------------
if [[ "$ARGS" != "--dry-run" ]]; then
    # shellcheck disable=SC1090
    source "${SCRIPT_DIR}/.env"

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  SSH ACCESS CHECK${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  The next step will ${RED}disable root login${NC} and ${RED}password auth${NC}."
    echo -e "  You MUST verify SSH access as '${DEPLOY_USER}' first."
    echo ""
    echo -e "  Open a ${GREEN}new terminal${NC} and run:"
    echo -e "    ${GREEN}ssh ${DEPLOY_USER}@$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    echo -e "  If that works, type ${GREEN}y${NC} below to continue."
    echo -e "  If not, type ${RED}n${NC} and fix the SSH key in .env."
    echo ""
    read -r -p "$(echo -e "${YELLOW}Have you verified SSH access? [y/N]${NC} ")" answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log_warn "Aborted. Fix SSH access, then re-run: sudo ./setup.sh"
        log_info "Steps already completed (base, user) will be skipped on re-run."
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Phase 2: Security, Docker, Traefik, Logging, Backups
# ---------------------------------------------------------------------------
log_info "Phase 3: Security hardening..."
$MAKE security ARGS="$ARGS"

log_info "Phase 4: Docker installation..."
$MAKE docker ARGS="$ARGS"

log_info "Phase 5: Traefik reverse proxy..."
$MAKE traefik ARGS="$ARGS"

log_info "Phase 6: Log management..."
$MAKE logging ARGS="$ARGS"

log_info "Phase 7: Backup setup..."
$MAKE backups ARGS="$ARGS"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Server setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Next steps:"
echo -e "    1. ${BLUE}su - ${DEPLOY_USER}${NC}"
echo -e "    2. ${BLUE}cd ~/apps${NC}"
echo -e "    3. Clone your application repo and deploy"
echo ""
$MAKE status
