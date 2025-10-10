#!/bin/bash
# Setup script for DPC Maven Repository

set -e

echo "🚀 Setting up DPC Maven Repository..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Start the services
echo "📦 Starting Maven Repository..."
docker-compose up -d

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
    echo "⚠️  Nexus is taking longer than expected to start. Check logs with: docker-compose logs"
    exit 1
fi

# Get the initial admin password
echo ""
echo "🔑 Retrieving initial admin password..."
if docker exec dpc-maven-repo test -f /nexus-data/admin.password; then
    ADMIN_PASSWORD=$(docker exec dpc-maven-repo cat /nexus-data/admin.password 2>/dev/null || echo "Not available yet")
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "📝 Access Information:"
    echo "   URL: http://localhost:8081"
    echo "   Username: admin"
    echo "   Password: $ADMIN_PASSWORD"
    echo ""
    echo "⚠️  Important: Please change the default password after first login!"
else
    echo "✅ Setup complete!"
    echo ""
    echo "📝 Access Information:"
    echo "   URL: http://localhost:8081"
    echo ""
    echo "ℹ️  The admin password file is not available yet. It may take a few more moments."
    echo "   Retrieve it later with: docker exec dpc-maven-repo cat /nexus-data/admin.password"
fi

echo ""
echo "📚 For more information, see README.md"
