#!/usr/bin/env bash
# Run ON THE VM (after ./prepare-vm.sh locally): sign in with the service account, build and push the image.
# Usage: cd ~/openshell-devlab && ./demo.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./demo.env   # PROJECT_ID, TENANT_ID, TAG, REGION written by prepare-vm.sh

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

step "1/3 Install the nebius CLI"
[ -x "$HOME/.nebius/bin/nebius" ] || curl -sSL https://storage.$REGION.nebius.cloud/cli/install.sh | bash
export PATH="$HOME/.nebius/bin:$PATH"

step "2/3 Sign in as the service account"
nebius profile create -p default --endpoint api.nebius.cloud --service-account-file ~/.nebius-sa/credentials.json \
  --parent-id "$PROJECT_ID" --tenant-id "$TENANT_ID" </dev/null
nebius iam whoami

step "3/3 Build and push the image"
PROJECT_ID="$PROJECT_ID" TAG="$TAG" REGISTRY_FQDN="cr.$REGION.nebius.cloud" ./registry-build-push.sh 2>&1 | tee ~/push.log

step "Done"
grep -m1 'The push refers to repository' ~/push.log || true
grep -E 'digest: sha256:' ~/push.log | tail -1 || true
echo "Next: create the Devlab in the UI."
