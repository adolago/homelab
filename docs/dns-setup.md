# DNS Configuration Guide

## Overview

The homelab uses dnsmasq on the services VM as the central DNS server for `.home.arpa` domains.

## Architecture

```
Internet ─► Router (ROUTER_IP) ─► dnsmasq (SERVICES_IP)
                    │                         │
                    ▼                         ▼
              DHCP for LAN            DNS for .home.arpa
              External DNS            Forwards external to Router
```

## Client Configuration

### Option 1: Per-Client DNS (Current)
Set DNS to your services VM IP on each client manually.

### Option 2: Router DNS Forwarding (Recommended)
Configure your router to use the services VM as DNS for `.home.arpa` domain.

### Option 3: Full DHCP Migration (Advanced)
Disable router DHCP, enable dnsmasq DHCP on services VM.

## Available Domains

| Domain | Service | Target |
|--------|---------|--------|
| proxmox.home.arpa | Proxmox VE | Hypervisor IP |
| grafana.home.arpa | Grafana | Services VM |
| prometheus.home.arpa | Prometheus | Services VM |
| alertmanager.home.arpa | Alertmanager | Services VM |
| portainer.home.arpa | Portainer | Services VM |
| jellyfin.home.arpa | Jellyfin | Services VM |
| immich.home.arpa | Immich | Services VM |
| chat.home.arpa | Open WebUI | Services VM |
| nas.home.arpa | TrueNAS | Storage VM |
| ha.home.arpa | Home Assistant | HA device |
| dns.home.arpa | dnsmasq Admin | Services VM |

## Testing

```bash
# Test DNS resolution (replace with your services VM IP)
dig @SERVICES_IP grafana.home.arpa

# Test from any client (if DNS configured)
curl -I https://grafana.home.arpa
```

## Configuration Files

- dnsmasq: `services-vm:~/docker/dnsmasq/dnsmasq.conf`
- Caddy: `services-vm:~/docker/caddy/Caddyfile`

## Adding New Services

1. Add DNS entry to `dnsmasq.conf`:
   ```
   address=/newservice.home.arpa/SERVICES_IP
   ```

2. Add Caddy reverse proxy:
   ```
   newservice.home.arpa {
       reverse_proxy localhost:PORT
   }
   ```

3. Restart containers:
   ```bash
   docker restart dnsmasq caddy
   ```
