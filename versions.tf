# Placeholder — sem provider declarado ainda. O provider Dokploy (comunitário)
# e sua versão pinada entram no epic 3 (ADR-005), junto com os recursos reais
# de app/domínio/deploy webhook. Este arquivo só existe para dar ao workflow
# de CI algo válido para `terraform init`/`validate` desde o epic 1.
terraform {
  required_version = ">= 1.5"
}
