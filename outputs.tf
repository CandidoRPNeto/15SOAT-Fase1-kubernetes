output "application_id" {
  description = "Id do serviço de app provisionado."
  value       = dokploy_application.fase1.id
}

output "application_status" {
  description = "Status do serviço de app reportado pelo Dokploy."
  value       = dokploy_application.fase1.status
}

output "domain_id" {
  description = "Id do domínio/rota Traefik provisionado."
  value       = dokploy_domain.fase1.id
}
