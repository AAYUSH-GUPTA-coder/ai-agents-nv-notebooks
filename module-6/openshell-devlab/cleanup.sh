#!/usr/bin/env bash
# Run LOCALLY after the demo. Deletes everything the demo created, found by name (no IDs to save):
# Devlabs that use the openshell-devlab registry, the registry with its images, service account
# devlab-build-sa with its keys, group devlab-build-group, and the VM with this public IP (if VM is set).
# Usage: PROJECT_ID=... [VM=<vm-ip>] [YES=1] ./cleanup.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
export PATH="$HOME/.nebius/bin:$PATH"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
by_name() { jq -r --arg n "$1" '.items[]? | select(.metadata.name == $n) | .metadata.id'; }

REG=$(nebius registry list --parent-id "$PROJECT_ID" --format json | by_name openshell-devlab)
IMAGES="" DEVLABS=""
if [[ -n "$REG" ]]; then
  # tagged indexes first: a child manifest cannot be deleted while its index exists
  IMAGES=$(nebius registry image list --parent-id "$REG" --format json | jq -r '[.items[]?] | sort_by((.tags // []) | length) | reverse | .[].id')
  DEVLABS=$(nebius ai devlab list --parent-id "$PROJECT_ID" --format json \
    | jq -r --arg r "/${REG#registry-}/openshell-devlab" '.items[]? | select(.spec | tostring | contains($r)) | .metadata.id')
fi

SA=$(nebius iam service-account list --parent-id "$PROJECT_ID" --format json | by_name devlab-build-sa)
G=$(nebius iam group list --parent-id "$PROJECT_ID" --format json | by_name devlab-build-group)
KEYS=""
[[ -z "$SA" ]] || KEYS=$(nebius iam auth-public-key list --parent-id "$PROJECT_ID" --format json \
  | jq -r --arg sa "$SA" '.items[]? | select(.spec.account.service_account.id == $sa) | .metadata.id')

INSTANCE=""
if [[ -n "${VM:-}" ]]; then
  INSTANCE=$(nebius compute instance list --parent-id "$PROJECT_ID" --format json \
    | jq -r --arg ip "$VM" '.items[]? | select(any(.status.network_interfaces[]?; (.public_ip_address.address // "") | startswith($ip + "/"))) | .metadata.id')
  [[ -n "$INSTANCE" ]] || echo "warning: no VM with public IP $VM in the project" >&2
fi

list() { echo "  $1 ${2:-none}" | tr '\n' ' '; echo; }
echo "Will delete in $PROJECT_ID:"
list "devlabs:        " "$DEVLABS"
list "registry:       " "$REG"
list "images:         " "$IMAGES"
list "VM:             " "$INSTANCE"
list "public keys:    " "$KEYS"
list "group:          " "$G"
list "service account:" "$SA"
if [[ "${YES:-}" != 1 ]]; then
  read -r -p "Proceed? [y/N] " a; [[ "$a" == [yY] ]] || { echo aborted; exit 1; }
fi

step "Cleanup"
for d in $DEVLABS; do nebius ai devlab delete --id "$d"; done
for i in $IMAGES; do nebius registry image delete --id "$i"; done
[[ -z "$REG" ]] || nebius registry delete --id "$REG"
[[ -z "$INSTANCE" ]] || nebius compute instance delete --id "$INSTANCE"   # its boot disk is deleted with it
for k in $KEYS; do nebius iam auth-public-key delete --id "$k"; done
[[ -z "$G" ]] || nebius iam group delete --id "$G"
[[ -z "$SA" ]] || nebius iam service-account delete --id "$SA"
echo "Done."
