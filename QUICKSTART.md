# Quick Start Guide

Get started with DPC Maven Repository in 3 easy steps!

## Step 1: Prerequisites

Make sure you have:
- Docker installed ([Get Docker](https://docs.docker.com/get-docker/))
- Docker Compose v2+ installed
- At least 2GB RAM available
- At least 10GB disk space

## Step 2: Quick Setup

```bash
# Clone the repository
git clone https://github.com/Dans-Plugins/dpc-mvn-repo.git
cd dpc-mvn-repo

# Start the Maven repository
./setup.sh
```

The setup script will:
- Start the Nexus Repository Manager container
- Wait for it to be ready
- Display the initial admin password

## Step 3: Access & Configure

1. Open your browser: http://localhost:8081

2. Log in with:
   - Username: `admin`
   - Password: (shown by setup script)

3. Follow the setup wizard to change your password

## Using the Repository

### For Maven Projects

Add to your `pom.xml`:

```xml
<repositories>
  <repository>
    <id>dpc-maven-repo</id>
    <url>http://localhost:8081/repository/maven-public/</url>
  </repository>
</repositories>
```

### To Deploy Artifacts

1. Add to `~/.m2/settings.xml`:

```xml
<servers>
  <server>
    <id>dpc-maven-repo</id>
    <username>admin</username>
    <password>your-password</password>
  </server>
</servers>
```

2. Add to your `pom.xml`:

```xml
<distributionManagement>
  <repository>
    <id>dpc-maven-repo</id>
    <url>http://localhost:8081/repository/maven-releases/</url>
  </repository>
</distributionManagement>
```

3. Deploy:

```bash
mvn clean deploy
```

## Common Commands

```bash
make start      # Start the repository
make stop       # Stop the repository
make status     # Check status
make logs       # View logs
make backup     # Create backup
```

## Need More Help?

- 📖 [Full Documentation](README.md)
- 📦 [Publishing from a Plugin Repo](PUBLISHING.md)
- 🚀 [Production Deployment](docs/PRODUCTION.md)
- 🔧 [Troubleshooting](docs/TROUBLESHOOTING.md)
- 💬 [Contributing](CONTRIBUTING.md)

## What's Included?

- ✅ Sonatype Nexus Repository Manager OSS
- ✅ Docker & Docker Compose setup
- ✅ Automated backup & restore scripts
- ✅ Production-ready configuration examples
- ✅ Comprehensive documentation

## Default Repositories

Your Nexus instance includes:
- **maven-central**: Proxy to Maven Central
- **maven-releases**: Your release artifacts
- **maven-snapshots**: Your snapshot artifacts
- **maven-public**: Combined repository group

Enjoy your Maven repository! 🎉
