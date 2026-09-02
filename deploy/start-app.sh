#!/bin/bash

# Starts the VM (if stopped) and brings the stack back up without
# re-transferring anything. Use test-deploy.sh instead if you have new
# images/config to push.
set -e

source "$(dirname "${BASH_SOURCE[0]}")/deploy-common.sh"

echo "==> 1/3 Starting the VM (no-op if it's already running)"
gcloud compute instances start "$VM_NAME" \
  --zone="$ZONE" --project="$PROJECT" \
  --impersonate-service-account="$DEPLOYER_SA"

echo "==> 2/3 Starting the stack via docker compose"
# sshd may not be up yet right after `instances start` - retry briefly.
started=false
for i in $(seq 1 10); do
  if gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" \
       --command="cd $REMOTE_DIR && sudo docker compose $COMPOSE_F_FLAGS up -d" 2>/dev/null; then
    started=true
    break
  fi
  echo "    VM not ready yet, retrying in 10s... ($i/10)"
  sleep 10
done
if [ "$started" != "true" ]; then
  echo "ERROR: could not reach the VM after 10 attempts. Check it actually started:"
  echo "    gcloud compute instances describe $VM_NAME --zone=$ZONE --project=$PROJECT --format='get(status)'"
  exit 1
fi

echo "==> 3/3 Checking it responds on the VM"
check_stack_responds

echo "==> Done."
echo "    If the LB forwarding rules were also torn down to save cost,"
echo "    run 'terraform apply' too before the public URLs will work again -"
echo "    this script only brings the VM/containers back, not the LB."
