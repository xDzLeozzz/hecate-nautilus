# Projeto Hécate-Nautilus

Arquitetura de Sistema DNS Soberano em Contêineres de Ultraperformance.

## Visão Geral

Este repositório contém a infraestrutura como código para implantar a stack Hécate-Nautilus, um sistema DNS recursivo e de filtragem de altíssima performance, construído sobre Docker.

### Componentes:
- **Host OS:** Debian/Ubuntu com Kernel customizado e tuning de baixo nível.
- **Unbound:** Contêiner customizado, compilado do zero para máxima performance.
- **AdGuard Home:** Filtragem de anúncios e tracking.
- **Redis:** (Opcional) Cache de alta velocidade.

## Implantação

1. Clone este repositório.
2. Ajuste os valores de `cpuset` e `mem_limit` no arquivo `docker-compose.yml` para corresponder ao seu hardware.
3. Execute o comando: `docker-compose up -d --build`

## Configuração Pós-Deploy

1. Acesse a interface do AdGuard Home em `http://<IP_DO_SERVIDOR>:3000`.
2. Na configuração inicial, defina o DNS Upstream para `127.0.0.1:5335`.