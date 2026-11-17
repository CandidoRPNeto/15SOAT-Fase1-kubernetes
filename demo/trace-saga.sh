#!/usr/bin/env bash
# Rastreia uma OS pelos 3 serviços sem APM: junta os logs JSON de todos os pods
# de os/billing/execution que carregam o saga_id da OS e imprime uma linha do
# tempo única. Funciona porque todo log de saga/outbox/inbox leva `saga_id` e
# `correlation_id` no context (InboxProcessor, OutboxRelay, saga phases).
# Usage: demo/trace-saga.sh <service_order_id>      (SINCE=6h para ir mais longe)
source "$(dirname "$0")/lib.sh"

ORDER_ID="${1:?usage: demo/trace-saga.sh <service_order_id>}"
STAFF_TOKEN="$(login recepcao@workshop.com)"
SAGA_ID="$(api GET "/api/v1/service-orders/$ORDER_ID/history" "$STAFF_TOKEN" | jq -r '.saga.id // empty')"
[[ -n "$SAGA_ID" ]] || fail "OS $ORDER_ID has no saga (expected GET /history to return .saga.id)"

pod_logs() { # namespace → JSON log lines of every pod, tagged with the namespace
  local ns=$1 pod   # API pods log without dd.service, so the namespace names the service
  for pod in $(kubectl -n "$ns" get pods -o name); do
    kubectl -n "$ns" logs "$pod" --all-containers --since="${SINCE:-2h}" 2>/dev/null || true
  done | jq -cR --arg ns "$ns" 'fromjson? | objects | .service = $ns'
}

printf '\033[1;36msaga %s · OS %s\033[0m\n\n' "$SAGA_ID" "$ORDER_ID"
for ns in os billing execution; do pod_logs "$ns"; done \
  | jq -r --arg saga "$SAGA_ID" '
      select(.context.saga_id? == $saga)
      | [ .datetime[11:23],
          .service,
          .message,
          (.context.type // .context.step // ""),
          (.context.status // (if .context.to then "→ \(.context.to)" else "" end)),
          ((.context.correlation_id // "")[0:8]) ]
      | @tsv' \
  | sort \
  | column -t -s $'\t' -N 'HORA (UTC),SERVIÇO,EVENTO,TIPO/PASSO,STATUS,CORRELATION'
