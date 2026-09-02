# Mesmo provider e versão do workshop-os-infra-database — ver
# 15SOAT-Fase1/docs/architecture/adrs/adr-005-dokploy-terraform-provider.md
# (dois providers gerindo o mesmo servidor Dokploy seria inconsistente).
terraform {
  required_version = ">= 1.5"

  required_providers {
    dokploy = {
      source  = "vanillauys/dokploy"
      version = "0.10.2"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "4.20.0"
    }
  }
}

# endpoint/api_key vêm de DOKPLOY_ENDPOINT/DOKPLOY_API_KEY (env), nunca de
# arquivo versionado — mesma disciplina do workshop-os-infra-database.
provider "dokploy" {}

# api_key/app_key vêm de DD_API_KEY/DD_APP_KEY (env, suportado nativamente
# pelo provider) — ver ADR-009. Provider oficial (mantido pela própria
# Datadog), diferente do provider Dokploy comunitário.
provider "datadog" {}
