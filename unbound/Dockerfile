# ---------- BUILDER ----------
FROM debian:bookworm-slim AS builder

# Instala dependências de build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libssl-dev libexpat1-dev libevent-dev \
    libhiredis-dev wget gnupg dirmngr ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Baixa Unbound
RUN wget -O unbound.tar.gz "https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz" \
    && wget -O unbound.asc "https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz.asc"

# --- MÉTODO DEFINITIVO: BAIXAR A CHAVE DIRETO DO SITE ---
RUN wget -qO- https://nlnetlabs.nl/downloads/unbound/unbound_nlnetlabs.asc | gpg --import
# -------------------------------------------------------

# Verifica a assinatura
RUN gpg --verify unbound.asc unbound.tar.gz

# Compila e instala o Unbound
RUN tar xzf unbound.tar.gz \
    && cd unbound-1.19.3 \
    && ./configure --prefix=/usr --sysconfdir=/etc --disable-static \
    && make -j"$(nproc)" \
    && make install

# ---------- FINAL IMAGE ----------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libexpat1 libevent-2.1-7 libhiredis0.14 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /etc/unbound /etc/unbound

EXPOSE 53/udp
EXPOSE 53/tcp

ENTRYPOINT ["unbound", "-d"]
