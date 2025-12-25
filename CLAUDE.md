# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Homelab infrastructure as code repository for Proxmox VE-based self-hosted services. Uses Ansible for configuration management and Docker Compose for container orchestration.

## Architecture

Four-tier infrastructure:
- **svr-host**: Proxmox VE hypervisor (bare metal)
- **svr-core**: Ubuntu 24.04 services VM - runs Docker containers for monitoring, DNS, reverse proxy, and applications (vLLM, Jellyfin, Immich)
- **svr-nas**: TrueNAS SCALE storage VM - ZFS pools, NFS exports
- **svr-dmz**: Debian public-facing VM - isolated network, Cloudflare Tunnel access only

Internal DNS uses `.home.arpa` domain via dnsmasq on svr-core.

## Common Commands

### Ansible (from `ansible/` directory)

```bash
# Test connectivity
ansible all -m ping

# Full deployment
ansible-playbook playbooks/site.yml

# Deploy specific role
ansible-playbook playbooks/common.yml --tags=ntp
ansible-playbook playbooks/site.yml --tags=docker
ansible-playbook playbooks/site.yml --tags=monitoring
```

### Docker Compose (on svr-core)

```bash
cd svr-core

# Start monitoring stack (Prometheus, Grafana, Caddy, dnsmasq, etc.)
docker compose -f stack-compose.yml up -d

# Start vLLM (requires NVIDIA GPU)
docker compose up -d
```

### Secrets Management

```bash
# Initial setup (generates age key, updates .sops.yaml)
./scripts/setup-sops.sh

# Encrypt a file
sops --encrypt --in-place ansible/group_vars/all/vault.yml

# Edit encrypted file
sops ansible/group_vars/all/vault.yml
```

### Health Checks

```bash
./scripts/health-check.sh
./scripts/install-health-check-cron.sh  # Install 6-hour cron job
```

## Repository Structure

- `ansible/` - Ansible configuration with inventory, playbooks, and roles (common, docker, monitoring)
- `svr-core/` - Docker Compose files for services VM: `stack-compose.yml` (monitoring/management stack), `docker-compose.yml` (vLLM)
- `svr-dmz/` - Docker Compose for DMZ VM (Caddy, Plausible analytics)
- `svr-host/` - Proxmox host scripts (vzdump backup automation)
- `scripts/` - Utility scripts for SOPS setup and health checks

## Key Configuration Files

- `.sops.yaml` - SOPS age encryption rules for secrets
- `ansible/inventory/hosts.yml` - Host inventory with IP addresses and variables
- `svr-core/dnsmasq/dnsmasq.conf` - DNS entries for `.home.arpa` domains
- `svr-core/caddy/Caddyfile` - Reverse proxy configuration
- `svr-core/prometheus/prometheus.yml` - Prometheus scrape targets and alerting rules

## Adding New Services

1. Add DNS entry to `svr-core/dnsmasq/dnsmasq.conf`
2. Add reverse proxy entry to `svr-core/caddy/Caddyfile`
3. Restart containers: `docker restart dnsmasq caddy`
