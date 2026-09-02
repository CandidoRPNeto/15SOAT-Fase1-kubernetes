# workshop-os-infra-kubernetes

Terraform que provisiona o recurso de aplicação e o domínio/roteamento
(Traefik) do Workshop OS na Fase 3, no mesmo servidor
[Dokploy](https://dokploy.com) usado pelo banco (repo irmão
[`workshop-os-infra-database`](https://github.com/CandidoRPNeto/workshop-os-infra-database)).
O "cluster com escalabilidade" desta fase é o orquestrador do próprio
Dokploy — não um Kubernetes real. Ver
[ADR-001](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/docs/architecture/adrs/adr-001-dokploy-as-cloud.md)
e [ADR-006](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/docs/architecture/adrs/adr-006-scaling-approach.md)
(sobre a ressalva de escalabilidade) no repo principal.

Parte do split em 4 repositórios da Fase 3 do projeto
[15SOAT-Fase1](https://github.com/CandidoRPNeto/15SOAT-Fase1) — requisito
completo em [`evolucao_fase3`](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/evolucao_fase3).

## Propósito

Cria, via Terraform, no mesmo `project`/`environment` do
`workshop-os-infra-database`:
- `dokploy_application` (`workshop-os-app`) — imagem publicada pelo CI/CD
  de `15SOAT-Fase1` (GHCR), 2 réplicas fixas (ver ADR-006), limites de
  CPU/memória iguais aos de `k8s/deployment.yaml`.
- `dokploy_domain` — rota HTTPS (Let's Encrypt) pro domínio público da
  aplicação, porta 8000 (mesma porta do container em `k8s/`).

## Tecnologias

- Terraform `>= 1.5`
- Provider [`vanillauys/dokploy`](https://registry.terraform.io/providers/vanillauys/dokploy) `0.10.2`
  (mesma escolha do `workshop-os-infra-database` — ver
  [ADR-005](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/docs/architecture/adrs/adr-005-dokploy-terraform-provider.md))

## Execução

```bash
export DOKPLOY_ENDPOINT="https://<seu-dokploy>.example.com"
export DOKPLOY_API_KEY="<sua api key>"

terraform init
terraform plan \
  -var="environment_id=<terraform output -raw environment_id, no workshop-os-infra-database>" \
  -var="app_image=ghcr.io/candidorpneto/15soat-fase1:latest" \
  -var="app_domain_host=<seu domínio>"
terraform apply ...  # mesmas -var acima
```

`environment_id` **não** é resolvido automaticamente — sem um backend
remoto compartilhado entre os dois repos (lacuna documentada em
[RFC-002](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/docs/architecture/rfcs/rfc-002-managed-database-strategy.md)),
copie o output do `workshop-os-infra-database` antes de aplicar este.

**Nota de rate limit**: a API do Dokploy responde `401` (não `429`) quando
o limite de requisições da API key é excedido — não confundir com
credencial errada num apply real (ver
[ADR-005](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/docs/architecture/adrs/adr-005-dokploy-terraform-provider.md)).

**Status**: `terraform validate` passa; `apply` real ainda não foi rodado —
requer servidor Dokploy acessível, API key e o `environment_id` do Epic 2,
nenhum disponível nesta sessão.

## Deploy

`main` e `homolog` protegidas (PR obrigatório). CI (`.github/workflows/ci.yml`)
roda `terraform fmt -check` + `terraform validate`; `apply` automático fica
para quando os secrets (`DOKPLOY_ENDPOINT`, `DOKPLOY_API_KEY`,
`environment_id`) estiverem configurados no repositório.

## Diagrama de arquitetura

```mermaid
flowchart LR
    CI["15SOAT-Fase1 CI/CD<br/>build + push GHCR"] -->|app_image| App

    subgraph Dokploy["Dokploy — project: workshop-os (mesmo do banco)"]
        App["dokploy_application<br/>workshop-os-app<br/>2 réplicas fixas"]
        Domain["dokploy_domain<br/>HTTPS · Let's Encrypt · :8000"]
        Domain --> App
    end

    DB["workshop-os-infra-database<br/>(Epic 2 — mesmo environment)"] -.->|environment_id manual| App
    Internet(["Internet"]) --> Domain
```

## Swagger / Postman

Não aplicável — este repositório é infraestrutura, não expõe API própria.
Ver o Swagger da aplicação em `15SOAT-Fase1` (`/api/documentation`).
