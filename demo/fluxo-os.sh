#!/usr/bin/env bash
# Fluxo completo de uma OS em 4 comandos, um por etapa da saga, para o vídeo.
# Cada comando vira UM trace no Jaeger (span raiz "fluxo-os: <etapa>") e
# imprime o link dele; as mensagens aparecem no RabbitMQ e os logs no
# demo/trace-saga.sh. A última OS fica salva, então o id é opcional.
#
#   bash demo/fluxo-os.sh abrir                 recepção abre a OS            → OS + saga
#   bash demo/fluxo-os.sh diagnosticar [id]     mecânico diagnostica          → Billing cria o orçamento
#   bash demo/fluxo-os.sh aprovar [id]          cliente aprova; reparo feito  → Billing gera o checkout
#   bash demo/fluxo-os.sh entregar [id]         confirma pagamento; entrega   → saga concluída
#   bash demo/fluxo-os.sh compensar             falha: falta estoque na aprovação → compensação
source "$(dirname "$0")/lib.sh"
JAEGER_UI="${JAEGER_UI:-http://localhost:16686}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/workshop-os/ultima-os"

# ---- trace da etapa ---------------------------------------------------------
trace_begin() { # name
  TRACE_ID="$(openssl rand -hex 16)"; ROOT_SPAN="$(openssl rand -hex 8)"
  TRACE_NAME="$1"; TRACE_START="$(date +%s%N)"
  export TRACEPARENT="00-$TRACE_ID-$ROOT_SPAN-01"
}

trace_end() { # envia o span raiz ao Jaeger (OTLP/HTTP) e imprime o link
  local end body
  end="$(date +%s%N)"
  body="$(jq -n --arg t "$TRACE_ID" --arg s "$ROOT_SPAN" --arg n "fluxo-os: $TRACE_NAME" \
    --arg a "$TRACE_START" --arg b "$end" --arg os "${ORDER_ID:-}" '{resourceSpans: [{
      resource: {attributes: [{key: "service.name", value: {stringValue: "terminal-demo"}}]},
      scopeSpans: [{spans: [{traceId: $t, spanId: $s, name: $n, kind: 3,
        startTimeUnixNano: $a, endTimeUnixNano: $b,
        attributes: [{key: "service_order.id", value: {stringValue: $os}}]}]}]}]}')"
  kubectl -n platform port-forward svc/jaeger 14318:4318 >/dev/null 2>&1 & local pf=$!
  sleep 1.5
  curl -s -o /dev/null -X POST localhost:14318/v1/traces -H 'Content-Type: application/json' -d "$body" || true
  kill "$pf" 2>/dev/null || true
  printf '\n  \033[1;35m🔎 Jaeger: %s/trace/%s\033[0m\n' "$JAEGER_UI" "$TRACE_ID"
}

# ---- utilidades ---------------------------------------------------------------
order_id() { # [id] → id informado ou o da última OS aberta
  local id="${1:-$(cat "$state" 2>/dev/null || true)}"
  [[ -n "$id" ]] || fail "sem OS: rode 'bash demo/fluxo-os.sh abrir' antes (ou passe o id)"
  echo "$id"
}

seed_item() { # peça do catálogo do seed (tem código); as do teste de carga não têm
  api GET /api/v1/items "$STAFF_TOKEN" \
    | jq -r '[.data[] | select(.part_number != null and .stock_quantity >= 2)][0] | "\(.id) \(.name)"'
}

saga_summary() {
  api GET "/api/v1/service-orders/$ORDER_ID/history" "$STAFF_TOKEN" \
    | jq -r '"  saga \(.saga.status) · passos: " + ([.saga.steps[] | "\(.name)=\(.status)"] | join(", "))'
}

wait_payment_approved() { # payment_id → aguarda o Billing confirmar (polling no gateway)
  for _ in $(seq 1 24); do
    [[ "$(api POST "/api/v1/payments/$1/verify" "$CLIENT_TOKEN" | jq -r .payment.status)" == approved ]] && return 0
    sleep 5
  done
  fail "pagamento $1 ainda não aprovado — pague no link do checkout e rode 'entregar' de novo"
}

# ---- etapas -------------------------------------------------------------------
abrir() {
  read -r item name <<<"$(seed_item)"
  trace_begin "1. abrir OS"
  step "Recepção abre a OS (peça: $name) → OS Service grava OS + saga + comando no outbox"
  ORDER_ID="$(open_order "$item" 1)"
  [[ "$ORDER_ID" =~ ^[0-9]+$ ]] || fail "OS não criada: $ORDER_ID"
  mkdir -p "$(dirname "$state")" && echo "$ORDER_ID" >"$state"
  wait_status "$ORDER_ID" received
  sleep 2; saga_summary
  ok "cmd.execution.enqueue_diagnosis → RabbitMQ → Execution enfileirou o diagnóstico"
  trace_end
}

diagnosticar() {
  ORDER_ID="$(order_id "${1:-}")"
  trace_begin "2. diagnosticar"
  step "Mecânico diagnostica a OS $ORDER_ID no Execution Service (MongoDB)"
  api POST "/api/v1/executions/$ORDER_ID/diagnosis/start" "$MECHANIC_TOKEN" | jq -c '{phase, status}'
  wait_status "$ORDER_ID" in_diagnosis
  api POST "/api/v1/executions/$ORDER_ID/diagnosis/finish" "$MECHANIC_TOKEN" '{"notes":"Pastilhas gastas"}' | jq -c '{phase, status}'
  wait_status "$ORDER_ID" awaiting_approval
  api GET "/api/v1/budgets?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -c '.data[0] | {orcamento: .id, status, total}'
  ok "evt.execution.diagnosis_completed → saga → cmd.billing.create_budget → Billing criou o orçamento"
  trace_end
}

aprovar() {
  ORDER_ID="$(order_id "${1:-}")"
  trace_begin "3. aprovar e reparar"
  step "Cliente aprova o orçamento no Billing → OS reserva o estoque → Execution enfileira o reparo"
  budget="$(api GET "/api/v1/budgets?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -r '.data[0].id')"
  api POST "/api/v1/budgets/$budget/approve" "$CLIENT_TOKEN" | jq -c '{status, total}'
  wait_status "$ORDER_ID" approved
  step "Mecânico executa o reparo (pivot da saga: daqui em diante não há compensação)"
  api POST "/api/v1/executions/$ORDER_ID/repair/start" "$MECHANIC_TOKEN" >/dev/null; wait_status "$ORDER_ID" in_execution
  api POST "/api/v1/executions/$ORDER_ID/repair/finish" "$MECHANIC_TOKEN" >/dev/null; wait_status "$ORDER_ID" finalized
  sleep 2
  api GET "/api/v1/payments?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -r '.data[0] | "  pagamento \(.provider) \(.status) R$ \(.amount)\n  checkout: \(.checkout_url)"'
  ok "pague no checkout (Mercado Pago: comprador de teste, cartão titular APRO) e rode: bash demo/fluxo-os.sh entregar"
  trace_end
}

entregar() {
  ORDER_ID="$(order_id "${1:-}")"
  trace_begin "4. pagar e entregar"
  step "Billing confirma o pagamento no gateway → OS marcada como paga → recepção entrega"
  payment="$(api GET "/api/v1/payments?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -c '.data[0]')"
  if [[ "$(jq -r .provider <<<"$payment")" == offline ]]; then
    curl -sS "$(jq -r .checkout_url <<<"$payment")" -H "Authorization: Bearer $CLIENT_TOKEN" -H 'Accept: application/json' \
      ${TRACEPARENT:+-H "traceparent: $TRACEPARENT"} | jq -r '"  " + .message'
  fi
  wait_payment_approved "$(jq -r .id <<<"$payment")"
  for _ in $(seq 1 30); do [[ "$(order_field "$ORDER_ID" paid_at)" != null ]] && break; sleep 1; done
  api POST "/api/v1/service-orders/$ORDER_ID/deliver" "$RECEPTION_TOKEN" | jq -c '{number, status}'
  wait_status "$ORDER_ID" delivered
  show_history "$ORDER_ID"
  ok "logs da saga pelos 3 serviços: bash demo/trace-saga.sh $ORDER_ID"
  trace_end
}

compensar() { # OS pede mais peças do que há em estoque: falha de negócio na aprovação
  read -r item stock name <<<"$(api GET /api/v1/items "$STAFF_TOKEN" \
    | jq -r '[.data[] | select(.part_number != null)][0] | "\(.id) \(.stock_quantity) \(.name)"')"
  trace_begin "5. compensar (estoque insuficiente)"
  step "OS pedindo $((stock + 5))× $name (estoque: $stock) → diagnóstico → orçamento"
  ORDER_ID="$(open_order "$item" $((stock + 5)))"
  wait_status "$ORDER_ID" received; sleep 2
  api POST "/api/v1/executions/$ORDER_ID/diagnosis/start" "$MECHANIC_TOKEN" >/dev/null; wait_status "$ORDER_ID" in_diagnosis
  api POST "/api/v1/executions/$ORDER_ID/diagnosis/finish" "$MECHANIC_TOKEN" >/dev/null; wait_status "$ORDER_ID" awaiting_approval
  step "Cliente aprova → OS não consegue reservar o estoque → saga compensa os passos já feitos"
  budget="$(api GET "/api/v1/budgets?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -r '.data[0].id')"
  api POST "/api/v1/budgets/$budget/approve" "$CLIENT_TOKEN" >/dev/null
  wait_status "$ORDER_ID" cancelled
  api GET "/api/v1/budgets/$budget" "$CLIENT_TOKEN" | jq -c '{orcamento: .status, motivo: .void_reason}'
  show_history "$ORDER_ID"
  ok "compensação: cmd.billing.void_budget (orçamento anulado) + cmd.execution.cancel_task (tarefa cancelada)"
  trace_end
}

cmd="${1:-}"; shift || true
case "$cmd" in
  abrir|diagnosticar|aprovar|entregar|compensar) bootstrap_actors >/dev/null; "$cmd" "$@" ;;
  *) sed -n '2,11p' "$0"; exit 1 ;;
esac
