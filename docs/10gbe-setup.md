# 10GbE Network Setup

## Prerequisites

- Intel X550-T2 installed in svr-host
- Cat6a or Cat7 cabling
- 10GbE switch or direct connection

Verify card detection:

```bash
lspci | grep -i ethernet
# Should show: Intel Corporation Ethernet Controller 10G X550T
```

## Proxmox Network Configuration

### Identify 10GbE Interface

```bash
ip link show
# Look for new interface (e.g., enp4s0f0, enp4s0f1)
```

### Create vmbr1 Bridge

Edit `/etc/network/interfaces` on svr-host:

```conf
auto enp4s0f0
iface enp4s0f0 inet manual

auto vmbr1
iface vmbr1 inet static
    address 10.0.0.1/24
    bridge-ports enp4s0f0
    bridge-stp off
    bridge-fd 0
#10GbE Storage Network
```

Apply changes:

```bash
ifreload -a
# Or reboot if ifreload not available
```

## VM Configuration

### Option 1: Add Network Interface to svr-nas

1. **VM → Hardware → Add → Network Device**
2. Bridge: `vmbr1`
3. Model: `VirtIO`

Configure inside svr-nas:

```bash
# /etc/network/interfaces (or via TrueNAS GUI)
auto eth1
iface eth1 inet static
    address 10.0.0.2
    netmask 255.255.255.0
```

### Option 2: PCI Passthrough (Better Performance)

1. Enable IOMMU in BIOS
2. Add to `/etc/default/grub`:
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
   ```
3. Update grub and reboot
4. **VM → Hardware → Add → PCI Device** → Select X550 port

## Static IP Assignments

| Host | 10GbE IP |
|------|----------|
| svr-host | 10.0.0.1 |
| svr-nas | 10.0.0.2 |
| svr-core | 10.0.0.3 |

## Update NFS Exports

On svr-nas, bind NFS to 10GbE interface. In TrueNAS:

1. **Services → NFS → Configure**
2. Bind IP Addresses: `10.0.0.2`

Or update `/etc/exports` manually:

```conf
/mnt/pool/media 10.0.0.0/24(rw,sync,no_subtree_check)
/mnt/pool/backups 10.0.0.0/24(rw,sync,no_subtree_check)
```

Update mounts on clients to use 10GbE IPs:

```bash
# /etc/fstab on svr-core
10.0.0.2:/mnt/pool/media /mnt/media nfs defaults,_netdev 0 0
```

## Performance Testing

### Install iperf3

```bash
# svr-host
apt install iperf3

# svr-nas (TrueNAS has iperf3 built-in)
```

### Run Tests

Server (svr-nas):

```bash
iperf3 -s -B 10.0.0.2
```

Client (svr-host):

```bash
iperf3 -c 10.0.0.2 -t 30
# Expected: ~9.4 Gbps for 10GbE
```

### NFS Performance Test

```bash
# Write test
dd if=/dev/zero of=/mnt/media/testfile bs=1G count=10 oflag=direct

# Read test
dd if=/mnt/media/testfile of=/dev/null bs=1G iflag=direct
```

Clean up:

```bash
rm /mnt/media/testfile
```
