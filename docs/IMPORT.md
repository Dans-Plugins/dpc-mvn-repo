# Importing Artifacts Guide

This guide explains how to import Maven artifacts from an existing repository to your DPC Maven Repository.

## Overview

The import functionality allows you to migrate artifacts from:
- Local Maven repository directories
- Backup files (tar.gz, tar, zip)
- Remote Maven repositories (planned)

This is useful when migrating from an old Maven repository deployment to this new infrastructure.

## Prerequisites

- DPC Maven Repository running (`make start`)
- Nexus admin password
- Source artifacts in one of the supported formats

## Quick Start

### Import from Local Directory

```bash
# Using the script directly
./import-artifacts.sh -p your-password /path/to/maven-repository

# Or using make
make import SOURCE=/path/to/maven-repository PASSWORD=your-password
```

### Import from Backup File

```bash
./import-artifacts.sh -p your-password /path/to/backup.tar.gz
```

### Import to Snapshots Repository

```bash
./import-artifacts.sh -p your-password --snapshot /path/to/snapshots
```

### Dry Run (Test Without Importing)

```bash
./import-artifacts.sh -p your-password --dry-run /path/to/maven-repository
```

## Import Script Options

```
Usage: ./import-artifacts.sh [OPTIONS] <source>

OPTIONS:
    -h, --help              Show help message
    -u, --user USER         Nexus username (default: admin)
    -p, --password PASS     Nexus password (required)
    -r, --repo REPO         Target repository (default: maven-releases)
    -n, --nexus-url URL     Nexus URL (default: http://localhost:8081)
    -t, --type TYPE         Import type: local, remote, or backup
    -s, --snapshot          Import to maven-snapshots
    --dry-run               Show what would be imported
```

## Detailed Examples

### Example 1: Basic Import

Import all artifacts from a local Maven repository directory:

```bash
./import-artifacts.sh \
    -p admin123 \
    /home/user/.m2/repository
```

### Example 2: Import to Custom Repository

Import to a specific repository (must exist in Nexus):

```bash
./import-artifacts.sh \
    -p admin123 \
    -r maven-custom \
    /path/to/artifacts
```

### Example 3: Import with Custom Nexus URL

Import to a remote Nexus instance:

```bash
./import-artifacts.sh \
    -u admin \
    -p admin123 \
    -n https://nexus.example.com \
    /path/to/artifacts
```

### Example 4: Test Before Importing

See what would be imported without making changes:

```bash
./import-artifacts.sh \
    -p admin123 \
    --dry-run \
    /path/to/artifacts
```

### Example 5: Import from Old Backup

Extract and import from a repository backup:

```bash
./import-artifacts.sh \
    -p admin123 \
    /backups/old-nexus-backup.tar.gz
```

## Supported File Formats

The import script handles standard Maven repository structures and artifact types:

### Directory Structure
```
repository/
├── com/
│   └── example/
│       └── myapp/
│           └── 1.0.0/
│               ├── myapp-1.0.0.jar
│               ├── myapp-1.0.0.pom
│               ├── myapp-1.0.0-sources.jar
│               └── myapp-1.0.0-javadoc.jar
└── org/
    └── another/
        └── lib/
            └── 2.1.0/
                ├── lib-2.1.0.jar
                └── lib-2.1.0.pom
```

### Supported Artifact Types
- `.jar` - Java archives
- `.pom` - Maven Project Object Model files
- `-sources.jar` - Source code archives
- `-javadoc.jar` - Documentation archives
- `.war` - Web application archives
- `.ear` - Enterprise application archives
- `.aar` - Android archives
- `.zip` - ZIP archives
- Any other Maven artifact type

### Supported Backup Formats
- `.tar.gz` / `.tgz` - Gzipped tar archives
- `.tar` - Tar archives
- `.zip` - ZIP archives

## Migration Workflow

### Step 1: Prepare Source Repository

If your old repository is running, you can backup its data:

```bash
# On the old server
cd /path/to/old/nexus
./backup.sh
```

Or if you have direct access to the repository directory:

```bash
tar czf maven-artifacts.tar.gz /path/to/maven/repository
```

### Step 2: Transfer to New Server

Copy the backup or directory to your new server:

```bash
scp maven-artifacts.tar.gz user@new-server:/tmp/
```

### Step 3: Start DPC Maven Repository

```bash
cd dpc-mvn-repo
make start
```

### Step 4: Import Artifacts

```bash
# Get the admin password
make password

# Import the artifacts
./import-artifacts.sh -p <admin-password> /tmp/maven-artifacts.tar.gz
```

### Step 5: Verify Import

1. Open the Nexus web interface: http://localhost:8081
2. Navigate to Browse → maven-releases
3. Verify your artifacts are present
4. Test downloading an artifact

## Environment Variables

You can use environment variables instead of command-line options:

```bash
export NEXUS_URL="http://localhost:8081"
export NEXUS_USER="admin"
export NEXUS_PASSWORD="your-password"
export NEXUS_REPO="maven-releases"

./import-artifacts.sh /path/to/artifacts
```

## Troubleshooting

### Container Not Running

```
❌ Nexus container is not running
```

**Solution**: Start the repository:
```bash
make start
```

### Authentication Failed

```
❌ Failed to authenticate with Nexus
```

**Solution**: 
1. Verify password: `make password`
2. If password was changed, use the new password
3. Check Nexus is accessible: `curl http://localhost:8081`

### No Artifacts Found

```
⚠️  No Maven artifacts found in /path/to/dir
```

**Solution**:
1. Verify the directory contains Maven artifacts (.pom files)
2. Check the directory structure matches Maven layout
3. Try a dry-run to see what the script detects

### Import Failures

If some artifacts fail to import:

1. Check Nexus logs: `make logs`
2. Verify disk space: `df -h`
3. Check artifact file permissions
4. Ensure repository exists in Nexus
5. Try re-running the import (duplicate uploads are handled gracefully)

### Large Imports

For very large repositories:

1. Consider importing in batches by subdirectory
2. Increase timeout values if needed
3. Monitor disk space during import
4. The import can be interrupted and resumed (already-imported artifacts are skipped)

## Performance Considerations

### Import Speed

Import speed depends on:
- Number of artifacts
- Size of artifacts
- Network speed (if remote)
- Disk I/O performance
- Nexus server resources

Typical performance:
- ~10-50 artifacts/minute for local imports
- Slower for remote imports or large files

### Resource Requirements

During import, ensure adequate resources:
- **Disk Space**: 2x the source repository size
- **Memory**: Default Nexus allocation (512MB) is usually sufficient
- **CPU**: Import is mostly I/O bound

To increase Nexus memory for large imports, see [Configuration Guide](../README.md#configuration).

## Security Considerations

### Password Management

**Never commit passwords to version control.**

Options for secure password handling:

1. **Environment variable**:
   ```bash
   export NEXUS_PASSWORD="your-password"
   ./import-artifacts.sh /path/to/artifacts
   ```

2. **Password file**:
   ```bash
   ./import-artifacts.sh -p "$(cat ~/.nexus-password)" /path/to/artifacts
   ```

3. **Interactive prompt** (feature request):
   Currently not supported, but you can modify the script to read from stdin

### Access Control

After importing:

1. Change the default admin password
2. Create specific user accounts for CI/CD
3. Configure repository permissions
4. Enable authentication for all repositories

## Advanced Usage

### Importing Specific Groups

To import only specific group IDs:

```bash
# Find artifacts for a specific group
cd /path/to/maven-repository
find . -path "*/com/example/*" -name "*.pom" -type f > /tmp/to-import.txt

# Create a temporary directory with symlinks
mkdir /tmp/import-subset
while read pom; do
    dir=$(dirname "$pom")
    mkdir -p "/tmp/import-subset/$dir"
    cp -r "$dir"/* "/tmp/import-subset/$dir/"
done < /tmp/to-import.txt

# Import the subset
./import-artifacts.sh -p admin123 /tmp/import-subset
```

### Importing to Multiple Repositories

For releases and snapshots:

```bash
# Import releases
./import-artifacts.sh -p admin123 /path/to/releases

# Import snapshots
./import-artifacts.sh -p admin123 --snapshot /path/to/snapshots
```

### Custom Repository Mapping

If your old repository used different names:

1. Create matching repositories in Nexus UI
2. Use `-r` option to specify target:

```bash
./import-artifacts.sh -p admin123 -r my-custom-repo /path/to/artifacts
```

## Integration with CI/CD

### Example: Automated Import Job

```bash
#!/bin/bash
# automated-import.sh

set -e

SOURCE_BACKUP="/backups/daily/maven-repo.tar.gz"
NEXUS_PASS=$(cat /etc/nexus-password)

# Ensure Nexus is running
cd /opt/dpc-mvn-repo
make start

# Wait for Nexus to be ready
sleep 30

# Import artifacts
./import-artifacts.sh -p "$NEXUS_PASS" "$SOURCE_BACKUP"

# Verify import
./import-artifacts.sh -p "$NEXUS_PASS" --dry-run "$SOURCE_BACKUP" > /tmp/verify.log

echo "Import completed. See /tmp/verify.log for details."
```

## FAQ

### Q: Can I import while Nexus is running?

**A**: Yes, the import script requires Nexus to be running. It uses the Nexus REST API.

### Q: Will duplicate artifacts be skipped?

**A**: Nexus will handle duplicates based on your repository configuration. By default, it will reject duplicate releases but allow duplicate snapshots.

### Q: Can I resume a failed import?

**A**: Yes, simply re-run the import command. Already-imported artifacts will be handled according to Nexus rules.

### Q: How do I import from Maven Central or other public repositories?

**A**: Configure a proxy repository in Nexus instead of importing. This is more efficient and keeps artifacts up-to-date.

### Q: Can I import metadata files?

**A**: Yes, the script imports all files including maven-metadata.xml and checksums (.md5, .sha1).

### Q: What about corrupted artifacts?

**A**: The import script will log failures but continue with other artifacts. Review the logs and re-import failed artifacts if needed.

## Getting Help

If you encounter issues:

1. Run with `--dry-run` to diagnose without changes
2. Check [Troubleshooting Guide](TROUBLESHOOTING.md)
3. Review Nexus logs: `make logs`
4. Create an issue with:
   - Import command used
   - Error messages
   - Nexus version
   - Source repository structure

## See Also

- [README](../README.md) - Main documentation
- [Backup Guide](../README.md#data-persistence) - Backing up Nexus data
- [Production Guide](PRODUCTION.md) - Production deployment
- [Nexus Documentation](https://help.sonatype.com/repomanager3) - Official Nexus docs
