#!/usr/bin/env bash
# kind nodes cannot resolve registry DNS (see 15SOAT-Fase1 memory/gotchas), so
# every third-party image is pulled on the host and side-loaded into kind.
# Usage: scripts/load-images.sh [extra-image ...]
set -euo pipefail
cluster="${KIND_CLUSTER:-workshop-os}"
images=(traefik:v3.1 rabbitmq:3.13-management postgres:16-alpine mongo:7 "$@")
for image in "${images[@]}"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull -q "$image"
  kind load docker-image "$image" --name "$cluster" >/dev/null
  echo "loaded $image"
done
