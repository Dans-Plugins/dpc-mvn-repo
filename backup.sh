#!/bin/bash
# Backup script for DPC Maven Repository

set -e

BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="nexus-backup-${TIMESTAMP}.tar.gz"

echo "📦 Starting backup of DPC Maven Repository..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if container is running
if ! docker ps | grep -q dpc-maven-repo; then
    echo "⚠️  Warning: Container is not running. Backing up from volume only."
fi

# Create backup
echo "💾 Creating backup: ${BACKUP_DIR}/${BACKUP_FILE}"
docker run --rm \
    -v dpc-mvn-repo_nexus-data:/data \
    -v "$(realpath "$BACKUP_DIR"):/backup" \
    ubuntu tar czf "/backup/${BACKUP_FILE}" /data

echo "✅ Backup complete: ${BACKUP_DIR}/${BACKUP_FILE}"
echo "📊 Backup size: $(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)"
