# Use the requested base image
FROM nvidia/cuda:13.1.0-base-ubuntu22.04

# Build arguments (can be overridden at build/push time)
ARG PANEL_USER=admin123
ARG PANEL_PASSWORD=12345678
ARG PANEL_PORT=20000

# Export defaults into environment
ENV DEBIAN_FRONTEND=noninteractive \
    PANEL_USER=${PANEL_USER} \
    PANEL_PASSWORD=${PANEL_PASSWORD} \
    PANEL_PORT=${PANEL_PORT} \
    LANG=en_US.UTF-8 \
    PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Basic prerequisites so the installer can run reliably
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    unzip \
    zip \
    tar \
    bzip2 \
    xz-utils \
    gnupg \
    lsb-release \
    sudo \
    python3 \
    python3-pip \
    net-tools \
    iproute2 \
    iputils-ping \
    cron \
    sqlite3 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Copy the installer (you said you'll place install_panel.sh in the repo root)
# Note: The script should already be modified for non-interactive mode as you described.
COPY install_panel.sh /tmp/install_panel.sh
RUN chmod +x /tmp/install_panel.sh

# Run the installer non-interactively. The script accepts -u -p -P -y
# We continue even if the installer returns non-zero to allow image build to complete for debugging.
# (In practice the panel may require services & init to run properly in a container.)
RUN /tmp/install_panel.sh -u "${PANEL_USER}" -p "${PANEL_PASSWORD}" -P "${PANEL_PORT}" -y || true

# Expose the panel port
EXPOSE ${PANEL_PORT}

# Simple healthcheck to quickly show whether the panel HTTP endpoint responds.
# It may fail initially while the panel finishes startup.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PANEL_PORT}/login" || exit 1

# Keep the container running and start the panel init script on container start.
# Note: /etc/init.d/bt should have been created by the installer.
ENTRYPOINT ["/bin/bash", "-c", "/etc/init.d/bt start || true; tail -F /www/server/panel/logs/*.log /dev/null"]
