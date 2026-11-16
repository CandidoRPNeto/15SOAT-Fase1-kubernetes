#!/usr/bin/env bash
# Shared helpers for the Fase 4 demo scripts. Everything goes through the
# Traefik gateway (http://localhost:30080), never straight to a service.
set -euo pipefail
GATEWAY="${GATEWAY_URL:-http://localhost:30080}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/workshop-os-config}"

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; [[ "${PAUSE:-0}" == 1 ]] && read -rp '  (enter) ' _ || true; }
ok() { printf '  \033[32m✔ %s\033[0m\n' "$*"; }
fail() { printf '  \033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

api() { # method path token [json-body]
  local method=$1 path=$2 token=$3 body=${4:-}
  curl -sS -X "$method" "$GATEWAY$path" -H 'Accept: application/json' -H 'Content-Type: application/json' \
    ${token:+-H "Authorization: Bearer $token"} ${body:+-d "$body"}
}

login() { api POST /api/v1/auth/login "" "{\"email\":\"$1\",\"password\":\"password\"}" | jq -r .token; }

order_field() { api GET "/api/v1/service-orders/$1" "$STAFF_TOKEN" | jq -r ".$2"; }

wait_status() { # order_id expected [timeout_s]
  local deadline=$((SECONDS + ${3:-30})) status
  while (( SECONDS < deadline )); do
    status="$(order_field "$1" status)"
    [[ "$status" == "$2" ]] && { ok "OS $1 → $2"; return 0; }
    sleep 1
  done
  fail "OS $1 stuck in '$status' (expected '$2')"
}

show_history() {
  api GET "/api/v1/service-orders/$1/history" "$STAFF_TOKEN" \
    | jq -r '"saga: \(.saga.status) \(.saga.failure_reason // "")", (.saga.steps[] | "  step \(.name): \(.status) (tentativas \(.attempts))"), (.status_history[] | "  \(.from // "-") → \(.to): \(.reason)")'
}

open_order() { # item_id quantity → prints order id
  api POST /api/v1/service-orders "$STAFF_TOKEN" \
    "{\"client_id\":$CLIENT_ID,\"vehicle_id\":$VEHICLE_ID,\"notes\":\"Barulho ao frear\",\"items\":[{\"item_id\":$1,\"quantity\":$2}]}" | jq -r .id
}

bootstrap_actors() {
  RECEPTION_TOKEN="$(login recepcao@workshop.com)"
  MECHANIC_TOKEN="$(login mecanico@workshop.com)"
  CLIENT_TOKEN="$(login carlos@example.com)"
  STAFF_TOKEN="$RECEPTION_TOKEN"
  CLIENT_ID="$(api GET /api/v1/auth/me "$CLIENT_TOKEN" | jq -r .id)"
  VEHICLE_ID="$(api GET "/api/v1/vehicles?client_id=$CLIENT_ID" "$STAFF_TOKEN" | jq -r '.data[0].id')"
  [[ "$VEHICLE_ID" != null ]] || fail "client $CLIENT_ID has no vehicle (seed the OS database)"
  ok "tokens for recepção, mecânico e cliente (id $CLIENT_ID, veículo $VEHICLE_ID)"
}

item_with_stock_at_least() { # min_stock → prints "id stock name"
  api GET /api/v1/items "$STAFF_TOKEN" | jq -r --argjson min "$1" '[.data[] | select(.stock_quantity >= $min)][0] | "\(.id) \(.stock_quantity) \(.name)"'
}
