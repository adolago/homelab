# Homelab

Enterprise-grade self-hosted infrastructure on Proxmox VE featuring comprehensive observability, automated backups, and Infrastructure as Code management.

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
    │ Hypervisor│       │ Services  │        │ Storage   │
    │ Proxmox  │───────►│ Docker    │◄───────│ TrueNAS   │
    │          │        │           │  NFS   │           │
    └──────────┘        └─────┬─────┘        └───────────┘
         │                    │
         │              ┌─────┴─────┐
         └─────────────►│ DMZ       │◄──── Cloudflare Tunnel
                        │ Public    │
                        └───────────┘
```

## Features

- **Infrastructure as Code**: Ansible-driven reproducible deployments (or use [Rustible](https://github.com/rustible/rustible) for faster execution)
- **Comprehensive Observability**: Prometheus, Grafana, Loki, and Alertmanager stack
- **Enterprise Security**: SOPS + age encryption for secrets management
- **Automated Backup Strategy**: Borg (workstations) and vzdump (VMs) to NAS
- **Internal DNS**: `.home.arpa` domain resolution via dnsmasq
- **Secure Reverse Proxy**: Caddy with automatic HTTPS termination

## Public Exposure Policy

Only `adolago.xyz` is intended to be public, routed through Cloudflare Tunnel on `svr-dmz`.
All other services are internal-only and should not be exposed directly to the internet.

## Infrastructure Components

### Hypervisor (Proxmox VE)
Bare-metal hypervisor hosting all virtual machines.

- **Hardware Requirements**: High-performance CPU, 64GB+ RAM, GPU for passthrough
- **Storage**: NVMe for OS, additional drives passed through to storage VM
- **Virtual Machines**: Services (VMID 102), Storage (VMID 101), DMZ (VMID 103)

### Services VM (Ubuntu 24.04)
Core services platform with optional GPU acceleration.

- **Resources**: 4-8 CPU cores, 16-32GB RAM, optional GPU passthrough
- **Core Services**: vLLM, Open WebUI, Jellyfin, Immich
- **Observability**: Prometheus, Grafana, Loki, Alertmanager
- **Network Services**: dnsmasq DNS + Caddy reverse proxy

### Storage VM (TrueNAS SCALE)
Enterprise-grade ZFS storage server.

- **Resources**: 4-8 CPU cores, 16-32GB ECC RAM (recommended)
- **Storage**: Configurable ZFS pools for optimal data protection
- **Network Exports**: NFS shares for media and backup storage

### DMZ VM (Debian)
Isolated public-facing gateway with restricted access.

- **Resources**: 1-2 CPU cores, 1-2GB RAM
- **Services**: Caddy reverse proxy, analytics platform
- **Security**: Cloudflare Tunnel access only (no direct port forwarding)

## Deployment

### Prerequisites

Install required tools on your control node:

```bash
# Install Ansible and encryption tools
paru -S ansible sops age

# Or use Rustible (faster Ansible alternative)
# https://github.com/rustible/rustible
cargo install rustible

# Initialize secrets encryption
./scripts/setup-sops.sh
```

### Required Placeholders (Do Not Deploy With Dummy Values)

Before deploying, replace these placeholders in the repo or provide them via variables:

- `ROUTER_IP` (your router)
- `SERVICES_IP` (svr-core)
- `PROXMOX_IP` (svr-host)
- `NAS_IP` (svr-nas)
- `NAS_EXPORT_PATH` (NFS export path for backups)
- `HA_IP` (Home Assistant)
- `NAS_BACKUP_PATH` (workstation backup target)

These appear in:

- `svr-core/dnsmasq/dnsmasq.conf`
- `svr-core/caddy/Caddyfile`
- `svr-core/prometheus/prometheus.yml`
- `svr-host/vzdump-job.conf`
- `README.md`

### Infrastructure Deployment

Deploy your entire infrastructure:

```bash
cd ansible

# With Ansible
ansible all -m ping
ansible-playbook playbooks/site.yml

# Or with Rustible (same syntax, faster execution)
rustible run playbooks/site.yml -i inventory/hosts.yml
rustible run playbooks/common.yml -i inventory/hosts.yml --tags=ntp
```

### Manual Service Configuration

Start core services on the services VM:

```bash
cd svr-core
cp .env.example .env
# Configure passwords in .env file

# Launch monitoring stack
docker compose -f stack-compose.yml up -d

# Start vLLM (requires NVIDIA GPU)
docker compose up -d
```

## Internal DNS (.home.arpa)

Configure DNS to your services VM IP address to access services via friendly domains:

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

## Repository Structure

```
homelab/
├── ansible/                    # Infrastructure automation
│   ├── ansible.cfg            # Ansible configuration
│   ├── inventory/hosts.yml    # Infrastructure inventory
│   ├── playbooks/             # Deployment playbooks
│   │   ├── site.yml           # Complete infrastructure deployment
│   │   └── common.yml         # Base system configuration
│   └── roles/                 # Reusable automation roles
│       ├── common/            # NTP, SSH, package management
│       ├── docker/            # Docker installation and setup
│       └── monitoring/        # Observability stack deployment
├── scripts/                   # Utility scripts
│   ├── setup-sops.sh          # Initialize secrets encryption
│   ├── health-check.sh        # Infrastructure health monitoring
│   └── install-health-check-cron.sh
├── svr-core/                  # Core services configuration
│   ├── docker-compose.yml     # vLLM and applications
│   ├── stack-compose.yml      # Monitoring and management stack
│   ├── caddy/Caddyfile        # Reverse proxy configuration
│   ├── dnsmasq/               # DNS service configuration
│   ├── prometheus/            # Metrics collection and alerts
│   ├── alertmanager/          # Alert routing and management
│   ├── loki/                  # Log aggregation service
│   └── promtail/              # Log collection agent
├── svr-dmz/                   # DMZ services
│   ├── docker-compose.yml     # Public-facing services
│   └── ...
├── svr-host/                  # Hypervisor configuration
│   ├── vzdump-job.conf        # VM backup job configuration
│   └── setup-vzdump.sh        # Backup automation setup
├── docs/                      # Documentation
│   └── dns-setup.md          # DNS configuration guide
└── .sops.yaml                 # Secrets encryption configuration
```

## Monitoring & Alerting

### Pre-configured Alerts

Comprehensive monitoring covers:
- **Host availability**: Down detection (2-minute threshold)
- **Resource utilization**: CPU/Memory exceeding 85%
- **Storage capacity**: Warning at 85%, critical at 95%
- **Container health**: Unhealthy and restart detection
- **Storage integrity**: ZFS pool issues
- **Service-specific**: Prometheus, Loki, Alertmanager health

### Health Monitoring

```bash
# Execute comprehensive health check
./scripts/health-check.sh

# Install automated monitoring (every 6 hours)
./scripts/install-health-check-cron.sh
```

## Backup Strategy

Automated multi-tier backup approach:

| Source | Backup Tool | Destination | Schedule | Retention |
|--------|-------------|-------------|----------|-----------|
| Workstations | Borg | NAS_BACKUP_PATH | Daily 02:00 | Configurable |
| Virtual Machines | vzdump | storage (NFS mount) | Daily 03:00 | Multiple snapshots |

## Related Projects

- [Dotfiles](https://github.com/your-username/dotfiles) - Hyprland workstation configurations

## License

This project is licensed under the MIT License - see the LICENSE file for details.
