#!/bin/bash
# Install health check cron job on wrk-main
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_SCRIPT="$SCRIPT_DIR/health-check.sh"

# Create cron job to run every 6 hours
CRON_JOB="0 */6 * * * $HEALTH_SCRIPT >> /var/log/homelab-health.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "health-check.sh"; then
    echo "Health check cron job already exists"
else
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Health check cron job installed (runs every 6 hours)"
fi

# Create log file with correct permissions
sudo touch /var/log/homelab-health.log
sudo chown artur:artur /var/log/homelab-health.log

echo "Done! Run manually with: $HEALTH_SCRIPT"
