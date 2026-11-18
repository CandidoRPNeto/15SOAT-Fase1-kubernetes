#!/usr/bin/env bash
# Brings up the shared platform on the local kind cluster: namespaces,
# Traefik (+ForwardAuth), RabbitMQ, OTel Collector + Jaeger, Datadog Agent and
# every service Secret. Runs on every push to main (CI job `deploy`).
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
kubectl -n platform rollout status deployment/jaeger deployment/trace-agent --timeout=120s
if kubectl -n platform get secret datadog-credentials >/dev/null 2>&1; then
  kubectl -n platform rollout status daemonset/datadog-agent --timeout=180s
fi
