# Hecate-Nautilus: Unbound "WarSpec" Build v6 (Checksum Fix)
# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder

ARG UNBOUND_VERSION=1.19.3

# Dependências de build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    libhiredis-dev wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Baixa e verifica o código-fonte
RUN set -eux; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz"        "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.sha256" "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz.sha256";

# CORREÇÃO CRÍTICA: Faz a verificação do checksum de forma robusta
RUN [ "$(sha256sum "unbound-${UNBOUND_VERSION}.tar.gz" | awk '{print $1}')" = "$(cat "unbound-${UNBOUND_VERSION}.tar.gz.sha256")" ]

# Compila e instala
RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim

# Dependências de runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Cria um usuário não-root para rodar o Unbound
RUN useradd -r -s /usr/sbin/nologin unbound

# Copia os binários, bibliotecas e configurações do builder
COPY --from=builder /usr/sbin/unbound* /usr/sbin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /etc/unbound /etc/unbound

# Define o usuário para rodar o processo
USER unbound

# Comando para iniciar o Unbound
ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]