# homelab

Self-hosted infrastructure running on Proxmox VE. Sharing this publicly so others can learn from (or improve upon) my setup.

## Architecture

```
                 ┌──────────────────────────────┐
                 │  Router (192.168.178.1)      │
                 │  DHCP, NAT, Wi-Fi            │
                 └───────────┬──────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐
   │ svr-host │        │ svr-core  │        │ svr-nas   │
   │ Proxmox  │───────►│ Services  │◄───────│ TrueNAS   │
   │ .88      │        │ .102      │  NFS   │ .101      │
   └──────────┘        └─────┬─────┘        └───────────┘
        │                    │
        │              ┌─────┴─────┐
        └─────────────►│ svr-dmz   │◄──── Cloudflare Tunnel
                       │ Public    │
                       └───────────┘
```

## Servers

### svr-host (Proxmox VE)
Bare-metal hypervisor running all VMs.

- **Hardware**: Intel i9-14900KF, 94GB ECC DDR5, RTX 4070 Super
- **Storage**: 2TB NVMe (OS), 2TB + 8TB NVMe passthrough to svr-nas
- **VMs**: svr-core, svr-nas, svr-dmz

### svr-core (Ubuntu 24.04)
Core services VM with GPU passthrough.

- **Resources**: 8 cores, 32GB RAM, RTX 4070 Super
- **Services**: vLLM, Open WebUI, Jellyfin, Immich, Prometheus, Grafana
- **DNS**: dnsmasq for `.home.arpa` domains
- **Proxy**: Caddy with internal HTTPS

### svr-nas (TrueNAS SCALE)
ZFS storage server.

- **Resources**: 8 cores, 32GB RAM
- **Storage**: ~9TB usable (2TB + 8TB NVMe)
- **Exports**: NFS for media, backups

### svr-dmz (Debian 13)
Public-facing gateway in isolated network.

- **Resources**: 2 cores, 2GB RAM
- **Services**: Caddy, Plausible Analytics
- **Access**: Cloudflare Tunnel only (no port forwarding)

## Quick Start

### svr-core

```bash
cd svr-core
cp .env.example .env
# Edit .env with your passwords

# Start monitoring stack
docker compose -f stack-compose.yml up -d

# Start vLLM (requires NVIDIA GPU)
docker compose up -d
```

### svr-dmz

```bash
cd svr-dmz
cp .env.example .env
# Edit .env - generate PLAUSIBLE_SECRET_KEY with:
# openssl rand -base64 64

docker compose up -d
```

## Internal DNS (.home.arpa)

Set your DNS to svr-core (192.168.178.102) to use these domains:

| Domain | Service |
|--------|---------|
| grafana.home.arpa | Grafana dashboards |
| prometheus.home.arpa | Prometheus metrics |
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
├── svr-core/
│   ├── docker-compose.yml      # vLLM
│   ├── stack-compose.yml       # Monitoring + management
│   ├── caddy/Caddyfile         # Internal reverse proxy
│   ├── dnsmasq/dnsmasq.conf    # .home.arpa DNS
│   └── prometheus/prometheus.yml
├── svr-dmz/
│   ├── docker-compose.yml      # Analytics + monitoring
│   ├── caddy/Caddyfile         # Public web server
│   └── prometheus/prometheus.yml
└── docs/                       # Additional documentation
```

## Related Repos

- [dotfiles](https://github.com/adolago/dotfiles) - Hyprland workstation configs
- [adolago.xyz](https://github.com/adolago/adolago.xyz) - Personal website
