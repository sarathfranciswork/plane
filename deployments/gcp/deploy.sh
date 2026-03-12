#!/bin/bash
set -euo pipefail

# =============================================================================
# Plane GCP Deployment — Cost-Optimized for Testing
# Reuses existing Cloud SQL (ignite-db) + Memorystore (ignite-redis)
# VM: e2-standard-2 (2 vCPU, 8GB) on ignite-vpc — ~$52/mo new cost
# =============================================================================

PROJECT_ID="innovation-labs-489916"
REGION="us-central1"
ZONE="us-central1-a"
VM_NAME="plane-server"
MACHINE_TYPE="e2-standard-2"
BOOT_DISK_SIZE="50GB"
BOOT_DISK_TYPE="pd-standard"
NETWORK="ignite-vpc"
SUBNET="ignite-subnet"
STATIC_IP_NAME="plane-external-ip"

# Existing managed services
CLOUD_SQL_INSTANCE="ignite-db"
CLOUD_SQL_IP="10.6.0.3"
REDIS_IP="10.65.46.139"
PLANE_DB_NAME="plane"

REPO_URL="https://github.com/sarathfranciswork/plane.git"
REPO_BRANCH="preview"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[PLANE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------------------------------------------------------------------------
log "Step 1/8 — Verifying GCP project..."
gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null
log "  Project: $PROJECT_ID"
log "  Strategy: Reuse ignite-db + ignite-redis, VM on ignite-vpc"

# ---------------------------------------------------------------------------
log "Step 2/8 — Creating 'plane' database on existing Cloud SQL..."
if ! gcloud sql databases describe "$PLANE_DB_NAME" --instance="$CLOUD_SQL_INSTANCE" --project="$PROJECT_ID" &>/dev/null; then
    gcloud sql databases create "$PLANE_DB_NAME" \
        --instance="$CLOUD_SQL_INSTANCE" \
        --project="$PROJECT_ID" \
        --charset=UTF8 --collation=en_US.UTF8
    log "  Database 'plane' created on ignite-db."
else
    log "  Database 'plane' already exists on ignite-db."
fi

# Get the Cloud SQL password (reuse ignite's postgres user or create a plane user)
# For simplicity, we'll create a dedicated plane user
PG_PASS=$(openssl rand -hex 16)
gcloud sql users create plane \
    --instance="$CLOUD_SQL_INSTANCE" \
    --project="$PROJECT_ID" \
    --password="$PG_PASS" 2>/dev/null || {
    # User might already exist, set password instead
    gcloud sql users set-password plane \
        --instance="$CLOUD_SQL_INSTANCE" \
        --project="$PROJECT_ID" \
        --password="$PG_PASS" 2>/dev/null
}
log "  Database user 'plane' configured."

# ---------------------------------------------------------------------------
log "Step 3/8 — Reserving static external IP..."
if ! gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    gcloud compute addresses create "$STATIC_IP_NAME" \
        --region="$REGION" --project="$PROJECT_ID"
fi
EXTERNAL_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" \
    --region="$REGION" --project="$PROJECT_ID" --format="value(address)")
log "  External IP: $EXTERNAL_IP"

# ---------------------------------------------------------------------------
log "Step 4/8 — Creating firewall rules on ignite-vpc..."
for rule_port in "plane-allow-http:80" "plane-allow-https:443"; do
    RULE="${rule_port%%:*}"
    PORT="${rule_port##*:}"
    if ! gcloud compute firewall-rules describe "$RULE" --project="$PROJECT_ID" &>/dev/null; then
        gcloud compute firewall-rules create "$RULE" \
            --project="$PROJECT_ID" --network="$NETWORK" \
            --allow="tcp:$PORT" --source-ranges=0.0.0.0/0 \
            --target-tags=plane-server \
            --description="Allow port $PORT to Plane"
    fi
done

# Also allow SSH on ignite-vpc if not present
if ! gcloud compute firewall-rules describe "plane-allow-ssh" --project="$PROJECT_ID" &>/dev/null; then
    gcloud compute firewall-rules create "plane-allow-ssh" \
        --project="$PROJECT_ID" --network="$NETWORK" \
        --allow=tcp:22 --source-ranges=0.0.0.0/0 \
        --target-tags=plane-server \
        --description="Allow SSH to Plane VM"
fi
log "  Firewall rules ready."

# ---------------------------------------------------------------------------
log "Step 5/8 — Creating GCE VM on ignite-vpc..."
if ! gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" &>/dev/null; then
    gcloud compute instances create "$VM_NAME" \
        --project="$PROJECT_ID" \
        --zone="$ZONE" \
        --machine-type="$MACHINE_TYPE" \
        --network-interface="network=$NETWORK,subnet=$SUBNET,address=$EXTERNAL_IP" \
        --tags=plane-server \
        --boot-disk-size="$BOOT_DISK_SIZE" \
        --boot-disk-type="$BOOT_DISK_TYPE" \
        --image-family=ubuntu-2404-lts-amd64 \
        --image-project=ubuntu-os-cloud \
        --scopes=cloud-platform
    log "  VM created. Waiting 45s for boot..."
    sleep 45
else
    log "  VM already exists."
fi

# ---------------------------------------------------------------------------
log "Step 6/8 — Generating environment files..."

SECRET_KEY=$(openssl rand -hex 25)
RMQ_PASS=$(openssl rand -hex 16)
MINIO_KEY=$(openssl rand -hex 16)
MINIO_SECRET=$(openssl rand -hex 32)
LIVE_KEY=$(openssl rand -hex 16)

# Root .env (docker-compose infra services)
cat > /tmp/plane-root.env << EOF
POSTGRES_USER=plane
POSTGRES_PASSWORD=${PG_PASS}
POSTGRES_DB=plane

REDIS_HOST=${REDIS_IP}
REDIS_PORT=6379

RABBITMQ_HOST=plane-mq
RABBITMQ_PORT=5672
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=${RMQ_PASS}
RABBITMQ_VHOST=plane

LISTEN_HTTP_PORT=80
LISTEN_HTTPS_PORT=443

AWS_REGION=
AWS_ACCESS_KEY_ID=${MINIO_KEY}
AWS_SECRET_ACCESS_KEY=${MINIO_SECRET}
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
FILE_SIZE_LIMIT=5242880

USE_MINIO=1

SITE_ADDRESS=:80
CERT_EMAIL=
CERT_ACME_CA=https://acme-v02.api.letsencrypt.org/directory
TRUSTED_PROXIES=0.0.0.0/0
CERT_ACME_DNS=
MINIO_ENDPOINT_SSL=0
API_KEY_RATE_LIMIT=60/minute
EOF

# API .env (api, worker, beat-worker, migrator)
cat > /tmp/plane-api.env << EOF
DEBUG=0
CORS_ALLOWED_ORIGINS=http://${EXTERNAL_IP}

POSTGRES_USER=plane
POSTGRES_PASSWORD=${PG_PASS}
POSTGRES_HOST=${CLOUD_SQL_IP}
POSTGRES_DB=plane
POSTGRES_PORT=5432
DATABASE_URL=postgresql://plane:${PG_PASS}@${CLOUD_SQL_IP}:5432/plane

REDIS_HOST=${REDIS_IP}
REDIS_PORT=6379
REDIS_URL=redis://${REDIS_IP}:6379/

RABBITMQ_HOST=plane-mq
RABBITMQ_PORT=5672
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=${RMQ_PASS}
RABBITMQ_VHOST=plane

AWS_REGION=
AWS_ACCESS_KEY_ID=${MINIO_KEY}
AWS_SECRET_ACCESS_KEY=${MINIO_SECRET}
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
FILE_SIZE_LIMIT=5242880
SIGNED_URL_EXPIRATION=3600

USE_MINIO=1

WEB_URL=http://${EXTERNAL_IP}

GUNICORN_WORKERS=2

ADMIN_BASE_URL=
ADMIN_BASE_PATH=/god-mode
SPACE_BASE_URL=
SPACE_BASE_PATH=/spaces
APP_BASE_URL=
APP_BASE_PATH=
LIVE_BASE_URL=
LIVE_BASE_PATH=/live

LIVE_SERVER_SECRET_KEY=${LIVE_KEY}

HARD_DELETE_AFTER_DAYS=60
MINIO_ENDPOINT_SSL=0
API_KEY_RATE_LIMIT=60/minute

SECRET_KEY=${SECRET_KEY}
EOF

log "  Env files generated (Cloud SQL: ${CLOUD_SQL_IP}, Redis: ${REDIS_IP})"

# ---------------------------------------------------------------------------
log "Step 7/8 — Copying files to VM..."

gcloud compute scp /tmp/plane-root.env "${VM_NAME}":/tmp/plane-root.env \
    --zone="$ZONE" --project="$PROJECT_ID"
gcloud compute scp /tmp/plane-api.env "${VM_NAME}":/tmp/plane-api.env \
    --zone="$ZONE" --project="$PROJECT_ID"
gcloud compute scp "${SCRIPT_DIR}/vm-setup.sh" "${VM_NAME}":/tmp/vm-setup.sh \
    --zone="$ZONE" --project="$PROJECT_ID"
gcloud compute scp "${SCRIPT_DIR}/docker-compose.gcp.yml" "${VM_NAME}":/tmp/docker-compose.gcp.yml \
    --zone="$ZONE" --project="$PROJECT_ID"

rm -f /tmp/plane-root.env /tmp/plane-api.env

# ---------------------------------------------------------------------------
log "Step 8/8 — Running setup on VM (builds take 15-20 min)..."

gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" \
    --command="chmod +x /tmp/vm-setup.sh && sudo /tmp/vm-setup.sh '${REPO_URL}' '${REPO_BRANCH}'"

log ""
log "============================================"
log "  PLANE DEPLOYMENT COMPLETE"
log "============================================"
log ""
log "  App URL:      http://$EXTERNAL_IP"
log "  Admin Panel:  http://$EXTERNAL_IP/god-mode/"
log ""
log "  VM:           $VM_NAME ($MACHINE_TYPE, $ZONE)"
log "  Database:     Cloud SQL ignite-db -> plane"
log "  Redis:        Memorystore ignite-redis"
log "  New cost:     ~\$52/mo"
log ""
log "  SSH:     gcloud compute ssh $VM_NAME --zone=$ZONE"
log "  Logs:    gcloud compute ssh $VM_NAME --zone=$ZONE --command='cd /opt/plane && sudo docker compose -f docker-compose.gcp.yml logs -f --tail=20'"
log "  Status:  gcloud compute ssh $VM_NAME --zone=$ZONE --command='cd /opt/plane && sudo docker compose -f docker-compose.gcp.yml ps'"
log "============================================"
