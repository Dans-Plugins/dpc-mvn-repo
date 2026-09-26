# Dockerfile for custom Nexus configuration
# Extends the official Nexus Repository Manager OSS image
# Pinned to the exact release running in production: a floating tag would let a
# rebuild silently upgrade Nexus and migrate the persistent nexus-data volume.
# Upgrade deliberately (back up nexus-data first) by changing this line.
FROM sonatype/nexus3:3.85.0@sha256:a2f0af994a4022a127414e9733adcf175ffb655d266fb4b0836717c5aa33a58d

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
