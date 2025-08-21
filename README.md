# Projeto Hécate-Nautilus
![Versão](https://img.shields.io/badge/release-v0.1-blue.svg)
![Status](https://img.shields.io/badge/status-operacional-brightgreen.svg)
![Plataforma](https://img.shields.io/badge/plataforma-docker-blue.svg)

Arquitetura de Sistema DNS Soberano em Contêineres de Ultraperformance.

---
## Filosofia do Projeto

O Hécate-Nautilus representa a materialização de uma doutrina de soberania de dados e performance extrema. Não é apenas um resolvedor de DNS, mas uma plataforma de resolução autônoma, projetada para operar nos limites teóricos de velocidade e privacidade.

Este repositório contém a **Infraestrutura como Código (IaC)** para implantar a stack completa de forma rápida e reprodutível.

## Arquitetura de Componentes

O sistema é uma stack de serviços micro-isolados e orquestrados via Docker Compose, composta por:

* **Unbound (O Motor de Recursão):** Contêiner customizado, compilado do zero com otimizações de microarquitetura (`-march=native`), suporte a `libevent` para alta concorrência e configurado para recursão pura a partir dos servidores raiz.
* **AdGuard Home (O Portão de Entrada):** Atua como o filtro primário de DNS, bloqueando anúncios, rastreadores e malware em nível de rede.
* **Redis (A Memória Persistente):** Banco de dados em memória de alta velocidade, utilizado como backend de cache (opcional) para garantir um estado de "cache quente" perpétuo.
* **Host OS (A Fundação):** O desempenho máximo é extraído através de tuning de baixo nível no host Linux, incluindo otimizações de kernel (`sysctl`) e afinidade de CPU.

## Pré-requisitos

* Um host com **Linux (Debian/Ubuntu recomendado)** ou **Windows 10/11 com WSL 2**.
* **Docker** e **Docker Compose** instalados.
* **Git** para clonar o repositório.
* Acesso de superusuário (root/sudo) no host para o tuning inicial do kernel (opcional, mas recomendado).

## Instalação e Implantação

O processo é projetado para ser rápido e determinístico.

**1. Clone o Repositório:**
```bash
git clone [https://github.com/xDzLeozzz/hecate-nautilus.git](https://github.com/xDzLeozzz/hecate-nautilus.git)
cd hecate-nautilus
```

**2. Configure os Recursos do Hardware:**
O coração do tuning de performance está na alocação de recursos.
* Copie o arquivo de exemplo: `cp .env.example .env` (se você criar um `.env.example`).
* Abra o arquivo `.env` e ajuste as variáveis `*_CPUSET` e `*_MEM_LIMIT` para corresponderem exatamente às especificações do seu hardware.

**3. Construa e Inicie a Stack:**
Este comando irá construir a imagem customizada do Unbound e iniciar todos os serviços em segundo plano.
```bash
docker-compose up -d --build
```

## Configuração Pós-Deploy

1.  **Acesse a Interface do AdGuard Home:**
    Abra seu navegador e vá para `http://<IP_DO_SEU_SERVIDOR>:3000`.

2.  **Configure o Upstream DNS:**
    Durante a configuração inicial, na seção **Servidores DNS Upstream**, apague todas as entradas padrão e adicione apenas o seu serviço Unbound local:
    ```
    127.0.0.1:5335
    ```

3.  **Aponte seus Clientes:**
    Configure o servidor DHCP da sua rede para que o endereço IP do seu host Hécate-Nautilus seja o único servidor DNS para todos os seus dispositivos.

## Validação Operacional

Use os seguintes comandos para verificar a saúde do sistema:

| Comando | O que Verificar |
| :--- | :--- |
| `docker-compose ps` | Status **Up** ou **running (healthy)** para todos os contêineres. |
| `docker-compose logs unbound` | Ausência de erros ou avisos críticos. |
| `nslookup google.com 127.0.0.1` | Receber uma resposta válida com endereços de IP. |

## Atualização do Sistema

Manter o Hécate-Nautilus atualizado é crucial para a segurança e performance.

* **Para atualizar a versão de um serviço (ex: Unbound):**
    1.  Altere a `UNBOUND_VERSION` no arquivo `.env`.
    2.  Execute `docker-compose up -d --build unbound`.

* **Para aplicar patches de segurança no sistema base:**
    1.  Execute `docker-compose build --pull --no-cache`.
    2.  Execute `docker-compose up -d`.

* **Para alterar uma configuração (ex: `unbound.conf`):**
    1.  Edite o arquivo de configuração.
    2.  Execute `docker-compose restart <nome_do_serviço>`.
## Configuração Inicial do AdGuard
Após deploy, acesse http://localhost:3000 e configure o upstream DNS para: 127.0.0.1:5335
## Configuração Inicial do AdGuard
Após deploy, acesse http://localhost:3000 e configure o upstream DNS para: 127.0.0.1:5335
