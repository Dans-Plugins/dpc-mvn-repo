#!/bin/bash
# Setup script for DPC Maven Repository

set -e

echo "🚀 Setting up DPC Maven Repository..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose v2 is installed. Every command below uses the
# `docker compose` plugin form, not the standalone v1 binary.
if ! docker compose version &> /dev/null; then
    echo "❌ Error: Docker Compose v2 is not installed. Please install the Docker Compose plugin first."
    exit 1
fi

# Start the services
echo "📦 Starting Maven Repository..."
docker compose up -d

# Wait for Nexus to be ready
echo "⏳ Waiting for Nexus to start (this may take a few minutes)..."
MAX_WAIT=300
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker exec dpc-maven-repo curl -sf http://localhost:8081 > /dev/null 2>&1; then
        echo "✅ Nexus is ready!"
        break
    fi
    sleep 5
    COUNTER=$((COUNTER + 5))
    echo "   Still waiting... ($COUNTER seconds)"
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    echo "⚠️  Nexus is taking longer than expected to start. Check logs with: docker compose logs"
    exit 1
fi

# Ask Compose which host port 8081 is published on, so NEXUS_PORT from .env
# (or an override file) is reflected in the printed URL; fall back to 8081
HOST_PORT=$(docker compose port nexus 8081 2>/dev/null | tail -n 1)
HOST_PORT="${HOST_PORT##*:}"
HOST_PORT="${HOST_PORT:-8081}"

# Get the initial admin password
echo ""
echo "🔑 Retrieving initial admin password..."
if docker exec dpc-maven-repo test -f /nexus-data/admin.password; then
    ADMIN_PASSWORD=$(docker exec dpc-maven-repo cat /nexus-data/admin.password 2>/dev/null || echo "Not available yet")
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "📝 Access Information:"
    echo "   URL: http://localhost:${HOST_PORT}"
    echo "   Username: admin"
    echo "   Password: $ADMIN_PASSWORD"
    echo ""
    echo "⚠️  Important: Please change the default password after first login!"
else
    echo "✅ Setup complete!"
    echo ""
    echo "📝 Access Information:"
    echo "   URL: http://localhost:${HOST_PORT}"
    echo ""
    echo "ℹ️  The admin password file is not available yet. It may take a few more moments."
    echo "   Retrieve it later with: docker exec dpc-maven-repo cat /nexus-data/admin.password"
fi

echo ""
echo "📚 For more information, see README.md"
