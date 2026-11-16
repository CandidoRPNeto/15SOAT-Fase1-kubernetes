#!/usr/bin/env bash
# Creates (once) the per-service secret env files OUTSIDE any repo and applies
# them as Kubernetes Secrets. Re-running keeps existing values.
#   ~/.workshop-os/secrets/{rabbitmq,os,billing,execution}.env
# Mercado Pago: put MERCADOPAGO_ACCESS_TOKEN=TEST-... in billing.env (or export
# it before the first run). Without it Billing uses PAYMENT_GATEWAY=offline.
# Usage: KUBECONFIG=~/.kube/workshop-os-config scripts/bootstrap-secrets.sh
set -euo pipefail
dir="${WORKSHOP_SECRETS_DIR:-$HOME/.workshop-os/secrets}"
mkdir -p "$dir" && chmod 700 "$dir"

rand() { openssl rand -hex 16; }
app_key() { echo "base64:$(openssl rand -base64 32)"; }
write_once() { # file, content
  [[ -f "$1" ]] && return 0
  umask 077 && printf '%s\n' "$2" > "$1" && echo "created $1"
}

write_once "$dir/rabbitmq.env" "RABBITMQ_USER=workshop
RABBITMQ_PASSWORD=$(rand)"
# shellcheck disable=SC1091
source "$dir/rabbitmq.env"

write_once "$dir/os.env" "APP_KEY=$(app_key)
DB_PASSWORD=$(rand)
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
LAMBDA_INTERNAL_API_KEY=$(rand)"

token="${MERCADOPAGO_ACCESS_TOKEN:-}"
gateway=$([[ -n "$token" ]] && echo mercadopago || echo offline)
write_once "$dir/billing.env" "APP_KEY=$(app_key)
DB_PASSWORD=$(rand)
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
PAYMENT_GATEWAY=$gateway
MERCADOPAGO_ACCESS_TOKEN=$token"

write_once "$dir/execution.env" "APP_KEY=$(app_key)
RABBITMQ_USER=$RABBITMQ_USER
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD"

apply_secret() { # namespace, name, file
  kubectl -n "$1" create secret generic "$2" --from-env-file="$3" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "applied secret $1/$2"
}
apply_secret platform rabbitmq-credentials "$dir/rabbitmq.env"
apply_secret os os-secret "$dir/os.env"
apply_secret billing billing-secret "$dir/billing.env"
apply_secret execution execution-secret "$dir/execution.env"
