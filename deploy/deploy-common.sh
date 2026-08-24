#!/bin/bash
# Shared config, defaults, and helpers for start-app.sh and test-deploy.sh.
# Sourced by both - not meant to be run directly.

VM_NAME="${VM_NAME:-terraform-instance}"
ZONE="${ZONE:-asia-southeast1-a}"
PROJECT="${PROJECT:-c0001-uat}"

# Where the compose files (and everything they reference) end up on the VM.
REMOTE_DIR="${REMOTE_DIR:-~/ragsha-deploy}"
COMPOSE_FILES=(docker-compose.yml docker-compose.observability.yml)

# Checks the app directly on the VM over the IAP tunnel - works regardless
# of whether the LB's forwarding rules currently exist or not.
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:4321/}"

SSH_ARGS=(--zone="$ZONE" --project="$PROJECT" --tunnel-through-iap)

COMPOSE_F_FLAGS=""
for f in "${COMPOSE_FILES[@]}"; do
  COMPOSE_F_FLAGS+=" -f $REMOTE_DIR/$(basename "$f")"
done

# Curls $HEALTH_CHECK_URL from inside the VM over the IAP tunnel and reports
# pass/fail. Last step of both start-app.sh and test-deploy.sh.
check_stack_responds() {
  gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" \
    --command="curl -sf $HEALTH_CHECK_URL > /dev/null && echo 'OK: stack responded' || (echo 'FAILED: no response'; exit 1)"
}
