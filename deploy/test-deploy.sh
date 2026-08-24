#!/bin/bash

# Builds images, pushes them to Artifact Registry, syncs compose files +
# configs to the VM, then (re)starts the stack via docker compose pulling
# those images by reference. Replaces the old tar/scp/docker-load flow.
#
# Run this from the repo root (e.g. `./deploy/test-deploy.sh`) - COMPOSE_DIR
# below defaults to a path relative to your current directory.
set -e

source "$(dirname "${BASH_SOURCE[0]}")/deploy-common.sh"

# Local directory the compose files live in.
COMPOSE_DIR="${COMPOSE_DIR:-./ragsha-app}"

# Artifact Registry location - must match registry.tf's location (var.region,
# default asia-southeast1) and the ${REGION:-...} default baked into
# ragsha-app/docker-compose.yml's image: fields.
GCP_PROJECT="${GCP_PROJECT:-$PROJECT}"
REGION="${REGION:-asia-southeast1}"
REGISTRY_HOST="${REGION}-docker.pkg.dev"

# Identity that has roles/artifactregistry.writer on the repo (see
# registry.tf) - same deployer SA Terraform itself impersonates (main.tf).
DEPLOYER_SA="${DEPLOYER_SA:-c0001-uat-terraform-deployer@c0001-uat.iam.gserviceaccount.com}"

for f in "${COMPOSE_FILES[@]}"; do
  if [ ! -f "$COMPOSE_DIR/$f" ]; then
    echo "ERROR: compose file $COMPOSE_DIR/$f not found."
    exit 1
  fi
done

# Set SKIP_BUILD=1 to reuse whatever's already pushed to Artifact Registry
# instead of rebuilding/re-pushing - e.g. to test the pull/sync/restart path
# on its own against images built manually earlier.
SKIP_BUILD="${SKIP_BUILD:-}"
if [ -z "$SKIP_BUILD" ]; then
  echo "==> 1/5 Building and pushing images to Artifact Registry"
  gcloud auth print-access-token --impersonate-service-account="$DEPLOYER_SA" \
    | docker login -u oauth2accesstoken --password-stdin "https://$REGISTRY_HOST"
  # Only docker-compose.yml (not the observability overlay) has build:/our
  # image: fields - loki/prometheus/alloy/grafana are public images we don't
  # build or push.
  (cd "$COMPOSE_DIR" && GCP_PROJECT="$GCP_PROJECT" REGION="$REGION" IMAGE_TAG="${IMAGE_TAG:-latest}" \
    docker compose -f docker-compose.yml build)
  (cd "$COMPOSE_DIR" && GCP_PROJECT="$GCP_PROJECT" REGION="$REGION" IMAGE_TAG="${IMAGE_TAG:-latest}" \
    docker compose -f docker-compose.yml push)
else
  echo "==> 1/5 Skipping build/push (SKIP_BUILD set) - reusing images already in Artifact Registry"
fi

echo "==> 2/5 Copying project directory (compose files + everything they reference - configs, env files, etc.) to $VM_NAME:$REMOTE_DIR"
gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" --command="mkdir -p $REMOTE_DIR"

# Remove stale remote copies of exactly what we're about to sync from local,
# so a previous docker-auto-created wrong-type artifact (e.g. a directory
# where observability/prometheus.yml, a file, belongs) gets fully replaced
# instead of merged/colliding with it. `scp --recurse` won't do this itself -
# it merges into existing directories rather than replacing them. Anything
# NOT present locally (e.g. a data/ persistent volume) is left untouched.
#
# Each path is shell-quoted individually (printf %q) rather than joined by
# naive string concatenation, so a name with a space or shell metacharacter
# can't break the remote command. Falls back to a no-op ("true") instead of
# a bare `rm -rf` if there's nothing to remove.
REMOVE_LIST=()
for entry in "$COMPOSE_DIR"/*; do
  REMOVE_LIST+=("$REMOTE_DIR/$(basename "$entry")")
done

REMOVE_CMD="true"
if [ "${#REMOVE_LIST[@]}" -gt 0 ]; then
  REMOVE_ARGS=""
  for path in "${REMOVE_LIST[@]}"; do
    REMOVE_ARGS+=" $(printf '%q' "$path")"
  done
  REMOVE_CMD="sudo rm -rf --$REMOVE_ARGS"
fi

gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" \
  --command="$REMOVE_CMD && sudo chown -R \$(whoami):\$(whoami) $REMOTE_DIR"

for entry in "$COMPOSE_DIR"/*; do
  if [ -d "$entry" ]; then
    gcloud compute scp --recurse "$entry" "$VM_NAME":"$REMOTE_DIR"/ "${SSH_ARGS[@]}"
  else
    gcloud compute scp "$entry" "$VM_NAME":"$REMOTE_DIR"/ "${SSH_ARGS[@]}"
  fi
done

echo "==> 3/5 Pulling images on the VM"
gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" \
  --command="cd $REMOTE_DIR && sudo docker compose $COMPOSE_F_FLAGS pull"

echo "==> 4/5 (Re)starting the stack via docker compose"
# `down` first - a container that failed to start on a previous run can be
# reused as-is by a plain `up -d` instead of recreated, carrying over
# whatever broken state caused the original failure.
gcloud compute ssh "$VM_NAME" "${SSH_ARGS[@]}" \
  --command="cd $REMOTE_DIR && sudo docker compose $COMPOSE_F_FLAGS down --remove-orphans; sudo docker compose $COMPOSE_F_FLAGS up -d"

echo "==> 5/5 Checking it responds on the VM"
check_stack_responds

echo "==> Done. To view it yourself, open an IAP tunnel:"
echo "    gcloud compute start-iap-tunnel $VM_NAME 8080 --local-host-port=localhost:8080 ${SSH_ARGS[@]}"
echo "    then browse http://localhost:8080"
