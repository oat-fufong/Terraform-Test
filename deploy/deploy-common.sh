#!/bin/bash
# Shared config, defaults, and helpers for start-app.sh and test-deploy.sh.
# Sourced by both - not meant to be run directly.

VM_NAME="${VM_NAME:-terraform-instance}"
ZONE="${ZONE:-asia-southeast1-a}"
PROJECT="${PROJECT:-c0001-uat}"

# Identity Terraform impersonates (main.tf) - reused here for image pushes
# and starting/stopping the VM.
DEPLOYER_SA="${DEPLOYER_SA:-c0001-uat-terraform-deployer@c0001-uat.iam.gserviceaccount.com}"

# Must match registry.tf's location. Kept separate from PROJECT in case the
# registry ever lives in a different project than the VM.
GCP_PROJECT="${GCP_PROJECT:-$PROJECT}"
REGION="${REGION:-asia-southeast1}"
REGISTRY_HOST="${REGION}-docker.pkg.dev"

# Local directory the compose files live in. This is a git submodule.
COMPOSE_DIR="${COMPOSE_DIR:-./ragsha-deploy}"

# Where the compose files (and everything they reference) end up on the VM.
REMOTE_DIR="${REMOTE_DIR:-~/ragsha-deploy}"
COMPOSE_FILES=(docker-compose.yml docker-compose.observability.yml)

# Works even if the LB isn't up - checks the VM directly over the IAP tunnel.
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:4321/}"

SSH_ARGS=(--zone="$ZONE" --project="$PROJECT" --tunnel-through-iap)

COMPOSE_F_FLAGS=""
for f in "${COMPOSE_FILES[@]}"; do
  COMPOSE_F_FLAGS+=" -f $REMOTE_DIR/$(basename "$f")"
done

# Curls the VM over IAP and reports pass/fail.
check_stack_responds() {
  gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" \
    --command="curl -sf $HEALTH_CHECK_URL > /dev/null && echo 'OK: stack responded' || (echo 'FAILED: no response'; exit 1)"
}
