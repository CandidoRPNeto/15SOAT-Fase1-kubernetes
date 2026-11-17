terraform {
  required_version = ">= 1.5"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "4.20.0"
    }
  }
}

# Credenciais via ambiente: DD_API_KEY, DD_APP_KEY (e DD_HOST para sites fora de US1).
provider "datadog" {}
