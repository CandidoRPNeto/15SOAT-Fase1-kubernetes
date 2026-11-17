# Fase 4 — monitores dos fluxos distribuídos (saga). Os eventos vêm dos logs
# JSON emitidos pelos serviços (saga.compensated, saga.step_resent,
# inbox.dead_lettered) e do APM (dd-trace em cada imagem).
# Aplicar: cd observability && terraform init && terraform apply

resource "datadog_monitor" "saga_compensations" {
  name    = "Workshop OS — sagas compensadas"
  type    = "log alert"
  message = "Sagas de OS compensadas nos últimos 10 min (estoque, fila lotada, timeout ou rejeição). Ver GET /api/v1/service-orders/{id}/history e ADR-010."
  query   = "logs(\"service:os-service env:${var.env} @message:saga.compensated\").index(\"*\").rollup(\"count\").last(\"10m\") > 3"

  monitor_thresholds {
    warning  = 1
    critical = 3
  }

  include_tags = true
  tags         = ["service:os-service", "env:${var.env}", "fase:4"]
}

resource "datadog_monitor" "saga_steps_stuck" {
  name    = "Workshop OS — passos de saga sem resposta (watchdog reenviando)"
  type    = "log alert"
  message = "O saga:watchdog reenviou comandos: Billing ou Execution não está respondendo. Verifique os workers e a fila no RabbitMQ."
  query   = "logs(\"service:os-service env:${var.env} @message:saga.step_resent\").index(\"*\").rollup(\"count\").last(\"5m\") > 0"

  monitor_thresholds {
    critical = 0
  }

  include_tags = true
  tags         = ["service:os-service", "env:${var.env}", "fase:4"]
}

resource "datadog_monitor" "dead_letters" {
  name    = "Workshop OS — mensagens na DLQ"
  type    = "log alert"
  message = "Um consumidor rejeitou uma mensagem (inbox.dead_lettered). Inspecione a fila <serviço>.inbox.dlq no RabbitMQ."
  query   = "logs(\"(${join(" OR ", formatlist("service:%s", var.services))}) env:${var.env} @message:inbox.dead_lettered\").index(\"*\").rollup(\"count\").last(\"5m\") > 0"

  monitor_thresholds {
    critical = 0
  }

  include_tags = true
  tags         = ["env:${var.env}", "fase:4"]
}

resource "datadog_monitor" "api_error_rate" {
  for_each = toset(var.services)

  name    = "Workshop OS — taxa de erro alta em ${each.value}"
  type    = "query alert"
  message = "Mais de 5% das requisições de ${each.value} com erro nos últimos 5 min (APM)."
  query   = "sum(last_5m):(sum:trace.laravel.request.errors{service:${each.value},env:${var.env}}.as_count() / sum:trace.laravel.request.hits{service:${each.value},env:${var.env}}.as_count()) > 0.05"

  monitor_thresholds {
    critical = 0.05
  }

  include_tags = true
  tags         = ["service:${each.value}", "env:${var.env}", "fase:4"]
}
