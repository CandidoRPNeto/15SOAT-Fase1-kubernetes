# Não cria um dokploy_project novo — anexa ao mesmo project/environment
# provisionado por workshop-os-infra-database (Epic 2), via var.environment_id.
# Ver "Hierarquia e ownership" em
# 15SOAT-Fase1/docs/architecture/rfcs/rfc-002-managed-database-strategy.md.
resource "dokploy_application" "workshop_os" {
  name           = "workshop-os-app"
  environment_id = var.environment_id

  docker = {
    image = var.app_image
  }

  # DB_HOST não é preenchido aqui: dokploy_postgres (Epic 2) não expõe um
  # atributo de hostname interno no schema do provider — só id/status. O
  # hostname real (Dokploy usa um nome de serviço interno na rede
  # dokploy-network) só existe depois do primeiro deploy do banco e precisa
  # ser conferido na UI/API do Dokploy. Documentado como lacuna manual, não
  # inventado aqui.
  env = <<-EOT
    APP_ENV=production
    DB_CONNECTION=pgsql
    DB_PORT=5432
  EOT

  replicas           = var.app_replicas
  cpu_limit          = var.cpu_limit
  cpu_reservation    = var.cpu_reservation
  memory_limit       = var.memory_limit
  memory_reservation = var.memory_reservation
}

resource "dokploy_domain" "workshop_os" {
  application_id   = dokploy_application.workshop_os.id
  host             = var.app_domain_host
  port             = 8000 # container port — ver k8s/deployment.yaml/service.yaml
  https            = true
  certificate_type = "letsencrypt"
}
