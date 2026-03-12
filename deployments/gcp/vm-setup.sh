#!/bin/bash
set -euo pipefail

# =============================================================================
# Plane VM Setup — runs ON the GCE VM
# Installs Docker, clones repo, builds images, starts 10 services
# Uses external Cloud SQL + Memorystore (no local PG/Redis)
# =============================================================================

REPO_URL="${1:-https://github.com/sarathfranciswork/plane.git}"
REPO_BRANCH="${2:-preview}"
PLANE_DIR="/opt/plane"
COMPOSE_FILE="docker-compose.gcp.yml"

log() { echo ">>> [$(date '+%H:%M:%S')] $1"; }

# ---------------------------------------------------------------------------
# 1. Install Docker
# ---------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    log "Docker installed."
else
    log "Docker already installed."
fi

# Install git
command -v git &>/dev/null || apt-get install -y -qq git

# ---------------------------------------------------------------------------
# 2. Clone / update repo
# ---------------------------------------------------------------------------
if [ ! -d "$PLANE_DIR" ]; then
    log "Cloning Plane repository..."
    git clone "$REPO_URL" "$PLANE_DIR"
else
    log "Updating Plane repository..."
fi

cd "$PLANE_DIR"
git fetch origin
git checkout "$REPO_BRANCH"
git pull origin "$REPO_BRANCH" || true

# ---------------------------------------------------------------------------
# 3. Place config files
# ---------------------------------------------------------------------------
log "Placing environment and compose files..."
cp /tmp/plane-root.env "$PLANE_DIR/.env"
cp /tmp/plane-api.env "$PLANE_DIR/apps/api/.env"
cp /tmp/docker-compose.gcp.yml "$PLANE_DIR/$COMPOSE_FILE"
rm -f /tmp/plane-root.env /tmp/plane-api.env /tmp/vm-setup.sh /tmp/docker-compose.gcp.yml

# ---------------------------------------------------------------------------
# 4. Add swap (safety net for builds on 8GB VM)
# ---------------------------------------------------------------------------
if [ ! -f /swapfile ]; then
    log "Creating 4GB swap file for build safety..."
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    log "Swap enabled."
fi

# ---------------------------------------------------------------------------
# 5. Build images (sequentially to avoid OOM)
# ---------------------------------------------------------------------------
log "Building Docker images (this takes 15-20 minutes on first run)..."
cd "$PLANE_DIR"

# Build the API image first (shared by api, worker, beat, migrator)
log "  Building API image..."
docker compose -f "$COMPOSE_FILE" build api 2>&1 | tail -3

# Build frontend images one by one
for svc in web admin space live proxy; do
    log "  Building $svc..."
    docker compose -f "$COMPOSE_FILE" build "$svc" 2>&1 | tail -3
done

log "All images built."

# ---------------------------------------------------------------------------
# 6. Start services
# ---------------------------------------------------------------------------
log "Starting infrastructure (RabbitMQ, MinIO)..."
docker compose -f "$COMPOSE_FILE" up -d plane-mq plane-minio
sleep 10

log "Running database migrations..."
docker compose -f "$COMPOSE_FILE" run --rm migrator 2>&1 | tail -10

log "Starting all application services..."
docker compose -f "$COMPOSE_FILE" up -d

# ---------------------------------------------------------------------------
# 7. Wait and verify
# ---------------------------------------------------------------------------
log "Waiting 30s for services to stabilize..."
sleep 30

log ""
log "=== SERVICE STATUS ==="
docker compose -f "$COMPOSE_FILE" ps
log ""

RUNNING=$(docker compose -f "$COMPOSE_FILE" ps --status=running -q | wc -l)
log "Running containers: $RUNNING / 10 expected (migrator exits after completion)"

log ""
log "================================================"
log "  Plane is deployed!"
log "  Open your browser to the VM's external IP."
log "  First visit will show the instance setup wizard."
log "================================================"
