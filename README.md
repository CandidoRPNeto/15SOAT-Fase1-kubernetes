# workshop-os-infra-kubernetes

Terraform (provider Dokploy) para o recurso de aplicação, domínio/roteamento
(Traefik) e deploy webhook do Workshop OS na Fase 3 — o "cluster com
escalabilidade" desta fase é o orquestrador do próprio Dokploy (Swarm/
Compose), não um Kubernetes real. Ver
[ADR-001](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/docs/architecture/adrs/adr-001-dokploy-as-cloud.md)
no repo principal para a justificativa completa dessa escolha e sua
ressalva de escalabilidade.

Parte do split em 4 repositórios da Fase 3 do projeto
[15SOAT-Fase1](https://github.com/CandidoRPNeto/15SOAT-Fase1) — requisito
completo em [`evolucao_fase3`](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/evolucao_fase3).

**Status**: scaffolding — implementação em
[epic 3](https://github.com/CandidoRPNeto/15SOAT-Fase1/blob/master/backlog.md#epic-3--appk8s-infra-iac)
do backlog do repo principal, depois do epic 2 (banco).

## Propósito

_(preenchido no epic 3)_

## Tecnologias

Terraform + [provider Dokploy](https://registry.terraform.io/) (comunitário
— versão a ser pinada no epic 3, ver ADR-005).

## Execução e deploy

_(preenchido no epic 3)_

## Diagrama de arquitetura

_(preenchido no epic 3)_

## Swagger / Postman

Não aplicável — este repositório é infraestrutura, não expõe API própria.
