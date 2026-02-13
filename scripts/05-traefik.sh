#!/usr/bin/env bash
# 05-traefik.sh — Deploy Traefik reverse proxy with Let's Encrypt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_root
load_env
require_vars ACME_EMAIL DOMAIN

section "Traefik Reverse Proxy Setup"

TRAEFIK_DIR="/opt/traefik"
ACME_DIR="${TRAEFIK_DIR}/acme"
DYNAMIC_DIR="${TRAEFIK_DIR}/dynamic"

# ---------------------------------------------------------------------------
# Create directories
# ---------------------------------------------------------------------------
log_info "Creating Traefik directories..."
run mkdir -p "$TRAEFIK_DIR" "$ACME_DIR" "$DYNAMIC_DIR"

# ---------------------------------------------------------------------------
# Create Docker network
# ---------------------------------------------------------------------------
if docker network inspect traefik-public &>/dev/null 2>&1; then
    log_info "Docker network 'traefik-public' already exists."
else
    log_info "Creating Docker network 'traefik-public'..."
    run docker network create traefik-public
fi

# ---------------------------------------------------------------------------
# Deploy Traefik static config
# ---------------------------------------------------------------------------
log_info "Deploying Traefik configuration..."

if [[ "$DRY_RUN" != "true" ]]; then
    cat > "${TRAEFIK_DIR}/traefik.yml" <<YAML
# Traefik static configuration
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: "${ACME_EMAIL}"
      storage: /acme/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-public
  file:
    directory: /dynamic
    watch: true

log:
  level: INFO

accessLog: {}
YAML
else
    log_info "[DRY RUN] Would write traefik.yml"
fi

# ---------------------------------------------------------------------------
# ACME storage file
# ---------------------------------------------------------------------------
if [[ ! -f "${ACME_DIR}/acme.json" ]]; then
    run touch "${ACME_DIR}/acme.json"
fi
run chmod 600 "${ACME_DIR}/acme.json"

# ---------------------------------------------------------------------------
# Deploy Docker Compose file for Traefik
# ---------------------------------------------------------------------------
log_info "Deploying Traefik Docker Compose file..."

if [[ "$DRY_RUN" != "true" ]]; then
    cat > "${TRAEFIK_DIR}/docker-compose.yml" <<'YAML'
services:
  traefik:
    image: traefik:v3.3
    container_name: traefik
    restart: unless-stopped
    environment:
      - DOCKER_API_VERSION=1.44
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./acme:/acme
      - ./dynamic:/dynamic:ro
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"

networks:
  traefik-public:
    external: true
YAML
else
    log_info "[DRY RUN] Would write docker-compose.yml"
fi

# ---------------------------------------------------------------------------
# Copy dynamic config templates (if any)
# ---------------------------------------------------------------------------
if [[ -d "${PROJECT_ROOT}/config/traefik/dynamic" ]]; then
    for f in "${PROJECT_ROOT}/config/traefik/dynamic/"*; do
        [[ -f "$f" ]] || continue
        [[ "$(basename "$f")" == ".gitkeep" ]] && continue
        run cp "$f" "${DYNAMIC_DIR}/"
    done
fi

# ---------------------------------------------------------------------------
# Start Traefik
# ---------------------------------------------------------------------------
log_info "Starting Traefik..."
run docker compose -f "${TRAEFIK_DIR}/docker-compose.yml" up -d

if [[ "$DRY_RUN" != "true" ]]; then
    sleep 2
    if docker ps --format '{{.Names}}' | grep -q traefik; then
        log_ok "Traefik is running."
    else
        log_error "Traefik failed to start. Check logs: docker logs traefik"
        exit 1
    fi
fi

log_ok "Traefik setup complete."
log_info "To expose a service, add these Docker labels:"
log_info '  - "traefik.enable=true"'
log_info '  - "traefik.http.routers.<name>.rule=Host(`app.${DOMAIN}`)"'
log_info '  - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"'
