#!/bin/bash
# Backup script for DPC Maven Repository

set -e

BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="nexus-backup-${TIMESTAMP}.tar.gz"
# Compose names the volume <project>_nexus-data, and the project name defaults
# to the checkout directory name. Override with NEXUS_VOLUME when they differ.
VOLUME_NAME="${NEXUS_VOLUME:-dpc-mvn-repo_nexus-data}"

echo "📦 Starting backup of DPC Maven Repository..."

# docker run -v <name>:/data creates a missing volume silently, which would
# produce an archive of an empty directory. Refuse to back up in that case.
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
    echo "❌ Error: Docker volume '$VOLUME_NAME' does not exist (or Docker is not reachable)."
    echo "   Compose derives the volume name from the checkout directory name."
    echo "   Find the right one with: docker volume ls | grep nexus-data"
    echo "   Then run: NEXUS_VOLUME=<name> ./backup.sh"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if container is running
if ! docker ps | grep -q dpc-maven-repo; then
    echo "⚠️  Warning: Container is not running. Backing up from volume only."
fi

# Create backup
echo "💾 Creating backup of volume '${VOLUME_NAME}': ${BACKUP_DIR}/${BACKUP_FILE}"
docker run --rm \
    -v "${VOLUME_NAME}:/data" \
    -v "$(realpath "$BACKUP_DIR"):/backup" \
    ubuntu tar czf "/backup/${BACKUP_FILE}" /data

echo "✅ Backup complete: ${BACKUP_DIR}/${BACKUP_FILE}"
echo "📊 Backup size: $(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)"
