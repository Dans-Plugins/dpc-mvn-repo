#!/bin/bash
# Import artifacts script for DPC Maven Repository
# This script imports Maven artifacts from an existing repository to Nexus

set -e

# Configuration
NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_REPO="${NEXUS_REPO:-maven-releases}"
CONTAINER_NAME="dpc-maven-repo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage
usage() {
    cat << EOF
📦 DPC Maven Repository - Artifact Import Tool

Usage: $0 [OPTIONS] <source>

Import Maven artifacts from an existing repository or directory.

OPTIONS:
    -h, --help              Show this help message
    -u, --user USER         Nexus username (default: admin)
    -p, --password PASS     Nexus password (required)
    -r, --repo REPO         Target repository (default: maven-releases)
    -n, --nexus-url URL     Nexus URL (default: http://localhost:8081)
    -t, --type TYPE         Import type: local or remote (default: auto-detect)
    -s, --snapshot          Import to maven-snapshots instead
    --dry-run               Show what would be imported without uploading

SOURCE:
    - Local directory: /path/to/maven/repository
    - Remote URL: https://repo.example.com/maven2/
    - Backup file: /path/to/backup.tar.gz

EXAMPLES:
    # Import from local directory
    $0 -p admin123 /path/to/old-maven-repo

    # Import from remote repository
    $0 -p admin123 https://old-repo.example.com/maven2/

    # Import to snapshots repository
    $0 -p admin123 --snapshot /path/to/snapshots

    # Dry run to see what would be imported
    $0 -p admin123 --dry-run /path/to/maven-repo

ENVIRONMENT VARIABLES:
    NEXUS_URL       Nexus repository URL
    NEXUS_USER      Nexus username
    NEXUS_PASSWORD  Nexus password (alternative to -p)
    NEXUS_REPO      Target repository name

EOF
    exit 0
}

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1"
}

# Check if container is running
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        log_error "Nexus container is not running. Start it with: make start"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v find &> /dev/null; then
        missing_deps+=("find")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them before running this script"
        exit 1
    fi
}

# Verify Nexus credentials
verify_credentials() {
    log_info "Verifying Nexus credentials..."
    
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "$NEXUS_USER:$NEXUS_PASSWORD" \
        "$NEXUS_URL/service/rest/v1/status")
    
    if [ "$status_code" != "200" ]; then
        log_error "Failed to authenticate with Nexus (HTTP $status_code)"
        log_info "Please check your username and password"
        exit 1
    fi
    
    log_success "Successfully authenticated with Nexus"
}

# Import from local directory
import_local_directory() {
    local source_dir="$1"
    local imported_count=0
    local failed_count=0
    local skipped_count=0
    
    log_info "Scanning directory: $source_dir"
    
    # Find all POM files (indicates an artifact)
    local pom_files=$(find "$source_dir" -type f -name "*.pom" | sort)
    local total_files=$(echo "$pom_files" | grep -c ".*" || echo "0")
    
    if [ "$total_files" -eq 0 ]; then
        log_warning "No Maven artifacts found in $source_dir"
        exit 0
    fi
    
    log_info "Found $total_files artifacts to import"
    
    # Process each POM file
    local current=0
    while IFS= read -r pom_file; do
        current=$((current + 1))
        
        if [ -z "$pom_file" ]; then
            continue
        fi
        
        # Get the directory containing this POM
        local artifact_dir=$(dirname "$pom_file")
        
        # Extract group, artifact, version from path
        local relative_path=${pom_file#$source_dir/}
        local artifact_info=$(extract_artifact_info "$relative_path")
        
        echo ""
        log_info "[$current/$total_files] Processing: $relative_path"
        
        if [ "$DRY_RUN" = "true" ]; then
            log_info "Would import: $artifact_info"
            imported_count=$((imported_count + 1))
            continue
        fi
        
        # Upload all files for this artifact
        if upload_artifact_files "$artifact_dir" "$relative_path"; then
            log_success "Imported: $artifact_info"
            imported_count=$((imported_count + 1))
        else
            log_error "Failed to import: $artifact_info"
            failed_count=$((failed_count + 1))
        fi
        
    done <<< "$pom_files"
    
    # Print summary
    echo ""
    echo "════════════════════════════════════════"
    log_success "Import completed!"
    echo "  Successfully imported: $imported_count"
    if [ $failed_count -gt 0 ]; then
        echo "  Failed: $failed_count"
    fi
    echo "════════════════════════════════════════"
}

# Extract artifact information from relative path
extract_artifact_info() {
    local relative_path="$1"
    echo "$relative_path" | sed 's/\/[^/]*$//'
}

# Upload artifact files
upload_artifact_files() {
    local artifact_dir="$1"
    local relative_path="$2"
    
    # Get base filename without extension from POM file
    local pom_name=$(basename "$artifact_dir"/*.pom .pom)
    
    # Find all files for this artifact (jar, pom, sources, javadoc, etc.)
    local files=$(find "$artifact_dir" -maxdepth 1 -type f -name "${pom_name}*")
    
    local success=true
    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi
        
        local filename=$(basename "$file")
        local extension="${filename##*.}"
        
        # Build the upload path
        local upload_path=$(dirname "$relative_path")
        
        # Upload using Nexus REST API
        if ! upload_file_to_nexus "$file" "$upload_path/$filename"; then
            success=false
        fi
    done <<< "$files"
    
    if [ "$success" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# Upload a single file to Nexus using REST API
upload_file_to_nexus() {
    local file_path="$1"
    local asset_path="$2"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "$NEXUS_USER:$NEXUS_PASSWORD" \
        -X PUT \
        "$NEXUS_URL/repository/$NEXUS_REPO/$asset_path" \
        --upload-file "$file_path")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
        return 0
    else
        log_warning "Failed to upload $asset_path (HTTP $http_code)"
        return 1
    fi
}

# Import from remote repository
import_remote_repository() {
    local remote_url="$1"
    
    log_warning "Remote repository import is not yet implemented"
    log_info "For now, please download the repository to a local directory and import it"
    log_info "You can use wget or similar tools to mirror the repository:"
    echo ""
    echo "  wget -r -np -nH --cut-dirs=2 -R 'index.html*' $remote_url"
    echo ""
    log_info "Then import the downloaded directory using this script"
    exit 1
}

# Import from backup file
import_backup_file() {
    local backup_file="$1"
    
    log_info "Extracting backup file..."
    
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    if [[ "$backup_file" == *.tar.gz ]] || [[ "$backup_file" == *.tgz ]]; then
        tar -xzf "$backup_file" -C "$temp_dir"
    elif [[ "$backup_file" == *.tar ]]; then
        tar -xf "$backup_file" -C "$temp_dir"
    elif [[ "$backup_file" == *.zip ]]; then
        unzip -q "$backup_file" -d "$temp_dir"
    else
        log_error "Unsupported backup file format. Supported: .tar.gz, .tgz, .tar, .zip"
        exit 1
    fi
    
    log_success "Backup extracted to temporary directory"
    
    # Find the repository directory in the extracted backup
    local repo_dir=$(find "$temp_dir" -type d -name "maven-*" | head -n 1)
    
    if [ -z "$repo_dir" ]; then
        log_warning "Could not find maven repository in backup, trying root directory"
        repo_dir="$temp_dir"
    fi
    
    import_local_directory "$repo_dir"
}

# Parse command line arguments
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
DRY_RUN=false
IMPORT_TYPE=""
SOURCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -u|--user)
            NEXUS_USER="$2"
            shift 2
            ;;
        -p|--password)
            NEXUS_PASSWORD="$2"
            shift 2
            ;;
        -r|--repo)
            NEXUS_REPO="$2"
            shift 2
            ;;
        -n|--nexus-url)
            NEXUS_URL="$2"
            shift 2
            ;;
        -t|--type)
            IMPORT_TYPE="$2"
            shift 2
            ;;
        -s|--snapshot)
            NEXUS_REPO="maven-snapshots"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            SOURCE="$1"
            shift
            ;;
    esac
done

# Main execution
main() {
    echo "════════════════════════════════════════"
    echo "📦 DPC Maven Repository - Import Tool"
    echo "════════════════════════════════════════"
    echo ""
    
    # Validate arguments
    if [ -z "$SOURCE" ]; then
        log_error "No source specified"
        usage
    fi
    
    if [ -z "$NEXUS_PASSWORD" ]; then
        log_error "Nexus password is required. Use -p option or set NEXUS_PASSWORD environment variable"
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Check if container is running
    check_container
    
    # Verify credentials
    if [ "$DRY_RUN" != "true" ]; then
        verify_credentials
    fi
    
    echo ""
    log_info "Import configuration:"
    echo "  Nexus URL: $NEXUS_URL"
    echo "  Username: $NEXUS_USER"
    echo "  Target repository: $NEXUS_REPO"
    echo "  Source: $SOURCE"
    if [ "$DRY_RUN" = "true" ]; then
        echo "  Mode: DRY RUN (no changes will be made)"
    fi
    echo ""
    
    # Auto-detect source type if not specified
    if [ -z "$IMPORT_TYPE" ]; then
        if [ -d "$SOURCE" ]; then
            IMPORT_TYPE="local"
        elif [ -f "$SOURCE" ]; then
            IMPORT_TYPE="backup"
        elif [[ "$SOURCE" =~ ^https?:// ]]; then
            IMPORT_TYPE="remote"
        else
            log_error "Could not determine source type. Please specify with -t option"
            exit 1
        fi
    fi
    
    # Import based on type
    case $IMPORT_TYPE in
        local)
            if [ ! -d "$SOURCE" ]; then
                log_error "Directory not found: $SOURCE"
                exit 1
            fi
            import_local_directory "$SOURCE"
            ;;
        backup)
            if [ ! -f "$SOURCE" ]; then
                log_error "File not found: $SOURCE"
                exit 1
            fi
            import_backup_file "$SOURCE"
            ;;
        remote)
            import_remote_repository "$SOURCE"
            ;;
        *)
            log_error "Unknown import type: $IMPORT_TYPE"
            exit 1
            ;;
    esac
}

# Run main function
main
