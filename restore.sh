#!/bin/bash
# Restore script for DPC Maven Repository

set -e

BACKUP_FILE="${1}"

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Error: Please provide a backup file as an argument"
    echo "Usage: ./restore.sh <backup-file>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
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
    docker-compose down
fi

# Restore from backup
echo "📦 Restoring from backup: $BACKUP_FILE"
docker run --rm \
    -v dpc-mvn-repo_nexus-data:/data \
    -v "$(dirname "$(realpath "$BACKUP_FILE")"):/backup" \
    ubuntu tar xzf "/backup/$(basename "$BACKUP_FILE")" -C /

echo "✅ Restore complete!"
echo "🚀 Starting Maven Repository..."
docker-compose up -d

echo "✅ Done! The repository has been restored and is starting up."
