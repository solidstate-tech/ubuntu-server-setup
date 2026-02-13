# deployment-ready-ubuntu

Makefile-driven bash scripts to take a fresh Ubuntu 24.04 LTS server from zero to production-ready. Installs Docker, deploys Traefik with automatic Let's Encrypt TLS, hardens SSH and firewall, configures logging, and sets up automated backups.

## Prerequisites

- Fresh Ubuntu 24.04 LTS server
- Root or sudo access
- SSH access to the server

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/solidstate-tech/deployment-ready-ubuntu.git
cd deployment-ready-ubuntu

# 2. Configure
cp .env.example .env
# Edit .env with your values (domain, SSH key, email, etc.)

# 3. Run everything
sudo make all

# Or preview first without making changes
sudo make all ARGS=--dry-run
```

## Makefile Targets

| Target | Script | Description |
|--------|--------|-------------|
| `make all` | All | Run full server setup in order |
| `make base` | `01-base.sh` | System updates, essential packages, timezone, locale |
| `make user` | `02-user.sh` | Create deploy user with SSH keys and sudo |
| `make security` | `03-security.sh` | SSH hardening, UFW firewall, unattended-upgrades |
| `make docker` | `04-docker.sh` | Install Docker CE + Compose plugin |
| `make traefik` | `05-traefik.sh` | Deploy Traefik reverse proxy with Let's Encrypt |
| `make logging` | `06-logging.sh` | Configure journald, Docker log driver, logrotate |
| `make backups` | `07-backups.sh` | Setup daily backup scripts and cron |
| `make check-env` | — | Validate `.env` has all required variables |
| `make status` | — | Show what's installed and running |
| `make help` | — | List all available targets |

Run any target individually: `sudo make docker`

## Configuration

Copy `.env.example` to `.env` and set these values:

### Required

| Variable | Description |
|----------|-------------|
| `DEPLOY_USER` | Name of the deploy user to create (default: `deploy`) |
| `DEPLOY_SSH_PUBLIC_KEY` | Full SSH public key string for the deploy user |
| `ACME_EMAIL` | Email for Let's Encrypt certificate notifications |
| `DOMAIN` | Primary domain for the server |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `TIMEZONE` | `UTC` | Server timezone |
| `DISABLE_SNAPD` | `false` | Remove snapd if `true` |
| `BACKUP_RETENTION_DAYS` | `7` | Days to keep local backups |
| `BACKUP_CRON_TIME` | `0 3 * * *` | Cron schedule for backups |
| `NOTIFICATION_EMAIL` | — | Email for unattended-upgrade notifications |

## Dry Run

Every script supports `--dry-run` to preview actions without making changes:

```bash
sudo make all ARGS=--dry-run
sudo make security ARGS=--dry-run
```

## Deploying a Service Behind Traefik

Once Traefik is running, add Docker labels to any container to expose it:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`app.example.com`)"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"

networks:
  traefik-public:
    external: true
```

## Backups

Backups run daily via cron and include:
- System configs (`/etc/ssh`, `/etc/ufw`, `/etc/docker`)
- Traefik config and ACME certificates
- All Docker volumes

Backups are stored in `/opt/backups/data/` as timestamped tarballs. Old backups are automatically pruned based on `BACKUP_RETENTION_DAYS`.

Run manually: `sudo /opt/backups/run-backup.sh`

To send backups offsite, edit `/opt/backups/run-backup.sh` and uncomment the rclone or rsync line at the bottom.

## Project Structure

```
├── Makefile                        # Orchestrates all scripts
├── .env.example                    # Configuration template
├── scripts/
│   ├── lib.sh                      # Shared helpers (logging, env, guards)
│   ├── 01-base.sh                  # Base system setup
│   ├── 02-user.sh                  # Deploy user creation
│   ├── 03-security.sh              # SSH + UFW + unattended-upgrades
│   ├── 04-docker.sh                # Docker CE installation
│   ├── 05-traefik.sh               # Traefik deployment
│   ├── 06-logging.sh               # journald + Docker logging
│   └── 07-backups.sh               # Backup scripts + cron
├── config/
│   ├── traefik/
│   │   ├── traefik.yml             # Reference Traefik config
│   │   └── dynamic/                # Dynamic Traefik config files
│   ├── sshd_config.d/
│   │   └── hardened.conf           # SSH hardening drop-in
│   └── journald.conf.d/
│       └── override.conf           # journald tuning
└── README.md
```

## Security Notes

- Root login is disabled over SSH
- Password authentication is disabled (key-only)
- UFW allows only SSH (22), HTTP (80), and HTTPS (443)
- Automatic security updates via unattended-upgrades
- Docker socket is mounted read-only in Traefik
- All scripts are idempotent and safe to re-run
