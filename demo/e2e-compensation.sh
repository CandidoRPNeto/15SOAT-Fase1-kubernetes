#!/usr/bin/env bash
# Falhas e compensação da saga.
#   stock      — orçamento aprovado sem estoque: libera reserva, anula orçamento, cancela tarefa e OS.
#   queue-full — Execution recusa o reparo (EXECUTION_QUEUE_CAPACITY=0): mesma compensação.
#   worker-down — Execution fora do ar: mensagem fica retida no RabbitMQ; ao voltar, a saga segue.
# Usage: PAUSE=1 demo/e2e-compensation.sh stock|queue-full|worker-down
source "$(dirname "$0")/lib.sh"
scenario="${1:?usage: $0 stock|queue-full|worker-down}"

to_awaiting_approval() { # order_id
  sleep 2
  api POST "/api/v1/executions/$1/diagnosis/start" "$MECHANIC_TOKEN" >/dev/null
  wait_status "$1" in_diagnosis
  api POST "/api/v1/executions/$1/diagnosis/finish" "$MECHANIC_TOKEN" >/dev/null
  wait_status "$1" awaiting_approval
}

approve_budget() { # order_id
  local budget
  budget="$(api GET "/api/v1/budgets?service_order_id=$1" "$CLIENT_TOKEN" | jq -r '.data[0].id')"
  api POST "/api/v1/budgets/$budget/approve" "$CLIENT_TOKEN" | jq -c '{status, total}'
}

# A terminating Pod keeps consuming its prefetched messages; wait until every
# execution-worker Pod is gone before relying on the new state.
stop_execution_worker() {
  kubectl -n execution scale deployment/execution-worker --replicas=0 >/dev/null
  kubectl -n execution wait --for=delete pod -l app=execution-worker --timeout=90s >/dev/null 2>&1 || true
  ok "execution-worker parado (0 pods)"
}
start_execution_worker() {
  kubectl -n execution scale deployment/execution-worker --replicas=1 >/dev/null
  kubectl -n execution rollout status deployment/execution-worker --timeout=120s >/dev/null
  ok "execution-worker no ar"
}
restore_execution_worker() {
  kubectl -n execution set env deployment/execution-worker EXECUTION_QUEUE_CAPACITY- >/dev/null 2>&1 || true
  kubectl -n execution scale deployment/execution-worker --replicas=1 >/dev/null 2>&1 || true
}
trap restore_execution_worker EXIT

bootstrap_actors
case "$scenario" in
  stock)
    read -r ITEM_ID STOCK ITEM_NAME <<<"$(item_with_stock_at_least 1)"
    step "OS pedindo $((STOCK + 5))× $ITEM_NAME (estoque: $STOCK)"
    ORDER_ID="$(open_order "$ITEM_ID" $((STOCK + 5)))"
    to_awaiting_approval "$ORDER_ID"
    step "Cliente aprova → reserva de estoque falha → compensação"
    approve_budget "$ORDER_ID"
    wait_status "$ORDER_ID" cancelled
    api GET "/api/v1/budgets?service_order_id=$ORDER_ID" "$CLIENT_TOKEN" | jq -c '.data[0] | {status, void_reason}'
    ;;
  queue-full)
    read -r ITEM_ID _ _ <<<"$(item_with_stock_at_least 1)"
    ORDER_ID="$(open_order "$ITEM_ID" 1)"
    to_awaiting_approval "$ORDER_ID"
    step "Execution lota a fila (EXECUTION_QUEUE_CAPACITY=0)"
    stop_execution_worker
    kubectl -n execution set env deployment/execution-worker EXECUTION_QUEUE_CAPACITY=0 >/dev/null
    start_execution_worker
    step "Cliente aprova → estoque reservado → Execution recusa o reparo → compensação"
    approve_budget "$ORDER_ID"
    wait_status "$ORDER_ID" cancelled 60
    ;;
  worker-down)
    read -r ITEM_ID _ _ <<<"$(item_with_stock_at_least 1)"
    step "Execution worker fora do ar (0 réplicas)"
    stop_execution_worker
    ORDER_ID="$(open_order "$ITEM_ID" 1)"
    sleep 5
    step "Comando retido na fila durável do RabbitMQ; saga aguardando"
    kubectl -n platform exec statefulset/rabbitmq -- rabbitmqctl -q list_queues name messages | grep execution.inbox
    show_history "$ORDER_ID"
    step "Execution volta → consome a fila → saga segue"
    start_execution_worker
    for _ in $(seq 1 30); do
      [[ "$(api GET "/api/v1/service-orders/$ORDER_ID/history" "$STAFF_TOKEN" | jq -r '.saga.steps[0].status')" == succeeded ]] && break
      sleep 1
    done
    ;;
  *) fail "unknown scenario $scenario" ;;
esac
show_history "$ORDER_ID"
