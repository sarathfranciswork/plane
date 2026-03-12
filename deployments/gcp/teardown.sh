#!/bin/bash
set -euo pipefail

# Teardown Plane GCP deployment (VM + firewall + IP only)
# Does NOT delete the plane database from Cloud SQL (preserves data)

PROJECT_ID="innovation-labs-489916"
REGION="us-central1"
ZONE="us-central1-a"
VM_NAME="plane-server"
STATIC_IP_NAME="plane-external-ip"

echo "WARNING: This will destroy the Plane VM and release the IP."
echo "The 'plane' database on Cloud SQL will NOT be deleted."
echo ""
echo "Resources to delete:"
echo "  - VM: $VM_NAME (all container data lost)"
echo "  - Static IP: $STATIC_IP_NAME"
echo "  - Firewall: plane-allow-http, plane-allow-https, plane-allow-ssh"
echo ""
read -p "Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo "Deleting VM..."
gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" --quiet 2>/dev/null || true

echo "Releasing static IP..."
gcloud compute addresses delete "$STATIC_IP_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null || true

echo "Deleting firewall rules..."
for rule in plane-allow-http plane-allow-https plane-allow-ssh; do
    gcloud compute firewall-rules delete "$rule" --project="$PROJECT_ID" --quiet 2>/dev/null || true
done

echo ""
echo "Plane VM infrastructure removed."
echo "Database 'plane' still exists on ignite-db. To remove:"
echo "  gcloud sql databases delete plane --instance=ignite-db --project=$PROJECT_ID"
