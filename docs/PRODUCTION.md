# Production Deployment Guide

This guide covers deploying the DPC Maven Repository in a production environment.

## Prerequisites

- Linux server (Ubuntu 20.04+ or similar)
- Docker Engine 20.10+
- Docker Compose v2+
- At least 4GB RAM
- At least 50GB available disk space
- Domain name (optional but recommended)
- SSL/TLS certificate (optional but recommended)

## Deployment Steps

### 1. Server Setup

Update your system:

```bash
sudo apt update && sudo apt upgrade -y
```

Install Docker:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Log out and back in for group changes to take effect.

### 2. Clone Repository

```bash
git clone https://github.com/Dans-Plugins/dpc-mvn-repo.git
cd dpc-mvn-repo
```

### 3. Configure Environment

Create production configuration:

```bash
cp .env.example .env
cp docker-compose.override.yml.example docker-compose.override.yml
```

Edit `.env` with production values:

```bash
NEXUS_PORT=8081
NEXUS_MIN_HEAP=2g
NEXUS_MAX_HEAP=2g
NEXUS_MAX_DIRECT_MEMORY=2g
```

### 4. Firewall Configuration

Allow necessary ports:

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (for reverse proxy)
sudo ufw allow 443/tcp   # HTTPS (for reverse proxy)
sudo ufw enable
```

**Note**: Do not expose port 8081 directly. Use a reverse proxy instead.

### 5. Deploy with Reverse Proxy (Recommended)

#### Option A: Nginx Reverse Proxy

Install Nginx:

```bash
sudo apt install nginx -y
```

Create Nginx configuration (`/etc/nginx/sites-available/maven-repo`):

```nginx
server {
    listen 80;
    server_name maven.yourdomain.com;
    
    # Redirect to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name maven.yourdomain.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/maven.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/maven.yourdomain.com/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Nexus Configuration
    client_max_body_size 500M;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/maven-repo /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 6. SSL/TLS Certificate

Using Let's Encrypt:

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d maven.yourdomain.com
```

### 7. Start the Repository

```bash
docker compose up -d
```

### 8. Initial Configuration

1. Access the web interface at your domain
2. Retrieve initial password:
   ```bash
   docker exec dpc-maven-repo cat /nexus-data/admin.password
   ```
3. Log in and change the password
4. Configure repository settings as needed

## Security Hardening

### 1. Disable Anonymous Access

- Log in to Nexus
- Go to Security → Anonymous Access
- Disable anonymous access

### 2. Create Service Accounts

- Create dedicated accounts for CI/CD systems
- Use least privilege principle
- Rotate credentials regularly

### 3. Regular Updates

```bash
cd dpc-mvn-repo
git pull
make update
```

### 4. Configure Backups

Set up automated backups:

```bash
# Create backup script
cat > /usr/local/bin/backup-nexus.sh << 'EOF'
#!/bin/bash
cd /path/to/dpc-mvn-repo
./backup.sh /backup/nexus
# Keep only last 7 days
find /backup/nexus -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/backup-nexus.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-nexus.sh") | crontab -
```

## Monitoring

### Health Checks

```bash
curl -f http://localhost:8081 || echo "Nexus is down!"
```

### Resource Monitoring

```bash
docker stats dpc-maven-repo
```

## Disaster Recovery

### Recovery Process

1. Stop the current instance
2. Restore from backup:
   ```bash
   make restore BACKUP=/path/to/backup.tar.gz
   ```
3. Verify data integrity

## Support

For production issues, check the troubleshooting guide or contact support.
