#!/usr/bin/env bash
# Step 3 (run ON THE VM): create the registry, log in, build and push.
# Usage: PROJECT_ID=project-... TAG=0.1.1-1 ./registry-build-push.sh
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.nebius/bin:$PATH"
P="${PROJECT_ID:?set PROJECT_ID}"
TAG="${TAG:-0.1.1-1}"
REGION_FQDN="${REGISTRY_FQDN:-cr.eu-west2.nebius.cloud}"

# Reuse the registry if it already exists, otherwise create it.
REG=$(nebius registry get-by-name --parent-id "$P" --name openshell-devlab --format json 2>/dev/null | jq -r .metadata.id || true)
if [[ -z "$REG" || "$REG" == null ]]; then
  REG=$(nebius registry create --parent-id "$P" --name openshell-devlab --format json | jq -r .metadata.id)
fi

nebius iam get-access-token | docker login "$REGION_FQDN" --username iam --password-stdin
IMAGE="$REGION_FQDN/${REG#registry-}/openshell-devlab" TAG="$TAG" ./build-and-push.sh push
