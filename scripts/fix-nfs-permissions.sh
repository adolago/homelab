#!/bin/bash
# Fix NFS permissions for Music directory on svr-nas
#
# TrueNAS ACL Considerations:
# - TrueNAS SCALE uses NFSv4 ACLs by default on datasets
# - If dataset has "Passthrough" ACL mode, UNIX permissions work directly
# - If using "Restricted" mode, modify ACLs via TrueNAS GUI instead
# - Check dataset ACL mode: Datasets → Select dataset → Edit → ACL Mode
#
# For datasets with NFSv4 ACLs, use TrueNAS GUI:
#   Storage → Pools → dataset → Edit Permissions
#
# This script assumes UNIX/Passthrough permissions mode

set -euo pipefail

NAS_IP="${NAS_IP:-192.168.178.101}"
NAS_USER="${NAS_USER:-root}"
MUSIC_PATH="${MUSIC_PATH:-/mnt/pool/media/Music}"

# User/group for media files (adjust as needed)
# Common choices: nobody:nogroup, media:media, or specific UID:GID
OWNER="${OWNER:-nobody}"
GROUP="${GROUP:-nogroup}"

echo "Connecting to svr-nas at ${NAS_IP}..."

ssh "${NAS_USER}@${NAS_IP}" << EOF
set -e

echo "Fixing permissions on ${MUSIC_PATH}..."

# Verify path exists
if [ ! -d "${MUSIC_PATH}" ]; then
    echo "Error: ${MUSIC_PATH} does not exist"
    exit 1
fi

# Set directory permissions (755 = rwxr-xr-x)
echo "Setting directory permissions to 755..."
find "${MUSIC_PATH}" -type d -exec chmod 755 {} \;

# Set file permissions (644 = rw-r--r--)
echo "Setting file permissions to 644..."
find "${MUSIC_PATH}" -type f -exec chmod 644 {} \;

# Set ownership
echo "Setting ownership to ${OWNER}:${GROUP}..."
chown -R "${OWNER}:${GROUP}" "${MUSIC_PATH}"

echo "Done. Current permissions:"
ls -la "${MUSIC_PATH}" | head -20
EOF

echo "Permissions fixed successfully."
