#!/usr/bin/env bash
# Build the OpenShell Devlab image locally and (optionally) push it to a registry.
#
#   ./build-and-push.sh build                      # local build only
#   IMAGE=cr.<region>.nebius.cloud/<registry-id>/openshell-devlab TAG=0.1.1-1 ./build-and-push.sh push
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-openshell-devlab}"
TAG="${TAG:-0.1.1-local}"
REF="$IMAGE:$TAG"

case "${1:-build}" in
  build)
    docker buildx build --platform linux/amd64 --load -t "$REF" .
    ;;
  push)
    [[ "$IMAGE" == */* ]] || { echo "Set IMAGE to the full registry path, e.g. cr.<region>.nebius.cloud/<registry-id>/openshell-devlab" >&2; exit 1; }
    docker buildx build --platform linux/amd64 --load -t "$REF" .
    # Log in beforehand, e.g.:
    #   nebius iam get-access-token | docker login cr.<region>.nebius.cloud --username iam --password-stdin
    docker push "$REF"
    docker buildx imagetools inspect "$REF" | grep -i '^Digest' || true
    ;;
  *)
    echo "usage: $0 [build|push]" >&2; exit 2
    ;;
esac
