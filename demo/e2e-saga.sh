#!/usr/bin/env bash
# Fluxo completo de uma OS atravessando OS → Execution → Billing (saga feliz).
# Usage: PAUSE=1 demo/e2e-saga.sh     (PAUSE=1 espera ENTER entre os passos, para o vídeo)
source "$(dirname "$0")/lib.sh"

step "Login (OS Service) e dados do cliente"
bootstrap_actors
read -r ITEM_ID STOCK ITEM_NAME <<<"$(item_with_stock_at_least 2)"
ok "peça: $ITEM_NAME (id $ITEM_ID, estoque $STOCK)"

step "Recepção abre a OS → saga envia cmd.execution.enqueue_diagnosis"
ORDER_ID="$(open_order "$ITEM_ID" 2)"
ok "OS $ORDER_ID criada"
wait_status "$ORDER_ID" received

step "Mecânico inicia o diagnóstico no Execution Service (MongoDB)"
sleep 2
api POST "/api/v1/executions/$ORDER_ID/diagnosis/start" "$MECHANIC_TOKEN" | jq -c '{phase, status}'
wait_status "$ORDER_ID" in_diagnosis

step "Mecânico conclui o diagnóstico → saga pede orçamento ao Billing"
api POST "/api/v1/executions/$ORDER_ID/diagnosis/finish" "$MECHANIC_TOKEN" '{"notes":"Pastilhas gastas"}' | jq -c '{phase, status}'
wait_status "$ORDER_ID" awaiting_approval

step "Cliente consulta e aprova o orçamento no Billing Service"
BUDGET_ID="$(api GET "/api/v1/budgets?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -r '.data[0].id')"
api POST "/api/v1/budgets/$BUDGET_ID/approve" "$CLIENT_TOKEN" | jq -c '{id, status, total}'
wait_status "$ORDER_ID" approved

step "Mecânico executa o reparo (pivot da saga)"
api POST "/api/v1/executions/$ORDER_ID/repair/start" "$MECHANIC_TOKEN" | jq -c '{phase, status}'
wait_status "$ORDER_ID" in_execution
api POST "/api/v1/executions/$ORDER_ID/repair/finish" "$MECHANIC_TOKEN" | jq -c '{phase, status}'
wait_status "$ORDER_ID" finalized

step "Billing abre o checkout (Mercado Pago) e o cliente paga"
sleep 2
PAYMENT="$(api GET "/api/v1/payments?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -c '.data[0]')"
PAYMENT_ID="$(jq -r .id <<<"$PAYMENT")"
CHECKOUT_URL="$(jq -r .checkout_url <<<"$PAYMENT")"
ok "provider $(jq -r .provider <<<"$PAYMENT"): $CHECKOUT_URL"
if [[ "$(jq -r .provider <<<"$PAYMENT")" == offline ]]; then
  curl -sS "$CHECKOUT_URL" -H "Authorization: Bearer $CLIENT_TOKEN" -H 'Accept: application/json' | jq -r .message
else
  read -rp "  Pague no link acima com o comprador de teste e pressione ENTER " _
fi
for _ in $(seq 1 60); do
  [[ "$(api POST "/api/v1/payments/$PAYMENT_ID/verify" "$CLIENT_TOKEN" | jq -r .payment.status)" == approved ]] && break
  sleep 5
done
for _ in $(seq 1 30); do [[ "$(order_field "$ORDER_ID" paid_at)" != null ]] && break; sleep 1; done
[[ "$(order_field "$ORDER_ID" paid_at)" != null ]] || fail "payment not confirmed on the OS"
ok "pagamento confirmado → OS marcada como paga"

step "Recepção entrega o veículo → saga concluída"
api POST "/api/v1/service-orders/$ORDER_ID/deliver" "$RECEPTION_TOKEN" | jq -c '{number, status}'
wait_status "$ORDER_ID" delivered
show_history "$ORDER_ID"
