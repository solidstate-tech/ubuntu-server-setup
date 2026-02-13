#!/usr/bin/env bash
# lib.sh — Shared helpers for all setup scripts
# Source this file at the top of every script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib.sh"

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Dry-run support
# ---------------------------------------------------------------------------
# Scripts check DRY_RUN to decide whether to actually execute commands.
# Pass --dry-run as the first argument to any script to enable.
DRY_RUN="${DRY_RUN:-false}"
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
        break
    fi
done
export DRY_RUN

# Run a command, or just print it if DRY_RUN is true.
run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] $*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------
require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Environment loading
# ---------------------------------------------------------------------------
# Locate the project root (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_env() {
    local env_file="${PROJECT_ROOT}/.env"
    if [[ ! -f "$env_file" ]]; then
        log_error ".env file not found at ${env_file}"
        log_error "Copy .env.example to .env and fill in the required values."
        exit 1
    fi
    # shellcheck disable=SC1090
    source "$env_file"
}

# Verify that required environment variables are set and non-empty.
# Usage: require_vars DEPLOY_USER ACME_EMAIL DOMAIN
require_vars() {
    local missing=()
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required .env variables: ${missing[*]}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

# Check if an apt package is installed.
is_pkg_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

# Check if a binary exists in PATH.
is_installed() {
    command -v "$1" &>/dev/null
}

# Interactive yes/no confirmation. Defaults to No.
# Usage: confirm_action "Restart sshd?" && systemctl restart sshd
confirm_action() {
    local prompt="${1:-Continue?}"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would prompt: ${prompt} [y/N]"
        return 0
    fi
    read -r -p "$(echo -e "${YELLOW}${prompt} [y/N]${NC} ")" answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Print a section header for visual separation in output.
section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}
