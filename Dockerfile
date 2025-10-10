# Dockerfile for custom Nexus configuration
# Extends the official Nexus Repository Manager OSS image
FROM sonatype/nexus3:latest

# Maintainer information
LABEL maintainer="Dan's Plugins Community"
LABEL description="Maven Repository for Dan's Plugins Community"

# Optional: Copy custom configuration if needed
# COPY nexus.properties /nexus-data/etc/nexus.properties

USER nexus

# Expose the default Nexus port
EXPOSE 8081

# Health check to ensure Nexus is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8081/ || exit 1
