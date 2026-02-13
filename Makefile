# deployment-ready-ubuntu Makefile
# Usage: sudo make <target>
# Run 'make all' for full server setup, or individual targets as needed.

SHELL := /bin/bash
SCRIPTS := scripts
ARGS ?=

.PHONY: all check-env base user security docker traefik logging backups status help

help: ## Show this help
	@echo "Usage: sudo make <target> [ARGS=--dry-run]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Pass ARGS=--dry-run to preview changes without applying them."

all: check-env base user security docker traefik logging backups ## Run full server setup in order
	@echo ""
	@echo -e "\033[0;32m[OK] Full server setup complete.\033[0m"

check-env: ## Validate .env file exists and has required variables
	@bash $(SCRIPTS)/lib.sh 2>/dev/null; \
	source $(SCRIPTS)/lib.sh && \
	load_env && \
	require_vars DEPLOY_USER DEPLOY_SSH_PUBLIC_KEY ACME_EMAIL DOMAIN && \
	log_ok ".env validated — all required variables present."

base: check-env ## 01 — Base packages, timezone, locale
	@bash $(SCRIPTS)/01-base.sh $(ARGS)

user: check-env ## 02 — Create deploy user with SSH keys
	@bash $(SCRIPTS)/02-user.sh $(ARGS)

security: check-env ## 03 — SSH hardening, UFW, unattended-upgrades
	@bash $(SCRIPTS)/03-security.sh $(ARGS)

docker: check-env ## 04 — Install Docker CE + Compose
	@bash $(SCRIPTS)/04-docker.sh $(ARGS)

traefik: check-env ## 05 — Deploy Traefik reverse proxy
	@bash $(SCRIPTS)/05-traefik.sh $(ARGS)

logging: check-env ## 06 — Configure journald + Docker log driver
	@bash $(SCRIPTS)/06-logging.sh $(ARGS)

backups: check-env ## 07 — Setup backup scripts and cron
	@bash $(SCRIPTS)/07-backups.sh $(ARGS)

status: ## Show current server setup status
	@echo "=== Server Status ==="
	@echo ""
	@echo "--- System ---"
	@uname -a
	@echo ""
	@echo "--- Users ---"
	@if id deploy &>/dev/null; then echo "  deploy user: exists"; else echo "  deploy user: not found"; fi
	@echo ""
	@echo "--- Firewall (UFW) ---"
	@if command -v ufw &>/dev/null; then ufw status 2>/dev/null || echo "  UFW not active"; else echo "  UFW not installed"; fi
	@echo ""
	@echo "--- Docker ---"
	@if command -v docker &>/dev/null; then docker --version; docker compose version 2>/dev/null; else echo "  Docker not installed"; fi
	@echo ""
	@echo "--- Traefik ---"
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -q traefik; then echo "  Traefik: running"; else echo "  Traefik: not running"; fi
	@echo ""
	@echo "--- Services ---"
	@systemctl is-active --quiet sshd && echo "  sshd: active" || echo "  sshd: inactive"
	@systemctl is-active --quiet docker 2>/dev/null && echo "  docker: active" || echo "  docker: inactive"
	@systemctl is-active --quiet unattended-upgrades 2>/dev/null && echo "  unattended-upgrades: active" || echo "  unattended-upgrades: inactive"
	@echo ""
	@echo "--- Backups ---"
	@if test -f /etc/cron.d/server-backup; then echo "  Backup cron: installed"; else echo "  Backup cron: not found"; fi
