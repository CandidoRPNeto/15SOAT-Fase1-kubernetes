variable "env" {
  description = "Tag env dos serviços (DD_ENV nos ConfigMaps)."
  type        = string
  default     = "dev"
}

variable "services" {
  description = "Valores de DD_SERVICE dos microsserviços da Fase 4."
  type        = list(string)
  default     = ["os-service", "billing-service", "execution-service"]
}
