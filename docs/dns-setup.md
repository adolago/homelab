# DNS Configuration Guide

## Overview

Enterprise-grade DNS infrastructure using dnsmasq on the services VM as the authoritative DNS server for internal `.home.arpa` domains with comprehensive service discovery.

## Architecture

```
Internet ─► Router (ROUTER_IP) ─► dnsmasq (SERVICES_IP)
                     │                         │
                     ▼                         ▼
               DHCP for LAN            DNS for .home.arpa
               External DNS            Forwards external to Router
```

**Traffic Flow**: External queries route through router → dnsmasq → external DNS. Internal `.home.arpa` domains resolve directly via dnsmasq.

## Client Configuration Options

### Option 1: Per-Client DNS Configuration (Manual)
Set DNS server to services VM IP address on each client device individually.

### Option 2: Router DNS Forwarding (Recommended)
Configure router to forward `.home.arpa` domain queries to services VM DNS server.

### Option 3: Complete DHCP Migration (Advanced)
Disable router DHCP service and enable dnsmasq DHCP on services VM for unified network management.

## Service Discovery Domains

| Domain | Service | Target |
|--------|---------|--------|
| proxmox.home.arpa | Proxmox VE | Hypervisor management interface |
| grafana.home.arpa | Grafana dashboards | Services VM |
| prometheus.home.arpa | Prometheus metrics | Services VM |
| alertmanager.home.arpa | Alert management | Services VM |
| portainer.home.arpa | Docker management | Services VM |
| jellyfin.home.arpa | Media server | Services VM |
| immich.home.arpa | Photo management | Services VM |
| chat.home.arpa | Open WebUI (LLM) | Services VM |
| nas.home.arpa | TrueNAS storage | Storage VM |
| ha.home.arpa | Home Assistant | Home automation device |
| dns.home.arpa | DNS administration | Services VM |

## Validation and Testing

Verify DNS functionality:

```bash
# Test DNS resolution (replace SERVICES_IP with your services VM IP)
dig @SERVICES_IP grafana.home.arpa

# Verify service accessibility (requires DNS configuration)
curl -I https://grafana.home.arpa
```

## Configuration Management

Primary configuration files:

- **DNS Service**: `services-vm:~/docker/dnsmasq/dnsmasq.conf`
- **Reverse Proxy**: `services-vm:~/docker/caddy/Caddyfile`

## Service Integration

Add new services to your infrastructure:

### 1. DNS Configuration
Add DNS entries to `dnsmasq.conf`:
```
address=/newservice.home.arpa/SERVICES_IP
```

### 2. Reverse Proxy Setup
Configure Caddy routing in `Caddyfile`:
```
newservice.home.arpa {
    reverse_proxy localhost:PORT
}
```

### 3. Service Activation
Restart affected containers:
```bash
docker restart dnsmasq caddy
```
