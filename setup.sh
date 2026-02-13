#!/usr/bin/env bash
# setup.sh — Bootstrap script for fresh Ubuntu servers
# Installs make (if missing), then runs the full setup via Makefile.
#
# Usage:
#   sudo ./setup.sh              # Full setup
#   sudo ./setup.sh --dry-run    # Preview only
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: run this script as root (sudo ./setup.sh)"
    exit 1
fi

if ! command -v make &>/dev/null; then
    echo "[INFO] Installing make..."
    apt-get update -qq && apt-get install -y -qq make
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec make -C "$SCRIPT_DIR" all ARGS="${1:-}"
