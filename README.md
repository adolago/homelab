# homelab

Self-hosted infrastructure running on Proxmox VE with enterprise-grade observability, automated backups, and Infrastructure as Code.

## Architecture

```
                 ┌──────────────────────────────┐
                 │  Router (ROUTER_IP)          │
                 │  DHCP, NAT, Wi-Fi            │
                 └───────────┬──────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐
   │ hypervisor│       │ services  │        │ storage   │
   │ Proxmox  │───────►│ Docker    │◄───────│ TrueNAS   │
   │          │        │           │  NFS   │           │
   └──────────┘        └─────┬─────┘        └───────────┘
        │                    │
        │              ┌─────┴─────┐
        └─────────────►│ dmz       │◄──── Cloudflare Tunnel
                       │ Public    │
                       └───────────┘
```

## Features

- **Infrastructure as Code**: Ansible playbooks for reproducible deployments
- **Observability Stack**: Prometheus, Grafana, Loki, Alertmanager
- **Secrets Management**: SOPS + age encryption
- **Automated Backups**: Borg (workstations) + vzdump (VMs) to NAS
- **Internal DNS**: `.home.arpa` domains via dnsmasq
- **Reverse Proxy**: Caddy with automatic internal HTTPS

## Servers

### Hypervisor (Proxmox VE)
Bare-metal hypervisor running all VMs.

- **Hardware**: High-performance CPU, 64GB+ RAM, GPU for passthrough
- **Storage**: NVMe for OS, additional drives passed through to storage VM
- **VMs**: Services (VMID 102), Storage (VMID 101), DMZ (VMID 103)

### Services VM (Ubuntu 24.04)
Core services VM with optional GPU passthrough.

- **Resources**: 4-8 cores, 16-32GB RAM, optional GPU
- **Services**: vLLM, Open WebUI, Jellyfin, Immich
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **DNS/Proxy**: dnsmasq + Caddy

### Storage VM (TrueNAS SCALE)
ZFS storage server.

- **Resources**: 4-8 cores, 16-32GB RAM (ECC recommended)
- **Storage**: Configure ZFS pools as needed
- **Exports**: NFS for media, backups

### DMZ VM (Debian)
Public-facing gateway in isolated network.

- **Resources**: 1-2 cores, 1-2GB RAM
- **Services**: Caddy, analytics
- **Access**: Cloudflare Tunnel only (no port forwarding)

## Quick Start

### Prerequisites

```bash
# Install Ansible (on control node)
paru -S ansible sops age

# Setup secrets encryption
./scripts/setup-sops.sh
```

### Deploy with Ansible

```bash
cd ansible

# Test connectivity
ansible all -m ping

# Deploy everything
ansible-playbook playbooks/site.yml

# Deploy specific role
ansible-playbook playbooks/common.yml --tags=ntp
```

### Manual Docker Start (svr-core)

```bash
cd svr-core
cp .env.example .env
# Edit .env with your passwords

# Start monitoring stack
docker compose -f stack-compose.yml up -d

# Start vLLM (requires NVIDIA GPU)
docker compose up -d
```

## Internal DNS (.home.arpa)

Set DNS to your services VM IP (e.g., `SERVICES_IP`) to use these domains:

| Domain | Service |
|--------|---------|
| grafana.home.arpa | Grafana dashboards |
| prometheus.home.arpa | Prometheus metrics |
| alertmanager.home.arpa | Alert management |
| loki.home.arpa | Log aggregation |
| portainer.home.arpa | Docker management |
| jellyfin.home.arpa | Media server |
| immich.home.arpa | Photo management |
| chat.home.arpa | Open WebUI (LLM) |
| proxmox.home.arpa | Proxmox VE |
| nas.home.arpa | TrueNAS |
| ha.home.arpa | Home Assistant |

## Structure

```
homelab/
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.yml
│   ├── playbooks/
│   │   ├── site.yml          # Full deployment
│   │   └── common.yml        # Base configuration
│   └── roles/
│       ├── common/           # NTP, SSH, packages
│       ├── docker/           # Docker installation
│       └── monitoring/       # Full observability stack
├── scripts/
│   ├── setup-sops.sh         # Initialize secrets encryption
│   ├── health-check.sh       # Infrastructure health check
│   └── install-health-check-cron.sh
├── svr-core/
│   ├── docker-compose.yml    # vLLM + applications
│   ├── stack-compose.yml     # Monitoring + management
│   ├── caddy/Caddyfile       # Reverse proxy
│   ├── dnsmasq/              # DNS configuration
│   ├── prometheus/           # Metrics + alerts
│   ├── alertmanager/         # Alert routing
│   ├── loki/                 # Log aggregation
│   └── promtail/             # Log collection
├── svr-dmz/
│   ├── docker-compose.yml
│   └── ...
├── svr-host/
│   ├── vzdump-job.conf       # Backup job config
│   └── setup-vzdump.sh       # Backup automation setup
├── docs/
│   └── dns-setup.md
└── .sops.yaml                # Secrets encryption config
```

## Monitoring

### Alerts Configured
- Host down (2m)
- High CPU/Memory (>85%)
- Disk space low (>85%) / critical (>95%)
- Container unhealthy / restarting
- ZFS pool issues
- Service-specific (Prometheus, Loki, Alertmanager)

### Health Checks
```bash
# Run manual health check
./scripts/health-check.sh

# Install cron job (every 6 hours)
./scripts/install-health-check-cron.sh
```

## Backups

| Source | Tool | Target | Schedule |
|--------|------|--------|----------|
| Workstations | Borg | storage:/mnt/pool/Backups | Daily 02:00 |
| VMs | vzdump | storage (NFS) | Daily 03:00 |

## Related Repos

- Workstation dotfiles (Hyprland configs) in separate repository

## License

MIT
