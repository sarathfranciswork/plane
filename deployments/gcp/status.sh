#!/bin/bash
# Check status of Plane GCP deployment

PROJECT_ID="innovation-labs-489916"
ZONE="us-central1-a"
REGION="us-central1"
VM_NAME="plane-server"
STATIC_IP_NAME="plane-external-ip"

echo "=== Plane GCP Deployment Status ==="
echo ""

EXTERNAL_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(address)" 2>/dev/null || echo "not reserved")

echo "--- Infrastructure ---"
echo "  VM:       $(gcloud compute instances describe $VM_NAME --zone=$ZONE --project=$PROJECT_ID --format='value(status)' 2>/dev/null || echo 'NOT FOUND')"
echo "  IP:       $EXTERNAL_IP"
echo "  App:      http://$EXTERNAL_IP"
echo "  Admin:    http://$EXTERNAL_IP/god-mode/"
echo "  DB:       Cloud SQL ignite-db (10.6.0.3)"
echo "  Redis:    Memorystore ignite-redis (10.65.46.139)"
echo ""

echo "--- Docker Services ---"
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" \
    --command="cd /opt/plane && sudo docker compose -f docker-compose.gcp.yml ps" 2>/dev/null || echo "  Cannot reach VM"

echo ""
echo "=== Done ==="
