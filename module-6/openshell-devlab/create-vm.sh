#!/usr/bin/env bash
# Step 1 (run locally): create a CPU VM with Docker + nebius CLI.
# Uses the project's existing subnet, or creates a network and subnet if there is none.
# Usage: PROJECT_ID=project-... REGION=eu-west2 ./create-vm.sh
set -euo pipefail
cd "$(dirname "$0")"
P="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:-eu-west2}"
PRESET="${PRESET:-2vcpu-8gb}"   # tenant vCPU quota is tight; use 4vcpu-16gb if available
KEY_FILE="${SSH_KEY_FILE:-$HOME/.ssh/id_ed25519.pub}"
id() { jq -r .metadata.id; }

SUBNET=$(nebius vpc subnet list --parent-id "$P" --format json | jq -r '.items[0].metadata.id // empty')
if [[ -z "$SUBNET" ]]; then
  NET=$(nebius vpc network create --parent-id "$P" --name devlab-build-net --format json | id)
  SUBNET=$(nebius vpc subnet create --parent-id "$P" --name devlab-build-subnet --network-id "$NET" --format json | id)
fi
IMAGE_ID=$(nebius compute image list-public --region "$REGION" --format json \
  | jq -r '[.items[] | select(.metadata.name | test("^ubuntu24.04-driverless\\.[0-9]"))][0].metadata.id')
DISK=$(nebius compute disk create --parent-id "$P" --name devlab-build-boot --type network_ssd \
  --size-gibibytes 100 --source-image-id "$IMAGE_ID" --format json | id)
CI=$(sed "s|SSH_PUBLIC_KEY|$(cat "$KEY_FILE")|" cloud-init.yaml)

nebius compute instance create --parent-id "$P" --name devlab-build-vm \
  --resources-platform cpu-d3 --resources-preset "$PRESET" \
  --boot-disk-existing-disk-id "$DISK" --boot-disk-attach-mode read_write \
  --network-interfaces "[{\"name\":\"eth0\",\"subnet_id\":\"$SUBNET\",\"ip_address\":{},\"public_ip_address\":{}}]" \
  --cloud-init-user-data "$CI" --format json \
  | jq -r '"VM ready: ssh ubuntu@" + (.status.network_interfaces[0].public_ip_address.address | split("/")[0])'
