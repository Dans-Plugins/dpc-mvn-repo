# Troubleshooting Guide

Common issues and solutions for the DPC Maven Repository.

## Container Issues

### Container Won't Start

**Solutions**:

1. Check if port 8081 is already in use:
   ```bash
   sudo lsof -i :8081
   ```
   
2. Check Docker logs:
   ```bash
   docker compose logs nexus
   ```

3. Verify Docker is running:
   ```bash
   docker ps
   ```

4. Check available disk space:
   ```bash
   df -h
   ```

### Can't Access Web Interface

**Solutions**:

1. Verify container is running:
   ```bash
   make status
   ```

2. Wait for Nexus to initialize (1-2 minutes):
   ```bash
   docker compose logs -f nexus
   ```

3. Test connectivity:
   ```bash
   curl -v http://localhost:8081
   ```

### Can't Log In

**Solutions**:

1. Retrieve initial password:
   ```bash
   docker exec dpc-maven-repo cat /nexus-data/admin.password
   ```

2. If file doesn't exist, wait a few minutes for initialization

## Performance Issues

### Slow Response Times

**Solutions**:

1. Check resource usage:
   ```bash
   docker stats dpc-maven-repo
   ```

2. Increase memory in `docker-compose.yml`:
   ```yaml
   environment:
     - INSTALL4J_ADD_VM_PARAMS=-Xms2g -Xmx2g -XX:MaxDirectMemorySize=2g
   ```

## Maven Integration Issues

### Can't Deploy Artifacts

**Solutions**:

1. Verify credentials in `~/.m2/settings.xml`

2. Check server ID matches `pom.xml`

3. Verify repository URL:
   ```bash
   curl -u username:password http://localhost:8081/repository/maven-releases/
   ```

4. Enable debug logging:
   ```bash
   mvn deploy -X
   ```

### Can't Download Dependencies

**Solutions**:

1. Check repository is online in Nexus UI

2. Test repository access:
   ```bash
   curl http://localhost:8081/repository/maven-public/
   ```

3. Clear local Maven cache:
   ```bash
   rm -rf ~/.m2/repository/*
   ```

## Getting Help

Collect diagnostic information:

```bash
# System info
docker version
docker compose version

# Container info
make status
docker compose logs --tail=100
```

Create an issue with this information and a clear description of the problem.
