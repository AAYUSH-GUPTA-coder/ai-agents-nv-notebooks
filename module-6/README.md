# Build and push the OpenShell Devlab image (Nebius)

Create a VM in the UI, build and push the image from it with two scripts, then create the Devlab in the UI.

## 1. Create the VM (UI)

`cpu-d3`, `4vcpu-16gb`, 100 GiB disk, Ubuntu 24.04, public IP, your SSH public key. The username you enter
there is `VM_USER`. The VM is billed while it runs; if its IP changes after a restart, run `ssh-keygen -R <ip>`.

## 2. Prepare (local) and build (on the VM)

```bash
export PROJECT_ID=<project-id>   # nebius iam project list --parent-id $TENANT_ID
export TENANT_ID=<tenant-id>     # nebius iam tenant list
export REGION=<region>           # region of your project, e.g. eu-west2
export TAG=0.1.1-1               # never reuse a pushed tag
export VM=<vm-public-ip>
export VM_USER=<ui-username>

cd openshell-devlab
./prepare-vm.sh                  # local: install tools on the VM, create the service account, copy the code
ssh $VM_USER@$VM
cd openshell-devlab && ./demo.sh # on the VM: sign in as the service account, build and push the image
```

- `prepare-vm.sh` creates the service account `devlab-build-sa` (editor on the project). The private key is
  generated on the VM and never leaves it; only the public key is registered. Never copy your personal IAM token to the VM.
- `demo.sh` shows `whoami` (must be the service account), creates the `openshell-devlab` registry if missing,
  builds `linux/amd64` and pushes. The last lines show the digest.
- Not idempotent: run Cleanup before a rerun. A concurrent second build fails with `image ... already exists`.

Image reference (prefer the digest):

```
cr.<region>.nebius.cloud/<registry-id without "registry-">/openshell-devlab:<TAG>
cr.<region>.nebius.cloud/<registry-id without "registry-">/openshell-devlab@sha256:<digest>
```

## 3. Create the Devlab (UI)

| Field | Value |
|---|---|
| Image | reference from step 2 |
| Container port / primary route port | `8888` / `8888` |
| Workspace path | `/workspace` |
| Platform / preset / disk | `cpu-d3` / `4vcpu-16gb` / 100 GiB or more |
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
VM=$VM ./cleanup.sh   # lists what it will delete and asks for confirmation (YES=1 skips it)
```

Deletes everything from this guide, found by name: Devlabs that use the `openshell-devlab` registry, the registry
with its images, the service account with its keys, the group, and the VM with its boot disk (by `VM` IP).
After it the image is gone, so a Devlab cannot be created until you build again (any `TAG` works).
