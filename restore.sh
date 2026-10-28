#!/bin/bash
# Restore script for DPC Maven Repository

set -e

BACKUP_FILE="${1}"
# Must match the volume backup.sh read from and docker-compose.yml mounts.
# Override with NEXUS_VOLUME when the checkout directory is not dpc-mvn-repo.
VOLUME_NAME="${NEXUS_VOLUME:-dpc-mvn-repo_nexus-data}"

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Error: Please provide a backup file as an argument"
    echo "Usage: ./restore.sh <backup-file>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "📦 Target volume: $VOLUME_NAME"
# A missing volume is expected on a fresh host, but if Compose uses a
# different name the restored data would never be mounted. Warn, don't fail.
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
    echo "⚠️  Warning: Docker volume '$VOLUME_NAME' does not exist and will be created."
    echo "   Compose derives the volume name from the checkout directory name."
    echo "   If this checkout is not named dpc-mvn-repo, cancel and rerun with:"
    echo "   NEXUS_VOLUME=<directory-name>_nexus-data ./restore.sh $BACKUP_FILE"
fi

echo "⚠️  WARNING: This will replace all current data in the Maven repository!"
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Stop the container if running
if docker ps | grep -q dpc-maven-repo; then
    echo "🛑 Stopping Maven Repository..."
    docker compose down
fi

# Restore from backup. Empty the volume first so files written after the
# backup was taken do not survive next to the restored ones. The archive is
# checked before anything is deleted: it must read cleanly and contain the
# data/ tree that backup.sh writes, or the volume is left untouched.
echo "📦 Restoring from backup: $BACKUP_FILE"
# shellcheck disable=SC2016 # $1 is expanded by the container's sh, not here
if ! docker run --rm \
    -v "${VOLUME_NAME}:/data" \
    -v "$(dirname "$(realpath "$BACKUP_FILE")"):/backup" \
    ubuntu sh -c '
        tar tzf "$1" >/dev/null || { echo "❌ Error: Backup archive is unreadable: $1"; exit 1; }
        tar tzf "$1" | grep -q "^data/" || { echo "❌ Error: Backup archive has no data/ directory: $1"; exit 1; }
        find /data -mindepth 1 -delete
        tar xzf "$1" -C /
    ' sh "/backup/$(basename "$BACKUP_FILE")"; then
    echo "❌ Error: Restore failed. The Maven Repository has been left stopped."
    echo "   Fix the problem above and rerun ./restore.sh, or start it with: make start"
    exit 1
fi

echo "✅ Restore complete!"
echo "🚀 Starting Maven Repository..."
docker compose up -d

echo "✅ Done! The repository has been restored and is starting up."
