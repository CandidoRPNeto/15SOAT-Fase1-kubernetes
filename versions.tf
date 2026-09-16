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
  }
}

# endpoint/api_key vêm de DOKPLOY_ENDPOINT/DOKPLOY_API_KEY (env), nunca de
# arquivo versionado — mesma disciplina do workshop-os-infra-database.
provider "dokploy" {}
