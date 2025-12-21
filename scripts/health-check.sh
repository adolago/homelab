#!/bin/bash
# Homelab Health Check Script
# Run periodically via cron to verify infrastructure health
# Exit codes: 0 = healthy, 1 = warning, 2 = critical
#
# CUSTOMIZE: Update IPs in HOSTS and SERVICES arrays

set -o pipefail

# Configuration - Update these IPs for your network
HOSTS=(
    "hypervisor:192.168.1.2"     # Your Proxmox host IP
    "services:192.168.1.10"      # Your services VM IP
    "storage:192.168.1.11"       # Your NAS IP
)

SERVICES=(
    "prometheus:http://192.168.1.10:9090/-/healthy"
    "grafana:http://192.168.1.10:3001/api/health"
    "jellyfin:http://192.168.1.10:8096/health"
    "portainer:http://192.168.1.10:9000/api/status"
)

DISK_WARNING_THRESHOLD=85
DISK_CRITICAL_THRESHOLD=95
LOG_FILE="/var/log/homelab-health.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# State tracking
WARNINGS=0
CRITICALS=0
RESULTS=()

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true
    echo -e "$1"
}

check_host() {
    local name=$1
    local ip=$2

    if ping -c 1 -W 2 "$ip" &>/dev/null; then
        RESULTS+=("${GREEN}✓${NC} Host $name ($ip) is reachable")
        return 0
    else
        RESULTS+=("${RED}✗${NC} Host $name ($ip) is DOWN")
        ((CRITICALS++))
        return 1
    fi
}

check_service() {
    local name=$1
    local url=$2

    if curl -sf --connect-timeout 5 --max-time 10 "$url" &>/dev/null; then
        RESULTS+=("${GREEN}✓${NC} Service $name is healthy")
        return 0
    else
        RESULTS+=("${RED}✗${NC} Service $name is DOWN ($url)")
        ((WARNINGS++))
        return 1
    fi
}

check_ssh() {
    local name=$1
    local ip=$2

    if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$ip" "echo ok" &>/dev/null; then
        RESULTS+=("${GREEN}✓${NC} SSH to $name working")
        return 0
    else
        RESULTS+=("${YELLOW}!${NC} SSH to $name failed (may be expected)")
        return 1
    fi
}

check_disk_space() {
    local host=$1
    local ip=$2

    # Get disk usage via SSH
    local disk_info
    if disk_info=$(timeout 10 ssh -o ConnectTimeout=3 -o BatchMode=yes "$ip" \
        "df -h --output=pcent,target | grep -E '/$|/mnt' | head -5" 2>/dev/null); then

        while IFS= read -r line; do
            local usage=$(echo "$line" | awk '{print $1}' | tr -d '%')
            local mount=$(echo "$line" | awk '{print $2}')

            if [ -n "$usage" ] && [ "$usage" -gt "$DISK_CRITICAL_THRESHOLD" ]; then
                RESULTS+=("${RED}✗${NC} $host: $mount is ${usage}% full (CRITICAL)")
                ((CRITICALS++))
            elif [ -n "$usage" ] && [ "$usage" -gt "$DISK_WARNING_THRESHOLD" ]; then
                RESULTS+=("${YELLOW}!${NC} $host: $mount is ${usage}% full (WARNING)")
                ((WARNINGS++))
            fi
        done <<< "$disk_info"
    fi
}

check_docker_containers() {
    local host=$1
    local ip=$2

    local unhealthy
    if unhealthy=$(timeout 10 ssh -o ConnectTimeout=3 -o BatchMode=yes "$ip" \
        "docker ps --filter 'health=unhealthy' --format '{{.Names}}'" 2>/dev/null); then

        if [ -n "$unhealthy" ]; then
            while IFS= read -r container; do
                RESULTS+=("${RED}✗${NC} $host: Container $container is unhealthy")
                ((WARNINGS++))
            done <<< "$unhealthy"
        fi
    fi

    # Check for restarting containers
    local restarting
    if restarting=$(timeout 10 ssh -o ConnectTimeout=3 -o BatchMode=yes "$ip" \
        "docker ps --filter 'status=restarting' --format '{{.Names}}'" 2>/dev/null); then

        if [ -n "$restarting" ]; then
            while IFS= read -r container; do
                RESULTS+=("${RED}✗${NC} $host: Container $container is restarting")
                ((CRITICALS++))
            done <<< "$restarting"
        fi
    fi
}

check_zfs_health() {
    local host=$1
    local ip=$2

    local zpool_status
    if zpool_status=$(timeout 10 ssh -o ConnectTimeout=3 -o BatchMode=yes "$ip" \
        "zpool status -x 2>/dev/null" 2>/dev/null); then

        if [[ "$zpool_status" != *"all pools are healthy"* ]]; then
            RESULTS+=("${RED}✗${NC} $host: ZFS pool issues detected")
            ((CRITICALS++))
        else
            RESULTS+=("${GREEN}✓${NC} $host: ZFS pools healthy")
        fi
    fi
}

check_backup_age() {
    # Check if last backup is recent (within 48 hours)
    # CUSTOMIZE: Update backup directory path
    local backup_dir="/mnt/nas/Backups/workstation"

    if [ -d "$backup_dir" ]; then
        local last_backup
        last_backup=$(find "$backup_dir" -maxdepth 1 -type d -name "*backup*" -mtime -2 | head -1)

        if [ -z "$last_backup" ]; then
            RESULTS+=("${YELLOW}!${NC} No recent backup found (>48h)")
            ((WARNINGS++))
        else
            RESULTS+=("${GREEN}✓${NC} Recent backup exists")
        fi
    fi
}

# Main execution
main() {
    log "=== Homelab Health Check - $(date) ==="
    echo ""

    # Check hosts
    echo "Checking hosts..."
    for host_entry in "${HOSTS[@]}"; do
        IFS=':' read -r name ip <<< "$host_entry"
        check_host "$name" "$ip"
    done
    echo ""

    # Check services
    echo "Checking services..."
    for service_entry in "${SERVICES[@]}"; do
        IFS=':' read -r name url <<< "$service_entry"
        # Reconstruct URL (split removed the http:)
        url="http:${url#http}"
        check_service "$name" "$url"
    done
    echo ""

    # Check SSH connectivity
    echo "Checking SSH..."
    for host_entry in "${HOSTS[@]}"; do
        IFS=':' read -r name ip <<< "$host_entry"
        check_ssh "$name" "$ip"
    done
    echo ""

    # Check disk space
    echo "Checking disk space..."
    for host_entry in "${HOSTS[@]}"; do
        IFS=':' read -r name ip <<< "$host_entry"
        check_disk_space "$name" "$ip"
    done
    echo ""

    # Check Docker containers on services VM
    echo "Checking Docker containers..."
    check_docker_containers "services" "192.168.1.10"
    echo ""

    # Check ZFS on storage
    echo "Checking ZFS..."
    check_zfs_health "storage" "192.168.1.11"
    echo ""

    # Check backups
    echo "Checking backups..."
    check_backup_age
    echo ""

    # Print results
    echo "=== Results ==="
    for result in "${RESULTS[@]}"; do
        echo -e "$result"
    done
    echo ""

    # Summary
    if [ $CRITICALS -gt 0 ]; then
        log "${RED}CRITICAL: $CRITICALS critical issues found${NC}"
        exit 2
    elif [ $WARNINGS -gt 0 ]; then
        log "${YELLOW}WARNING: $WARNINGS warnings found${NC}"
        exit 1
    else
        log "${GREEN}OK: All checks passed${NC}"
        exit 0
    fi
}

main "$@"
