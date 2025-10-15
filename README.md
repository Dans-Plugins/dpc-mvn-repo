# DPC Maven Repository

Infrastructure-as-Code Maven Repository for Dan's Plugins Community using Docker and Docker Compose.

## Overview

This repository provides a self-hosted Maven repository using Sonatype Nexus Repository Manager OSS. It's designed to be easy to deploy and manage using Docker containers.

## Prerequisites

- Docker (version 20.10 or later)
- Docker Compose (version 2.0 or later)
- At least 2GB of available RAM
- At least 10GB of available disk space

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Dans-Plugins/dpc-mvn-repo.git
cd dpc-mvn-repo
```

### 2. Start the Maven Repository

```bash
docker-compose up -d
```

This will:
- Pull the Nexus Repository Manager OSS Docker image
- Create a persistent volume for Maven artifacts
- Start the repository on port 8081

### 3. Access the Repository

- **Web Interface**: http://localhost:8081
- **Default Credentials**: 
  - Username: `admin`
  - Password: Located in `/nexus-data/admin.password` inside the container

To retrieve the initial admin password:

```bash
docker exec dpc-maven-repo cat /nexus-data/admin.password
```

### 4. Configure Maven Settings

After logging in and changing the default password, configure your Maven `settings.xml` file (usually located at `~/.m2/settings.xml`):

```xml
<settings>
  <servers>
    <server>
      <id>dpc-maven-repo</id>
      <username>admin</username>
      <password>your-password</password>
    </server>
  </servers>
  
  <mirrors>
    <mirror>
      <id>dpc-maven-repo</id>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:8081/repository/maven-public/</url>
    </mirror>
  </mirrors>
</settings>
```

### 5. Deploy Artifacts

To deploy artifacts to the repository, add this to your project's `pom.xml`:

```xml
<distributionManagement>
  <repository>
    <id>dpc-maven-repo</id>
    <url>http://localhost:8081/repository/maven-releases/</url>
  </repository>
  <snapshotRepository>
    <id>dpc-maven-repo</id>
    <url>http://localhost:8081/repository/maven-snapshots/</url>
  </snapshotRepository>
</distributionManagement>
```

Then deploy with:

```bash
mvn clean deploy
```

## Management Commands

### Start the Repository

```bash
docker-compose up -d
```

### Stop the Repository

```bash
docker-compose down
```

### View Logs

```bash
docker-compose logs -f
```

### Restart the Repository

```bash
docker-compose restart
```

### Update to Latest Version

```bash
docker-compose pull
docker-compose up -d
```

## Repository Structure

```
dpc-mvn-repo/
├── docker-compose.yml    # Docker Compose orchestration
├── Dockerfile            # Custom Nexus image configuration
├── .gitignore           # Git ignore rules
└── README.md            # This file
```

## Default Repositories

Nexus comes with several pre-configured repositories:

- **maven-central**: Proxy to Maven Central
- **maven-releases**: Hosted repository for release artifacts
- **maven-snapshots**: Hosted repository for snapshot artifacts
- **maven-public**: Repository group combining all Maven repositories

## Importing Artifacts

You can import existing Maven artifacts from another repository or backup:

### Quick Import

```bash
# Import from a local directory
./import-artifacts.sh -p your-password /path/to/maven-repository

# Import from a backup file
./import-artifacts.sh -p your-password /path/to/backup.tar.gz

# Using make
make import SOURCE=/path/to/repository PASSWORD=your-password
```

### Get Admin Password

```bash
make password
```

### Import Examples

```bash
# Import releases
./import-artifacts.sh -p admin123 /path/to/old-maven-repo

# Import snapshots
./import-artifacts.sh -p admin123 --snapshot /path/to/snapshots

# Dry run (test without importing)
./import-artifacts.sh -p admin123 --dry-run /path/to/repository
```

For detailed documentation on importing artifacts, including troubleshooting and advanced usage, see [docs/IMPORT.md](docs/IMPORT.md).

## Configuration

### Resource Limits

The default configuration allocates:
- Heap Memory: 512MB
- Direct Memory: 273MB

To adjust these limits, modify the `INSTALL4J_ADD_VM_PARAMS` environment variable in `docker-compose.yml`.

### Port Configuration

By default, Nexus runs on port 8081. To change this, modify the ports mapping in `docker-compose.yml`:

```yaml
ports:
  - "9000:8081"  # Change 9000 to your desired port
```

## Data Persistence

Maven artifacts and configuration are stored in a Docker volume named `nexus-data`. This ensures data persists across container restarts and upgrades.

To backup the data:

```bash
docker run --rm -v dpc-mvn-repo_nexus-data:/data -v $(pwd):/backup ubuntu tar czf /backup/nexus-backup.tar.gz /data
```

To restore from backup:

```bash
docker run --rm -v dpc-mvn-repo_nexus-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/nexus-backup.tar.gz -C /
```

## Security

### Initial Setup

1. Change the default admin password immediately after first login
2. Create separate user accounts for different teams/purposes
3. Configure appropriate roles and permissions
4. Enable SSL/TLS for production deployments

### Production Deployment

For production use:

1. Use a reverse proxy (nginx/Apache) with SSL/TLS
2. Configure firewall rules to restrict access
3. Set up regular backups
4. Enable authentication for all repositories
5. Use strong passwords and consider token-based authentication

## Troubleshooting

### Container Won't Start

Check logs:
```bash
docker-compose logs
```

Common issues:
- Insufficient memory
- Port 8081 already in use
- Docker daemon not running

### Can't Access Web Interface

1. Verify container is running: `docker-compose ps`
2. Check if port is accessible: `curl http://localhost:8081`
3. Review firewall settings

### Slow Performance

Increase memory allocation in `docker-compose.yml`:

```yaml
environment:
  - INSTALL4J_ADD_VM_PARAMS=-Xms1g -Xmx1g -XX:MaxDirectMemorySize=546m
```

## Support

For issues and questions:
- Create an issue in this repository
- Check [Nexus Repository Manager documentation](https://help.sonatype.com/repomanager3)

## License

This infrastructure configuration is provided as-is for the Dan's Plugins Community.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.