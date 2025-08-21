# Hecate-Nautilus: Unbound "WarSpec" Build vFinal
# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder

ARG UNBOUND_VERSION=1.19.3

# Dependências de build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Baixa e verifica o código-fonte
RUN set -eux; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz"        "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"; \
  wget -O "unbound-${UNBOUND_VERSION}.tar.gz.sha256" "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz.sha256";
RUN [ "$(sha256sum "unbound-${UNBOUND_VERSION}.tar.gz" | awk '{print $1}')" = "$(cat "unbound-${UNBOUND_VERSION}.tar.gz.sha256")" ]

# Compila e instala
RUN tar xzf "unbound-${UNBOUND_VERSION}.tar.gz" \
 && cd "unbound-${UNBOUND_VERSION}" \
 && ./configure --prefix=/usr --sysconfdir=/etc --disable-static --with-libevent \
 && make -j"$(nproc)" \
 && make install

# ---------- RUNTIME ----------
FROM debian:bookworm-slim

# Dependências de runtime, incluindo GOSU
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 ca-certificates gosu \
 && rm -rf /var/lib/apt/lists/*

# Cria um usuário não-root
RUN useradd -r -s /usr/sbin/nologin unbound

# Copia os binários e configurações do builder
COPY --from=builder /usr/sbin/unbound* /usr/sbin/
COPY --from=builder /etc/unbound /etc/unbound

# Copia o novo script de entrada e o torna executável
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Define o script como o comando de inicialização
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]