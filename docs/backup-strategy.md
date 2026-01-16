# Backup Strategy

## Overview

Three-tier backup architecture:

| Tier | Source | Method | Target |
|------|--------|--------|--------|
| Workstations | User data | Borg Backup | svr-nas |
| VMs | Proxmox VMs | vzdump | svr-nas (NFS) |
| NAS | Critical data | Cloud Sync | Backblaze B2 |

## Proxmox vzdump Setup

### Add NAS NFS Storage in Proxmox GUI

1. **Datacenter → Storage → Add → NFS**
2. Configure:
   - ID: `nas-backup`
   - Server: `192.168.178.101` (svr-nas)
   - Export: `/mnt/pool/backups`
   - Content: `VZDump backup file`
3. Click **Add**

### vzdump Job Configuration

Create `/etc/vzdump.conf` on svr-host:

```conf
# /etc/vzdump.conf
storage: nas-backup
mode: snapshot
compress: zstd
mailto: admin@example.com
mailnotification: failure
```

Schedule via **Datacenter → Backup → Add**:
- Select VMs: all or specific
- Schedule: daily at 02:00
- Retention: keep-last=7, keep-weekly=4, keep-monthly=3

## Home Assistant Backup

### Option 1: Google Drive Backup Add-on (Recommended)

1. **Settings → Add-ons → Add-on Store**
2. Search "Google Drive Backup" → Install
3. Configure OAuth credentials
4. Set schedule and retention

### Option 2: Backup to NFS

1. Mount NFS share on Home Assistant host:
   ```bash
   mount -t nfs 192.168.178.101:/mnt/pool/backups/homeassistant /backup
   ```
2. Add to `/etc/fstab` for persistence
3. Configure backup location in **Settings → System → Backups**

## TrueNAS Off-site (Backblaze B2)

### 1. Create Backblaze B2 Bucket

1. Log in to [Backblaze B2](https://www.backblaze.com/b2/)
2. **Buckets → Create a Bucket**
   - Name: `homelab-backup-<unique>`
   - Private
3. **App Keys → Add a New Application Key**
   - Name: `truenas-sync`
   - Allow access to: your bucket
   - Save `keyID` and `applicationKey`

### 2. Configure TrueNAS Cloud Sync

1. **Data Protection → Cloud Sync Tasks → Add**
2. Configure:
   - Provider: `Backblaze B2`
   - Access Key ID: `<keyID>`
   - Secret Access Key: `<applicationKey>`
   - Bucket: select your bucket
3. Set source dataset and schedule
4. Direction: `PUSH`
5. Transfer Mode: `SYNC` (or `COPY` to preserve deleted files)

## Retention Policies

| Backup Type | Daily | Weekly | Monthly | Yearly |
|-------------|-------|--------|---------|--------|
| VM (vzdump) | 7 | 4 | 3 | 1 |
| Borg (workstations) | 7 | 4 | 6 | 2 |
| B2 Cloud Sync | 30 | 12 | 12 | - |

## Recovery Procedures

### Restore VM from vzdump

```bash
# List available backups
qmrestore --list nas-backup

# Restore VM 100 from backup
qmrestore /mnt/pve/nas-backup/dump/vzdump-qemu-100-*.vma.zst 100 --storage local-lvm
```

### Restore Borg Archive

```bash
# List archives
borg list /path/to/repo

# Extract specific archive
borg extract /path/to/repo::archive-name path/to/restore
```

### Restore from B2

Use TrueNAS Cloud Sync task with direction set to `PULL`, or use `rclone`:

```bash
rclone copy b2:homelab-backup/path /mnt/pool/restored
```
