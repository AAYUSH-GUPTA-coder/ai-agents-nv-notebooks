# Build and push the OpenShell Devlab image (Nebius)

Steps 1-4 run from a terminal in `openshell-devlab/`; step 5 (create the Devlab) is done in the UI.

```bash
export PROJECT_ID=<project-id>   # project-...
export TENANT_ID=<tenant-id>     # tenant-...
export REGION=<region>           # region of your project, e.g. eu-west2
export TAG=0.1.1-1               # never reuse a pushed tag
```

Where to find the values:

| Value | Console | CLI |
|---|---|---|
| `TENANT_ID` | organization menu | `nebius iam tenant list` |
| `PROJECT_ID` | project switcher / project settings | `nebius iam project list --parent-id $TENANT_ID` |
| `REGION` | project settings (the region your project lives in) | - |
| `<registry-id>` (step 4) | Container Registry page | printed as `The push refers to repository ...` in `~/push.log` |

If a `nebius` profile is already set up, `nebius config list` shows its `parent-id` and `tenant-id`.
The scripts default to `eu-west2`; if your project is in another region, change `REGION` in
`create-vm.sh`, `REGISTRY_FQDN` in `registry-build-push.sh` and the storage host in `cloud-init.yaml`,
or pass `REGION=...` and `REGISTRY_FQDN=cr.<region>.nebius.cloud` when running them.

## 1. Create the VM (local)

```bash
VM=$(PROJECT_ID=$PROJECT_ID REGION=$REGION ./create-vm.sh | sed -n 's/.*ubuntu@//p')
ssh ubuntu@$VM 'cloud-init status --wait && docker --version'
```

`cpu-d3`, `2vcpu-8gb` (override with `PRESET=4vcpu-16gb`), 100 GiB disk, Ubuntu 24.04, public IP.
`cloud-init.yaml` installs Docker, buildx, rsync, jq and the nebius CLI, and adds your SSH key.
The VM is billed while it runs. If the IP changes after a restart, run `ssh-keygen -R <ip>`.

## 2. Service account for the VM (local)

```bash
SA=$(nebius iam service-account create --parent-id $PROJECT_ID --name devlab-build-sa --format json | jq -r .metadata.id)
G=$(nebius iam group create --parent-id $PROJECT_ID --name devlab-build-group --format json | jq -r .metadata.id)
nebius iam group-membership create --parent-id $G --member-id $SA
nebius iam access-permit create --parent-id $G --resource-id $PROJECT_ID --role editor
```

## 3. Credentials on the VM

The private key is generated on the VM and never leaves it.

```bash
ssh ubuntu@$VM 'umask 077; mkdir -p ~/.nebius-sa && cd ~/.nebius-sa &&
  openssl genrsa -out private.pem 4096 && openssl rsa -in private.pem -pubout -out public.pem && cat public.pem' > sa-public.pem
KID=$(nebius iam auth-public-key create --parent-id $PROJECT_ID --account-service-account-id $SA \
  --data "$(cat sa-public.pem)" --format json | jq -r .metadata.id)

ssh ubuntu@$VM "export PATH=\$HOME/.nebius/bin:\$PATH; cd ~/.nebius-sa; umask 077
jq -n --arg sa $SA --arg kid $KID --rawfile pk private.pem \
  '{\"subject-credentials\":{\"type\":\"JWT\",\"alg\":\"RS256\",\"private-key\":\$pk,\"kid\":\$kid,\"iss\":\$sa,\"sub\":\$sa}}' > credentials.json
nebius profile create -p default --endpoint api.nebius.cloud --service-account-file ~/.nebius-sa/credentials.json \
  --parent-id $PROJECT_ID --tenant-id $TENANT_ID </dev/null && nebius iam whoami"
```

`whoami` must show the service account. Never copy your personal IAM token to the VM.

## 4. Build and push (on the VM)

```bash
rsync -az --exclude .ipynb_checkpoints --exclude __pycache__ ./ ubuntu@$VM:~/openshell-devlab/
ssh ubuntu@$VM "cd ~/openshell-devlab && chmod +x *.sh &&
  PROJECT_ID=$PROJECT_ID TAG=$TAG nohup ./registry-build-push.sh > ~/push.log 2>&1 </dev/null &"
ssh ubuntu@$VM 'tail -f ~/push.log'      # last lines show the digest
```

The script creates the `openshell-devlab` registry if missing, logs in, builds `linux/amd64` and pushes.
Run it once: a concurrent second run fails with `image ... already exists`.

Image reference (prefer the digest):

```
cr.eu-west2.nebius.cloud/<registry-id without "registry-">/openshell-devlab:0.1.1-1
cr.eu-west2.nebius.cloud/<registry-id without "registry-">/openshell-devlab@sha256:<digest>
```

## 5. Create the Devlab (UI)

| Field | Value |
|---|---|
| Image | reference from step 4 |
| Container port / primary route port | `8888` / `8888` |
| Workspace path | `/workspace` |
| Platform / preset / disk | `cpu-d3` / at least `2vcpu-8gb` / 100 GiB or more |
| Public endpoint | on |

Environment variables (Name = name only, Value = value only):

- `JUPYTER_TOKEN` (required): 16 letters and digits. Without it the container exits with
  `JUPYTER_TOKEN is required; refusing to start an unauthenticated application`.
- `TOFA_API_KEY`, `TAVILY_API_KEY`: needed for research, not for starting Jupyter.

Plain env values are visible to anyone with access to the Devlab; use MysteryBox secrets to hide them.
They cannot be edited after creation; recreate the Devlab to change them.

Jupyter URL: `<public endpoint>/?token=<JUPYTER_TOKEN>`.

## Troubleshooting

```bash
nebius ai devlab logs <devlab-id> --tail 50
```

- `no healthy upstream`: nothing listens on the routed port; check the logs and port `8888`.
- Healthy start: logs contain `OpenShell runtime is ready` and JupyterLab lines.
- Test the image on the VM: `docker run --privileged -p 8888:8888 -e JUPYTER_TOKEN=... <image-reference>`
  (needs nested Docker and Landlock, so it will not start on Docker Desktop for macOS).

## Cleanup (VM and disk cost money)

```bash
nebius ai devlab delete --id <devlab-id>
nebius compute instance delete --id <instance-id>
nebius compute disk delete --id <disk-id>
nebius iam auth-public-key delete --id $KID
nebius iam group delete --id $G
nebius iam service-account delete --id $SA
```

Keep the registry while the image is in use.
