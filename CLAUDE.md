# CLAUDE.md

Guidelines for Claude Code (claude.ai/code) when working with this homelab infrastructure repository.

## Overview

Enterprise-grade homelab infrastructure as code repository for Proxmox VE-based self-hosted services. Uses Ansible for configuration management and Docker Compose for container orchestration.

## Architecture

Four-tier infrastructure design:

- **svr-host**: Proxmox VE hypervisor (bare metal)
- **svr-core**: Ubuntu 24.04 services VM - Docker containers for monitoring, DNS, reverse proxy, and applications (vLLM, Jellyfin, Immich)
- **svr-nas**: TrueNAS SCALE storage VM - ZFS pools with NFS exports
- **svr-dmz**: Debian public-facing VM - isolated network with Cloudflare Tunnel access

Internal DNS resolution via `.home.arpa` domain through dnsmasq on svr-core.

## Essential Operations

### Infrastructure Management (from `ansible/` directory)

```bash
# Verify host connectivity
ansible all -m ping

# Deploy complete infrastructure
ansible-playbook playbooks/site.yml

# Deploy specific components
ansible-playbook playbooks/common.yml --tags=ntp
ansible-playbook playbooks/site.yml --tags=docker
ansible-playbook playbooks/site.yml --tags=monitoring
```

### Service Management (on svr-core)

```bash
cd svr-core

# Start monitoring stack (Prometheus, Grafana, Caddy, dnsmasq)
docker compose -f stack-compose.yml up -d

# Start vLLM (requires NVIDIA GPU)
docker compose up -d
```

### Secrets Management with SOPS

```bash
# Initialize encryption (generates age key, updates .sops.yaml)
./scripts/setup-sops.sh

# Encrypt configuration files
sops --encrypt --in-place ansible/group_vars/all/vault.yml

# Edit encrypted files
sops ansible/group_vars/all/vault.yml
```

### Infrastructure Monitoring

```bash
# Execute comprehensive health check
./scripts/health-check.sh

# Install automated monitoring (runs every 6 hours)
./scripts/install-health-check-cron.sh
```

## Repository Structure

```
homelab/
├── ansible/                   # Ansible automation
│   ├── inventory/hosts.yml   # Infrastructure inventory
│   ├── playbooks/            # Deployment automation
│   └── roles/                # Reusable configuration roles
├── svr-core/                  # Core services VM
│   ├── stack-compose.yml     # Monitoring and management stack
│   └── docker-compose.yml    # Application services (vLLM)
├── svr-dmz/                   # DMZ VM configuration
├── svr-host/                  # Hypervisor scripts
└── scripts/                   # Utility and setup scripts
```

## Key Configuration Files

- **`.sops.yaml`**: SOPS age encryption rules for secrets management
- **`ansible/inventory/hosts.yml`**: Infrastructure inventory with IP addresses and variables
- **`svr-core/dnsmasq/dnsmasq.conf`**: Internal DNS entries for `.home.arpa` domains
- **`svr-core/caddy/Caddyfile`**: Reverse proxy and HTTPS termination configuration
- **`svr-core/prometheus/prometheus.yml`**: Prometheus monitoring targets and alerting rules

## Service Integration

Add new services to your infrastructure:

1. **DNS Configuration**: Add entries to `svr-core/dnsmasq/dnsmasq.conf`
2. **Reverse Proxy**: Configure routing in `svr-core/caddy/Caddyfile`
3. **Service Deployment**: Restart affected containers

```bash
docker restart dnsmasq caddy
```
