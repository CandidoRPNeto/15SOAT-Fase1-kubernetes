variable "environment_id" {
  description = "Id do environment 'production' do projeto workshop-os, exportado por workshop-os-infra-database (Epic 2). Sem backend remoto compartilhado ainda (ver RFC-002), copiar de `terraform output environment_id` naquele repo — não é resolvido automaticamente."
  type        = string
}

variable "app_image" {
  description = "Imagem Docker da aplicação principal, publicada pelo CI/CD de 15SOAT-Fase1 (ghcr.io/candidorpneto/15soat-fase1:<tag>)."
  type        = string
}

variable "app_replicas" {
  description = "Número fixo de réplicas — Dokploy não tem autoscaling nativo (ver ADR-006 em 15SOAT-Fase1). 2 replica o minReplicas do HPA da Fase 2 (k8s/hpa.yaml)."
  type        = number
  default     = 2
}

variable "app_domain_host" {
  description = "Hostname público da aplicação (ex.: workshop-os.example.com). Sem default — depende do domínio real do usuário, não decidido nesta sessão."
  type        = string
}

# Limites reaproveitados de k8s/deployment.yaml (Fase 2) — mesmo envelope de
# recursos em ambos os alvos de deploy (kind local e Dokploy cloud), não
# valores inventados para este repositório.
variable "cpu_limit" {
  description = "Limite de CPU, formato Docker (ver k8s/deployment.yaml: limits.cpu 500m = 0.5 core)."
  type        = string
  default     = "0.5"
}

variable "cpu_reservation" {
  description = "CPU reservada, formato Docker (ver k8s/deployment.yaml: requests.cpu 250m = 0.25 core)."
  type        = string
  default     = "0.25"
}

variable "memory_limit" {
  description = "Limite de memória, formato Docker (ver k8s/deployment.yaml: limits.memory 512Mi)."
  type        = string
  default     = "512m"
}

variable "memory_reservation" {
  description = "Memória reservada, formato Docker (ver k8s/deployment.yaml: requests.memory 256Mi)."
  type        = string
  default     = "256m"
}
