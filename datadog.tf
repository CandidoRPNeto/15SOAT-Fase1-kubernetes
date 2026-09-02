# Epic 6 — observabilidade. Escopo e trade-offs conscientemente aceitos
# documentados em
# 15SOAT-Fase1/docs/architecture/adrs/adr-009-datadog-agent-placement.md.

# Agent como serviço Dokploy (mesmo projeto/environment do banco e da app —
# RFC-002), montando docker.sock: dá métricas de CPU/memória de todo
# container do host automaticamente, sem instrumentar cada serviço.
resource "dokploy_compose" "datadog_agent" {
  name           = "datadog-agent"
  environment_id = var.environment_id
  description    = "Datadog Agent — coleta métricas de containers (docker.sock) e recebe logs (Epic 6)"

  raw = {
    compose_file = <<-YAML
      services:
        datadog-agent:
          image: gcr.io/datadoghq/agent:7
          environment:
            - DD_API_KEY=${var.datadog_api_key}
            - DD_SITE=${var.datadog_site}
            - DD_LOGS_ENABLED=true
            - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
            - DD_CONTAINER_EXCLUDE=name:datadog-agent
            - DD_TAGS=env:production service:workshop-os
          volumes:
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - /proc/:/host/proc/:ro
            - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
    YAML
  }
}

resource "datadog_monitor" "container_cpu" {
  name    = "workshop-os — CPU alta / container fora do ar"
  type    = "metric alert"
  message = "CPU do container workshop-os-app acima do esperado (ou parou de reportar — ver notify_no_data). Ver ADR-009."
  query   = "avg(last_5m):avg:docker.cpu.usage{service:workshop-os-app} > 85"

  monitor_thresholds {
    warning  = 70
    critical = 85
  }

  # Ausência de dados = container não está mais reportando métricas —
  # interpretação pragmática de "healthcheck/uptime" (ADR-009, sem
  # synthetic HTTP check externo nesta fase).
  notify_no_data    = true
  no_data_timeframe = 10

  include_tags = true
  tags         = ["service:workshop-os-app", "env:production"]
}

resource "datadog_monitor" "container_memory" {
  name    = "workshop-os — memória do container acima do limite do envelope"
  type    = "metric alert"
  message = "Memória do container workshop-os-app acima de 90% do limite definido em k8s/deployment.yaml (512Mi) — ver ADR-006/adr-009."
  # 512Mi (mesmo limite de k8s/deployment.yaml — 15SOAT-Fase1) * 0.9
  query = "avg(last_5m):avg:docker.mem.rss{service:workshop-os-app} > 483183820.8"

  monitor_thresholds {
    critical = 483183820.8
  }

  notify_no_data    = true
  no_data_timeframe = 10

  include_tags = true
  tags         = ["service:workshop-os-app", "env:production"]
}

resource "datadog_monitor" "service_order_failures" {
  name    = "workshop-os — falhas no processamento de ordens de serviço"
  type    = "log alert"
  message = "5+ erros em 5min nos logs da app (canal JSON, Epic 4) — ver evolucao_fase3 'alertas para falhas no processamento de ordens de serviço'."
  query   = "logs(\"service:workshop-os-app status:error\").index(\"main\").rollup(\"count\").last(\"5m\") > 5"

  monitor_thresholds {
    critical = 5
  }

  include_tags = true
  tags         = ["service:workshop-os-app", "env:production"]
}
