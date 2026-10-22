#!/usr/bin/env bash
# Run LOCALLY after creating the VM in the UI. Prepares the VM so that ./demo.sh can be run on it:
# installs tools, creates the service account, puts its credentials on the VM, copies this folder.
# Usage: PROJECT_ID=... TENANT_ID=... VM=<vm-ip> [TAG=0.1.1-1] [REGION=eu-west2] [VM_USER=ubuntu] ./prepare-vm.sh
set -euo pipefail
cd "$(dirname "$0")"

VM="${VM:?set VM (public IP)}"
VM_USER="${VM_USER:-ubuntu}"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
TENANT_ID="${TENANT_ID:?set TENANT_ID}"
TAG="${TAG:-0.1.1-1}"   # never reuse a pushed tag
REGION="${REGION:-eu-west2}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30)
for c in nebius jq rsync ssh; do command -v "$c" >/dev/null || { echo "missing locally: $c" >&2; exit 1; }; done

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
vm() { ssh "${SSH_OPTS[@]}" "$VM_USER@$VM" "$@"; }

step "1/3 Install Docker, rsync, jq on the VM"
vm 'set -e
cloud-init status --wait >/dev/null 2>&1 || true   # fresh VM: wait for first-boot apt jobs
APT="sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300"
$APT update -qq
$APT install -y -qq docker.io docker-buildx rsync jq curl openssl
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"'

step "2/3 Service account and credentials (private key is generated on the VM and stays there)"
SA=$(nebius iam service-account create --parent-id "$PROJECT_ID" --name devlab-build-sa --format json | jq -r .metadata.id)
G=$(nebius iam group create --parent-id "$PROJECT_ID" --name devlab-build-group --format json | jq -r .metadata.id)
nebius iam group-membership create --parent-id "$G" --member-id "$SA" >/dev/null
nebius iam access-permit create --parent-id "$G" --resource-id "$PROJECT_ID" --role editor >/dev/null

vm 'umask 077; mkdir -p ~/.nebius-sa && cd ~/.nebius-sa &&
  openssl genrsa -out private.pem 4096 2>/dev/null && openssl rsa -in private.pem -pubout -out public.pem 2>/dev/null && cat public.pem' > sa-public.pem
KID=$(nebius iam auth-public-key create --parent-id "$PROJECT_ID" --account-service-account-id "$SA" \
  --data "$(cat sa-public.pem)" --format json | jq -r .metadata.id)
rm -f sa-public.pem

vm "cd ~/.nebius-sa; umask 077
jq -n --arg sa $SA --arg kid $KID --rawfile pk private.pem \
  '{\"subject-credentials\":{\"type\":\"JWT\",\"alg\":\"RS256\",\"private-key\":\$pk,\"kid\":\$kid,\"iss\":\$sa,\"sub\":\$sa}}' > credentials.json"

step "3/3 Copy the code and settings to the VM"
rsync -az -e "ssh ${SSH_OPTS[*]}" --exclude .ipynb_checkpoints --exclude __pycache__ ./ "$VM_USER@$VM:~/openshell-devlab/"
vm "cat > ~/openshell-devlab/demo.env" <<EOF
export PROJECT_ID=$PROJECT_ID
export TENANT_ID=$TENANT_ID
export TAG=$TAG
export REGION=$REGION
EOF
vm "chmod +x ~/openshell-devlab/*.sh"

cat <<EOF

Ready. Service account: $SA   group: $G   key: $KID   (needed for Cleanup)
Now log in and run the demo:

  ssh $VM_USER@$VM
  cd openshell-devlab && ./demo.sh
EOF
