# OpenShell Devlab (standalone build)

Self-contained copy of `openshell-devlab` without the monorepo-only files
(`BUILD.bazel`, tests). Contents are exactly what the `Dockerfile` needs.

## Build and push

```bash
./build-and-push.sh build        # openshell-devlab:0.1.1-local

nebius iam get-access-token | docker login cr.<region>.nebius.cloud --username iam --password-stdin
IMAGE=cr.<region>.nebius.cloud/<registry-id>/openshell-devlab TAG=0.1.1-1 ./build-and-push.sh push
```

Notes:
- Image is linux/amd64 only (OpenShell binaries are x86_64). On Apple Silicon it builds under emulation.
- The image runs a nested Docker daemon and needs a host kernel with Landlock; it will not start on Docker Desktop for macOS. Run it in a Devlab / Linux VM.
- Never reuse a pushed tag; use a new TAG per revision.

## Runtime inputs (set in the Devlab template)

- Port `8888` (JupyterLab), persistent volume at `/workspace`
- `JUPYTER_TOKEN`, `TOFA_API_KEY`, `TAVILY_API_KEY` (secrets); optional `LEAD_MODEL`, `WORKER_MODEL`

See the original project README for the trust boundary, validation checklist and details.
