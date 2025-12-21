#!/bin/bash
# Setup Proxmox vzdump backup job to NAS
# Run this on Proxmox hypervisor
#
# CUSTOMIZE: Update NAS_IP and NAS_EXPORT for your network
set -e

echo "=== Proxmox Backup Setup ==="
echo ""

# Check if running on Proxmox
if [ ! -f /etc/pve/local/pve-ssl.pem ]; then
    echo "Error: This script must be run on Proxmox VE host"
    exit 1
fi

# CUSTOMIZE: Update these for your network
NAS_IP="192.168.1.11"            # Your NAS IP
NAS_EXPORT="/mnt/pool/Backups"   # Your NFS export path
STORAGE_ID="nas-backups"

# Check if NAS is reachable
echo "Checking NAS connectivity..."
if ! ping -c 1 -W 2 "$NAS_IP" &>/dev/null; then
    echo "Error: Cannot reach NAS at $NAS_IP"
    exit 1
fi
echo "NAS is reachable"

# Check if NFS export is available
echo "Checking NFS export..."
if ! showmount -e "$NAS_IP" 2>/dev/null | grep -q "$NAS_EXPORT"; then
    echo "Warning: NFS export $NAS_EXPORT not found. Make sure it's configured on your NAS"
fi

# Add NAS storage if not exists
echo "Configuring storage..."
if pvesm status | grep -q "$STORAGE_ID"; then
    echo "Storage $STORAGE_ID already exists"
else
    echo "Adding NFS storage $STORAGE_ID..."
    pvesm add nfs "$STORAGE_ID" \
        --server "$NAS_IP" \
        --export "$NAS_EXPORT" \
        --content backup \
        --maxfiles 0 \
        --options vers=4.2
    echo "Storage added"
fi

# Create backup job
echo "Creating backup job..."
cat > /tmp/vzdump-job.json << 'EOF'
{
    "id": "homelab-daily",
    "schedule": "0 3 * * *",
    "storage": "nas-backups",
    "mailnotification": "failure",
    "mode": "snapshot",
    "compress": "zstd",
    "vmid": "101,102,103",
    "prune-backups": "keep-daily=7,keep-weekly=4,keep-monthly=3",
    "enabled": 1
}
EOF

# Check if job exists
if pvesh get /cluster/backup 2>/dev/null | grep -q "homelab-daily"; then
    echo "Backup job homelab-daily already exists"
else
    echo "Creating backup job..."
    pvesh create /cluster/backup \
        --id homelab-daily \
        --schedule "0 3 * * *" \
        --storage "$STORAGE_ID" \
        --mailnotification failure \
        --mode snapshot \
        --compress zstd \
        --vmid "101,102,103" \
        --prune-backups "keep-daily=7,keep-weekly=4,keep-monthly=3" \
        --enabled 1 || echo "Note: You may need to create this via GUI if API fails"
fi

rm -f /tmp/vzdump-job.json

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Backup schedule: Daily at 03:00"
echo "VMs backed up: 101, 102, 103 (update VMIDs as needed)"
echo "Retention: 7 daily, 4 weekly, 3 monthly"
echo "Storage: $STORAGE_ID ($NAS_IP:$NAS_EXPORT)"
echo ""
echo "Manual backup: vzdump 101 102 103 --storage $STORAGE_ID --mode snapshot --compress zstd"
echo "View jobs: pvesh get /cluster/backup"
