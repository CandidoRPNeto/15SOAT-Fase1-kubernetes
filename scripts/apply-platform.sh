#!/usr/bin/env bash
# Brings up the shared platform on the local kind cluster: namespaces,
# Traefik (+ForwardAuth), RabbitMQ and every service Secret.
# Usage: KUBECONFIG=~/.kube/workshop-os-config scripts/apply-platform.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
"$here/load-images.sh"
kubectl apply -f "$here/../k8s/platform/namespaces.yaml"
"$here/bootstrap-secrets.sh"
kubectl apply -k "$here/../k8s/platform"
# Traefik only re-reads the file provider on start; restart picks up ConfigMap edits.
kubectl -n traefik rollout restart deployment/traefik
kubectl -n traefik rollout status deployment/traefik --timeout=120s
kubectl -n platform rollout status statefulset/rabbitmq --timeout=300s
